package main

import (
	"context"
	"embed"
	"errors"
	"io"
	"log"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
	"github.com/syndtr/goleveldb/leveldb"
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

func (bbb *Benbebots) RunFnafBot() { // gnerb
	opts := struct {
		Time        time.Duration `ini:"poutime"`
		Destination uint64        `ini:"destination"`
		StatChannel uint64        `ini:"statchannel"`
	}{}
	bbb.Config.Section("bot.fnaf").MapTo(&opts)

	client := api.NewClient("Bot " + bbb.Tokens["fnaf"].Password)

	fnafStat := Stat{
		Name:      "Gnerbs",
		Value:     0,
		Client:    client,
		ChannelID: discord.ChannelID(opts.StatChannel),
		LevelDB:   bbb.LevelDB,
		Delay:     time.Second * 5,
	}

	defer func() {
		go func() {
			channel := discord.ChannelID(opts.Destination)
			sleep, _ := getWaitTime(time.Now().UTC(), opts.Time, 0)
			log.Printf("Sending next pou in %dm.", sleep/time.Minute)
			for {
				gnerbTimer = time.NewTimer(sleep)
				<-gnerbTimer.C

				var err error
				gnerbReader, err = gnerbFS.Open("resource/pou.png")
				if err != nil {
					log.Fatalln(err)
				}
				_, err = client.SendMessageComplex(channel, api.SendMessageData{
					Files: []sendpart.File{{
						Name:   "pou.png",
						Reader: gnerbReader,
					}},
				})
				if err != nil {
					log.Println(err)
					continue
				}

				fnafStat.Increment(1)
			}
		}()
	}()

	me, err := client.Me()
	if err == nil {
		log.Println(me.Tag() + " is ready")
		bbb.CoroutineGroup.Done()
		return
	}

	bbb.CoroutineGroup.Done()
}

func (b *Benbebots) LoginCannedFood() (*session.Session, error) {
	var err error
	for i := 1; i < 3; i++ {
		client, err := session.Login(context.Background(), b.Tokens["cannedFood"].Login, b.Tokens["cannedFood"].Password, "")
		if err == nil {
			b.LevelDB.Put([]byte("cannedFoodToken"), []byte(client.Token), nil)
			return client, nil
		}
		log.Println(err)
	}
	return nil, err
}

var cannedFoodEmoji = discord.NewAPIEmoji(discord.NullEmojiID, `🥫`)

func (bbb *Benbebots) RunCannedFood() {
	opts := struct {
		Delay         []int64 `ini:"delay"`
		CommandRole   uint64  `ini:"commandrole"`
		BotServer     uint64  `ini:"benbebots"`
		StatChannel   uint64  `ini:"statchannel"`
		PingChannelId uint64  `ini:"pingchannel"`
		PingChannel   discord.ChannelID
	}{}
	bbb.Config.Section("bot.cannedfood").MapTo(&opts)
	bbb.Config.Section("servers").MapTo(&opts)
	opts.PingChannel = discord.ChannelID(opts.PingChannelId)

	var client *session.Session
	if t, err := bbb.LevelDB.Get([]byte("cannedFoodToken"), nil); err == nil {
		token := string(t)
		tmpClient := api.NewClient(token)
		_, err := tmpClient.Me()
		if err != nil {
			log.Println("CannedFood token errored, logging in")
			client, err = bbb.LoginCannedFood()
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
		} else {
			client = session.New(token)
		}
	} else {
		if !errors.Is(err, leveldb.ErrNotFound) {
			log.Println(err)
		} else {
			log.Println("CannedFood token missing, logging in")
		}
		client, err = bbb.LoginCannedFood()
		if err != nil {
			log.Fatalln(err)
		}
	}
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})
	client.AddHandler(bbb.Heartbeater.Init)
	client.AddHandler(bbb.Heartbeater.Heartbeat)

	var validChannels []discord.ChannelID
	validChannelsStr, err := bbb.LevelDB.Get([]byte("cannedFoodValidChannels"), nil)
	if err != nil {
		bbb.Logger.Error(err.Error())
		return
	}

	strs := strings.Fields(string(validChannelsStr))
	validChannels = make([]discord.ChannelID, len(strs))
	for i, v := range strs {
		id, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			bbb.Logger.Error(err.Error())
			return
		}
		validChannels[i] = discord.ChannelID(id)
	}

	client.AddHandler(func(message *gateway.MessageCreateEvent) { // reaction
		if len(message.Mentions) <= 0 && len(message.MentionRoleIDs) <= 0 && !message.MentionEveryone {
			return
		}
		me, err := client.Me()
		if err != nil {
			bbb.Logger.Error(err.Error())
			return
		}
		// check if pinging canned food
		var userPinged bool
		for _, user := range message.Mentions {
			if user.ID == me.ID {
				userPinged = true
				break
			}
		}

		if !userPinged {
			// check if in valid channel
			var validChannel bool
			for _, channel := range validChannels {
				if message.ChannelID == channel {
					validChannel = true
					break
				}
			}
			if !validChannel {
				return
			}

			// check if pinging everyone
			if !message.MentionEveryone {
				// check if pinging any of canned food's roles
				member, err := client.Member(message.GuildID, me.ID)
				if err != nil {
					bbb.Logger.Error(err.Error())
					return
				}
				var rolePinged bool
			roleLoop:
				for _, mrole := range message.MentionRoleIDs {
					for _, role := range member.RoleIDs {
						if mrole == role {
							rolePinged = true
							break roleLoop
						}
					}
				}

				if !rolePinged {
					return
				}
			}
		} else {
			bbb.Logger.Assert2(client.SendMessage(opts.PingChannel, message.URL()))
		}

		delay := time.Duration(opts.Delay[0]+rand.Int63n(opts.Delay[1]-opts.Delay[0])) * time.Millisecond
		time.Sleep(delay)

		bbb.Logger.Assert(client.React(message.ChannelID, message.ID, cannedFoodEmoji))

		log.Printf("CannedFood reacted to a message after %dms\n", delay.Milliseconds())
	})

	reactionStat := Stat{
		Name:      "Canned Foods",
		Value:     0,
		Client:    client.Client,
		ChannelID: discord.ChannelID(opts.StatChannel),
		LevelDB:   bbb.LevelDB,
		Delay:     time.Second * 5,
	}
	reactionStat.Initialise()

	checkReaction := func(emoji discord.Emoji, channelID discord.ChannelID) bool {
		if emoji.APIString() != cannedFoodEmoji {
			return false
		}

		var validChannel bool
		for _, channel := range validChannels {
			if channelID == channel {
				validChannel = true
				break
			}
		}
		return validChannel
	}

	client.AddHandler(func(reaction *gateway.MessageReactionAddEvent) {
		if !checkReaction(reaction.Emoji, reaction.ChannelID) {
			return
		}

		reactionStat.Increment(1)
	})

	client.AddHandler(func(reaction *gateway.MessageReactionRemoveEvent) {
		if !checkReaction(reaction.Emoji, reaction.ChannelID) {
			return
		}

		reactionStat.Increment(-1)
	})

	var commandInitiatorString string
	var commandInitiatorLen int
	var isReady bool
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		commandInitiatorString = "<@" + me.ID.String()
		commandInitiatorLen = len(commandInitiatorString)
		isReady = true
	})

	client.AddHandler(func(message *gateway.MessageCreateEvent) { // commands
		if !isReady {
			return
		}

		// check command initiator
		if len(message.Content) < commandInitiatorLen || message.Content[:commandInitiatorLen] != commandInitiatorString {
			return
		}

		// check
		member, err := client.Member(discord.GuildID(opts.BotServer), message.Author.ID)
		if err != nil {
			return
		}

		allowed := false
		for _, v := range member.RoleIDs {
			if opts.CommandRole == uint64(v) {
				allowed = true
				break
			}
		}
		if !allowed {
			return
		}

		items := strings.Fields(message.Content)
		if len(items) < 3 {
			client.SendMessageReply(message.ChannelID, "invalid syntax!", message.ID)
			return
		}

		switch items[1] {
		case "add":
			channelId, err := strconv.ParseUint(items[2][2:len(items[2])-1], 10, 64)
			if err != nil {
				bbb.Logger.Error(err.Error())
				client.SendMessageReply(message.ChannelID, "error: "+err.Error(), message.ID)
				return
			}
			channel, err := client.Channel(discord.ChannelID(discord.Snowflake(channelId)))
			if err != nil {
				bbb.Logger.Error(err.Error())
				client.SendMessageReply(message.ChannelID, "error: "+err.Error(), message.ID)
				return
			}

			found := false
			for _, v := range validChannels {
				if channel.ID == v {
					found = true
					break
				}
			}
			if found {
				client.SendMessageReply(message.ChannelID, "channel already added", message.ID)
				return
			}

			validChannelsNew := append(validChannels, channel.ID)
			validChannelsStrNew := strconv.AppendUint(append(validChannelsStr, ' '), uint64(channel.ID), 10)

			err = bbb.LevelDB.Put([]byte("cannedFoodValidChannels"), validChannelsStrNew, nil)
			if err != nil {
				bbb.Logger.Error(err.Error())
				client.SendMessageReply(message.ChannelID, "error: "+err.Error(), message.ID)
				return
			}

			validChannels = validChannelsNew
			validChannelsStr = validChannelsStrNew

			client.SendMessageReply(message.ChannelID, "done", message.ID)
		default:
			client.SendMessage(message.ChannelID, "invalid command!")
		}
	})

	bbb.Logger.Assert(client.Open(client.Context()))
	bbb.AddClient(client)
	bbb.CoroutineGroup.Done()
}
