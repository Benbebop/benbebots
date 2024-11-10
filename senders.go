package main

import (
	"fmt"
	"math/rand"
	"time"

	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/stats"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/state"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
)

type FamilyGuyConfig struct {
	CacheChannel  discord.ChannelID `toml:"cache_channel"`
	PublicChannel discord.ChannelID `toml:"public_channel"`
	StatChannel   discord.ChannelID `toml:"stat_channel"`
	TestChannel   discord.ChannelID `toml:"test"`
	Frequency     time.Duration     `toml:"frequency"`
}

func (Benbebots) FAMILYGUY() *state.State {
	if !config.Components.IsEnabled("family_guy") {
		log.Info("family guy component has been disabled")
		return nil
	}

	client := state.New("Bot " + tokens["familyGuy"].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(heartbeater.Init)
	client.AddHandler(heartbeater.Heartbeat)

	fgStat := stats.Stat{
		Name:      "Family Guys",
		Value:     0,
		Client:    client.Client,
		ChannelID: config.Bot.FamilyGuy.StatChannel,
		LevelDB:   lvldb,
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
			log.ErrorQuick(err)
			return
		}

		users = append(users, discord.ChannelID(config.Bot.FamilyGuy.PublicChannel))
		index := 1
		for _, guild := range guilds {
			members, err := client.Members(guild.ID)
			if err != nil {
				log.ErrorQuick(err)
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
		messages, err := client.Messages(config.Bot.FamilyGuy.CacheChannel, 1000)
		if err != nil {
			log.ErrorQuick(err)
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
		client.ModifyChannel(config.Bot.FamilyGuy.CacheChannel, api.ModifyChannelData{
			Topic: option.NewNullableString(fmt.Sprintf("current family guy clips in rotation: %d", len(clips))),
		})

		currentTicker = time.NewTicker(config.Bot.FamilyGuy.Frequency / time.Duration(len(users)))
		for {
			<-currentTicker.C
			channel := config.Bot.FamilyGuy.TestChannel
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

	return client
}

/*func (Benbebots) BANKBEMER() *session.Session {
	if !component.IsEnabled("bankbemer") {
		log.Info("bank bemer component has been disabled")
		return nil
	}

	client := state.New("Bot " + tokens["bankbemer"].Password)

	var wake <-chan time.Time
	client.AddHandler(func(ready *gateway.ReadyEvent) {
		for {
			var users []discord.UserID

			guilds, err := client.Guilds()
			if err != nil {
				log.Fatal("%s", err)
			}
			for _, guild := range guilds {
				members, err := client.Members(guild.ID)
				if err != nil {
					log.Fatal("%s", err)
				}
				for _, member := range members {
					users
				}
			}
			wake = time.After()
			time := <-wake
			if time.IsZero() {
				continue
			}
		}
	})

	return client.Session
}
*/
