package benbebots

import (
	"context"
	"errors"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/stats"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/syndtr/goleveldb/leveldb"
)

func LoginCannedFood() (*session.Session, error) {
	client, err := session.Login(context.Background(), tokens["cannedFood"].Login, tokens["cannedFood"].Password, "")
	if err == nil {
		lvldb.Put([]byte("cannedFoodToken"), []byte(client.Token), nil)
		return client, nil
	}
	return nil, err
}

var cannedFoodEmoji = discord.NewAPIEmoji(discord.NullEmojiID, `🥫`)

type CannedFoodConfig struct {
	CommandRole discord.RoleID    `toml:"command_role"`
	StatChannel discord.ChannelID `toml:"stat_channel"`
	PingChannel discord.ChannelID `toml:"ping_channel"`
	Delay       []int64
}

func (Benbebots) CANNEDFOOD() *session.Session {
	if !config.Components.IsEnabled("canned_food") {
		log.Info("canned food component has been disabled")
		return nil
	}

	var client *session.Session
	if t, err := lvldb.Get([]byte("cannedFoodToken"), nil); err == nil {
		token := string(t)
		tmpClient := api.NewClient(token)
		_, err := tmpClient.Me()
		if err != nil {
			log.Warn("CannedFood token errored, logging in")
			client, err = LoginCannedFood()
			if err != nil {
				log.Fatal("%s", err)
			}
		} else {
			client = session.New(token)
		}
	} else {
		if !errors.Is(err, leveldb.ErrNotFound) {
			log.Error("%s", err)
		} else {
			log.Debug("CannedFood token missing, logging in")
		}
		client, err = LoginCannedFood()
		if err != nil {
			log.Fatal("%s", err)
		}
	}
	client.AddHandler(heartbeater.Init)
	client.AddHandler(heartbeater.Heartbeat)

	var validChannels []discord.ChannelID
	validChannelsStr, err := lvldb.Get([]byte("cannedFoodValidChannels"), nil)
	if err != nil && !errors.Is(err, leveldb.ErrNotFound) {
		log.Fatal("%s", err)
	}

	strs := strings.Fields(string(validChannelsStr))
	validChannels = make([]discord.ChannelID, len(strs))
	for i, v := range strs {
		id, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			log.Fatal("%s", err)
		}
		validChannels[i] = discord.ChannelID(id)
	}

	client.AddHandler(func(message *gateway.MessageCreateEvent) { // reaction
		if len(message.Mentions) <= 0 && len(message.MentionRoleIDs) <= 0 && !message.MentionEveryone {
			return
		}
		me, err := client.Me()
		if err != nil {
			log.ErrorQuick(err)
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
					log.ErrorQuick(err)
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
			log.Assert(client.SendMessage(config.Bot.CannedFood.PingChannel, message.URL()))
		}

		delay := time.Duration(config.Bot.CannedFood.Delay[0]+rand.Int63n(config.Bot.CannedFood.Delay[1]-config.Bot.CannedFood.Delay[0])) * time.Millisecond
		time.Sleep(delay)

		log.Assert(client.React(message.ChannelID, message.ID, cannedFoodEmoji))

		log.Info("CannedFood reacted to a message after %dms\n", delay.Milliseconds())
	})

	reactionStat := stats.Stat{
		Name:      "Canned Foods",
		Value:     0,
		Client:    client.Client,
		ChannelID: config.Bot.CannedFood.StatChannel,
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
		member, err := client.Member(config.Servers.Benbebots, message.Author.ID)
		if err != nil {
			return
		}

		allowed := false
		for _, v := range member.RoleIDs {
			if config.Bot.CannedFood.CommandRole == v {
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
				log.ErrorQuick(err)
				client.SendMessageReply(message.ChannelID, "error: "+err.Error(), message.ID)
				return
			}
			channel, err := client.Channel(discord.ChannelID(discord.Snowflake(channelId)))
			if err != nil {
				log.ErrorQuick(err)
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
				log.ErrorQuick(err)
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

	return client
}
