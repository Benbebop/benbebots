package main

import (
	"context"
	"embed"
	"errors"
	"io"
	"io/fs"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

func getWaitTime(now time.Time, gnerbtime time.Duration, dayAdd int) (time.Duration, time.Time) {
	year, month, day := now.Date()
	postTime := time.Date(year, month, day+dayAdd, 0, 0, 0, 0, now.Location()).Add(time.Duration(gnerbtime))
	waitTime := postTime.Sub(now)
	if waitTime < 0 {
		return getWaitTime(now, gnerbtime, dayAdd+1)
	}
	return waitTime, postTime
}

//go:embed resource/pou.png
var gnerbFS embed.FS
var gnerbReader io.Reader
var gnerbTimer *time.Timer

func fnafBot() { // gnerb
	opts := struct {
		Time        time.Duration `ini:"poutime"`
		Destination uint64        `ini:"destination"`
	}{}
	cfg.Section("bot.fnaf").MapTo(&opts)

	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	defer func() {
		go func() {
			channel := discord.ChannelID(opts.Destination)
			sleep, postTime := getWaitTime(time.Now().UTC(), opts.Time, 0)
			var lostTime time.Duration
			log.Printf("Sending next pou in %dm.", sleep/time.Minute)
			for {
				gnerbTimer = time.NewTimer(sleep - lostTime)
				<-gnerbTimer.C

				var err error
				gnerbReader, err = gnerbFS.Open("resource/pou.png")
				if err != nil {
					log.Fatalln(err)
				}
				m, err := client.SendMessageComplex(channel, api.SendMessageData{
					Files: []sendpart.File{{
						Name:   "pou.png",
						Reader: gnerbReader,
					}},
				})
				if err != nil {
					log.Println(err)
				}

				messageRecieved := m.ID.Time().UTC()
				lostTime = messageRecieved.Sub(postTime)
				db.Exec("REPLACE INTO gnerb.send_lost_time (lost) VALUES ( ? )", lostTime.Microseconds())
				log.Printf("Sent gnerb, lost %dms.", lostTime/time.Millisecond)

				sleep, postTime = getWaitTime(time.Now().UTC(), opts.Time, 1)
			}
		}()
	}()

	me, err := client.Me()
	if err == nil {
		log.Println(me.Tag() + " is ready")
		return
	}

	botGoroutineGroup.Done()
}

func loginCannedFood() (*session.Session, error) {
	var err error
	for i := 1; i < 3; i++ {
		client, err := session.Login(context.Background(), tokens["cannedFood"].Login, tokens["cannedFood"].Password, "")
		if err == nil {
			os.WriteFile(dirs.Data+"cannedFood.token", []byte(client.Token), 0600)
			return client, nil
		}
		log.Println(err)
	}
	return nil, err
}

var cannedFoodEmoji = discord.NewAPIEmoji(discord.NullEmojiID, `🥫`)

func cannedFood() {
	opts := struct {
		Channels []discord.ChannelID `ini:"-"`
		Delay    []int64             `ini:"delay"`
	}{}
	sect := cfg.Section("bot.cannedfood")
	sect.MapTo(&opts)

	for _, v := range sect.Key("channels").StringsWithShadows(",") {
		channel, err := discord.ParseSnowflake(v)
		if err == nil {
			opts.Channels = append(opts.Channels, discord.ChannelID(channel))
		}
	}

	var client *session.Session
	if t, err := os.ReadFile(dirs.Data + "cannedFood.token"); err == nil {
		token := string(t)
		tmpClient := api.NewClient(token)
		_, err := tmpClient.Me()
		if err != nil {
			log.Println("CannedFood token errored, logging in")
			client, err = loginCannedFood()
			if err != nil {
				log.Fatalln(err)
			}
		} else {
			client = session.New(token)
		}
	} else {
		if !errors.Is(err, fs.ErrNotExist) {
			log.Println(err)
		} else {
			log.Println("CannedFood token missing, logging in")
		}
		client, err = loginCannedFood()
		if err != nil {
			log.Fatalln(err)
		}
	}
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})

	client.AddHandler(func(message *gateway.MessageCreateEvent) {
		var valid bool
		for _, channel := range opts.Channels {
			if message.ChannelID == channel {
				valid = true
				break
			}
		}
		if !valid {
			return
		}

		delay := time.Duration(opts.Delay[0]+rand.Int63n(opts.Delay[1]-opts.Delay[0])) * time.Millisecond
		time.Sleep(delay)

		err := client.React(message.ChannelID, message.ID, cannedFoodEmoji)
		if err != nil {
			log.Println(err)
			return
		}

		log.Printf("CannedFood reacted to a message after %dms\n", delay.Milliseconds())
	})

	client.Open(client.Context())
	botGoroutineGroup.Done()
}
