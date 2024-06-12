package main

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/state"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
)

func (bbb *Benbebots) RunFamilyGuy() {
	opts := struct {
		CacheChannelId uint64 `ini:"cachechannel"`
		cacheChannel   discord.ChannelID
		Frequency      time.Duration `ini:"frequency"`
		StatChannel    uint64        `ini:"statchannel"`
		PublicChannel  uint64        `ini:"publicchannel"`
		TestId         uint64        `ini:"test"`
		Test           discord.ChannelID
	}{}
	bbb.Logger.Assert(bbb.Config.Section("bot.familyguy").StrictMapTo(&opts))
	opts.cacheChannel = discord.ChannelID(opts.CacheChannelId)
	if opts.TestId != 0 {
		opts.Test = discord.ChannelID(opts.TestId)
	}

	client := state.New("Bot " + bbb.Tokens["familyGuy"].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})
	client.AddHandler(bbb.Heartbeater.Init)
	client.AddHandler(bbb.Heartbeater.Heartbeat)

	fgStat := Stat{
		Name:      "Family Guys",
		Value:     0,
		Client:    client.Client,
		ChannelID: discord.ChannelID(opts.StatChannel),
		LevelDB:   bbb.LevelDB,
		Delay:     time.Second * 5,
	}
	fgStat.Initialise()

	var users []discord.ChannelID
	var clips []string
	var currentTicker *time.Ticker

	client.AddHandler(func(*gateway.ReadyEvent) {
		// get users
		guilds, err := client.Guilds()
		if err != nil {
			bbb.Logger.Error(err.Error())
			return
		}

		users = append(users, discord.ChannelID(opts.PublicChannel))
		index := 1
		for _, guild := range guilds {
			members, err := client.Members(guild.ID)
			if err != nil {
				bbb.Logger.Error(err.Error())
				continue
			}
			users = append(users, make([]discord.ChannelID, len(members))...)

			for _, member := range members {
				exists := false
				for _, id := range users[:index] {
					if id == discord.ChannelID(member.User.ID) {
						exists = true
					}
				}
				if exists {
					continue
				}
				priv, err := client.CreatePrivateChannel(member.User.ID)
				if err != nil {
					continue
				}
				users[index] = priv.ID
				index += 1
			}
		}
		users = users[:index]

		// get clips
		messages, err := client.Messages(opts.cacheChannel, 1000)
		if err != nil {
			bbb.Logger.Error(err.Error())
			return
		}

		clips, index = make([]string, len(messages)), 0
		for _, message := range messages {
			attachCount := len(message.Attachments)
			if attachCount > 0 {
				clips[index] = message.Attachments[0].URL
				index += 1
				if attachCount > 1 {
					clips = append(clips, make([]string, attachCount)...)
					for _, attachment := range message.Attachments[1:] {
						clips[index] = attachment.URL
						index += 1
					}
				}
			}
		}
		clips = clips[:index]
		client.ModifyChannel(opts.cacheChannel, api.ModifyChannelData{
			Topic: option.NewNullableString(fmt.Sprintf("current family guy clips in rotation: %d", len(clips))),
		})

		currentTicker = time.NewTicker(opts.Frequency / time.Duration(len(users)))
		for {
			<-currentTicker.C
			channel := opts.Test
			if channel <= 0 {
				channel = users[rand.Intn(len(users))]
			}
			_, err = client.SendMessage(channel, clips[rand.Intn(len(clips))])
			if err != nil {
				continue
			}
			fgStat.Increment(1)
		}
	})

	client.Open(client.Context())
	bbb.AddClient(client.Session)
	bbb.CoroutineGroup.Done()
}
