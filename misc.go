package main

import (
	"context"
	"embed"
	"errors"
	"io"
	"io/fs"
	"log"
	"os"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

func getWaitTime(now time.Time, gnerbtime uint, dayAdd int) (time.Duration, time.Time) {
	year, month, day := now.Date()
	postTime := time.Date(year, month, day+dayAdd, 0, 0, 0, 0, now.Location()).Add(time.Duration(gnerbtime * uint(time.Millisecond)))
	waitTime := postTime.Sub(now)
	if waitTime < 0 {
		return getWaitTime(now, gnerbtime, dayAdd+1)
	}
	return waitTime, postTime
}

//go:embed resource/gnerb.jpg
var gnerbFS embed.FS
var gnerbReader io.Reader
var gnerbTimer *time.Timer

func fnafBot() { // gnerb
	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	gnerbtime, _ := getCfg("bot.fnaf", "gnerbtime").Uint()
	desination, _ := getCfg("bot.fnaf", "destination").Uint64()

	defer func() {
		go func() {
			channel := discord.ChannelID(desination)
			sleep, postTime := getWaitTime(time.Now().UTC(), gnerbtime, 0)
			var lostTime time.Duration
			log.Printf("Sending next gnerb in %dm.", sleep/time.Minute)
			for {
				gnerbTimer = time.NewTimer(sleep - lostTime)
				<-gnerbTimer.C

				var err error
				gnerbReader, err = gnerbFS.Open("resource/gnerb.jpg")
				if err != nil {
					log.Fatalln(err)
				}
				m, err := client.SendMessageComplex(channel, api.SendMessageData{
					Files: []sendpart.File{{
						Name:   "gnerb.jpg",
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

				sleep, postTime = getWaitTime(time.Now().UTC(), gnerbtime, 1)
			}
		}()
	}()

	me, err := client.Me()
	if err == nil {
		log.Println(me.Tag() + " is ready")
		return
	}
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
	client.AddHandler(createReadyAnnouncer(*client))

	var validChannels []discord.ChannelID
	for _, v := range getCfg("bot.cannedfood", "channels").StringsWithShadows(",") {
		channel, err := discord.ParseSnowflake(v)
		if err == nil {
			validChannels = append(validChannels, discord.ChannelID(channel))
		}
	}

	client.AddHandler(func(message *gateway.MessageCreateEvent) {
		var valid bool
		for _, channel := range validChannels {
			if message.ChannelID == channel {
				valid = true
				break
			}
		}
		if !valid {
			return
		}

		err := client.React(message.ChannelID, message.ID, cannedFoodEmoji)
		if err != nil {
			log.Println(err)
			return
		}

		log.Println("CannedFood reacted to a message")
	})

	startSession(*client)
}
