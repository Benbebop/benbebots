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

	"benbebop.net/benbebots/internal/stats"
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

func (Benbebots) FNAF() *session.Session { // gnerb
	if !component.IsEnabled("gnerb") {
		logs.Info("gnerb component has been disabled")
		return nil
	}
	opts := struct {
		Time        time.Duration `ini:"poutime"`
		Destination uint64        `ini:"destination"`
		StatChannel uint64        `ini:"statchannel"`
	}{}
	config.Section("bot.fnaf").MapTo(&opts)

	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	fnafStat := stats.Stat{
		Name:      "Gnerbs",
		Value:     0,
		Client:    client,
		ChannelID: discord.ChannelID(opts.StatChannel),
		LevelDB:   lvldb,
		Delay:     time.Second * 5,
	}
	fnafStat.Initialise()

	defer func() {
		go func() {
			channel := discord.ChannelID(opts.Destination)
			sleep, _ := getWaitTime(time.Now().UTC(), opts.Time, 0)
			logs.Info("sending next pou in %dm.", sleep/time.Minute)
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
		AnnounceReady(&gateway.ReadyEvent{
			User: *me,
		})
	}
	return nil
}

func LoginCannedFood() (*session.Session, error) {
	var err error
	for i := 1; i < 3; i++ {
		client, err := session.Login(context.Background(), tokens["cannedFood"].Login, tokens["cannedFood"].Password, "")
		if err == nil {
			lvldb.Put([]byte("cannedFoodToken"), []byte(client.Token), nil)
			return client, nil
		}
		logs.ErrorQuick(err)
	}
	return nil, err
}

var cannedFoodEmoji = discord.NewAPIEmoji(discord.NullEmojiID, `🥫`)

func (Benbebots) CANNEDFOOD() *session.Session {
	if !component.IsEnabled("cannedfood") {
		logs.Info("canned food component has been disabled")
		return nil
	}
	opts := struct {
		Delay         []int64 `ini:"delay"`
		CommandRole   uint64  `ini:"commandrole"`
		BotServer     uint64  `ini:"benbebots"`
		StatChannel   uint64  `ini:"statchannel"`
		PingChannelId uint64  `ini:"pingchannel"`
		PingChannel   discord.ChannelID
	}{}
	config.Section("bot.cannedfood").MapTo(&opts)
	config.Section("servers").MapTo(&opts)
	opts.PingChannel = discord.ChannelID(opts.PingChannelId)

	var client *session.Session
	if t, err := lvldb.Get([]byte("cannedFoodToken"), nil); err == nil {
		token := string(t)
		tmpClient := api.NewClient(token)
		_, err := tmpClient.Me()
		if err != nil {
			logs.Warn("CannedFood token errored, logging in")
			client, err = LoginCannedFood()
			if err != nil {
				logs.Fatal("%s", err)
			}
		} else {
			client = session.New(token)
		}
	} else {
		if !errors.Is(err, leveldb.ErrNotFound) {
			logs.Error("%s", err)
		} else {
			logs.Debug("CannedFood token missing, logging in")
		}
		client, err = LoginCannedFood()
		if err != nil {
			logs.Fatal("%s", err)
		}
	}
	client.AddHandler(AnnounceReady)
	client.AddHandler(heartbeater.Init)
	client.AddHandler(heartbeater.Heartbeat)

	var validChannels []discord.ChannelID
	validChannelsStr, err := lvldb.Get([]byte("cannedFoodValidChannels"), nil)
	if err != nil && !errors.Is(err, leveldb.ErrNotFound) {
		logs.Fatal("%s", err)
	}

	strs := strings.Fields(string(validChannelsStr))
	validChannels = make([]discord.ChannelID, len(strs))
	for i, v := range strs {
		id, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			logs.Fatal("%s", err)
		}
		validChannels[i] = discord.ChannelID(id)
	}

	client.AddHandler(func(message *gateway.MessageCreateEvent) { // reaction
		if len(message.Mentions) <= 0 && len(message.MentionRoleIDs) <= 0 && !message.MentionEveryone {
			return
		}
		me, err := client.Me()
		if err != nil {
			logs.ErrorQuick(err)
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
					logs.ErrorQuick(err)
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
			logs.Assert(client.SendMessage(opts.PingChannel, message.URL()))
		}

		delay := time.Duration(opts.Delay[0]+rand.Int63n(opts.Delay[1]-opts.Delay[0])) * time.Millisecond
		time.Sleep(delay)

		logs.Assert(client.React(message.ChannelID, message.ID, cannedFoodEmoji))

		logs.Info("CannedFood reacted to a message after %dms\n", delay.Milliseconds())
	})

	reactionStat := stats.Stat{
		Name:      "Canned Foods",
		Value:     0,
		Client:    client.Client,
		ChannelID: discord.ChannelID(opts.StatChannel),
		LevelDB:   lvldb,
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
				logs.ErrorQuick(err)
				client.SendMessageReply(message.ChannelID, "error: "+err.Error(), message.ID)
				return
			}
			channel, err := client.Channel(discord.ChannelID(discord.Snowflake(channelId)))
			if err != nil {
				logs.ErrorQuick(err)
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

			err = lvldb.Put([]byte("cannedFoodValidChannels"), validChannelsStrNew, nil)
			if err != nil {
				logs.ErrorQuick(err)
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

	logs.Assert(client.Open(client.Context()))
	return client
}
