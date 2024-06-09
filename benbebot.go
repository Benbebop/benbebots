package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
	"github.com/go-co-op/gocron/v2"
)

func (bbb *Benbebots) RunBenbebot() {
	cfgSec := bbb.Config.Section("bot.benbebot")

	client := session.New("Bot " + bbb.Tokens["benbebot"].Password)
	client.AddIntents(gateway.IntentGuildPresences | gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddIntents(gateway.IntentGuildMessages | gateway.IntentDirectMessages)
	client.AddIntents(gateway.IntentGuilds)
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})
	client.AddHandler(bbb.Heartbeater.Init)
	client.AddHandler(bbb.Heartbeater.Heartbeat)
	router := cmdroute.NewRouter()

	{ // soundclown
		opts := struct {
			Cron        string `ini:"motdcron"`
			ChannelId   uint64 `ini:"motdchannel"`
			Channel     discord.ChannelID
			EndPoint    string `ini:"motdendpoint"`
			StatChannel uint64 `ini:"motdstatchannel"`
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))

		scClient := SoundcloudClient{
			MaxRetries: 1,
			LevelDB:    bbb.LevelDB,
		}
		scStat := Stat{
			Name:      "Soundclowns",
			Value:     0,
			Client:    client.Client,
			LevelDB:   bbb.LevelDB,
			ChannelID: discord.ChannelID(opts.StatChannel),
			Delay:     time.Second * 5,
		}
		scStat.Initialise()

		var recents [30]uint
		var recentsIndex uint64
		client.AddHandler(func(*gateway.ReadyEvent) {
			validChannelsStr, err := bbb.LevelDB.Get([]byte("recentSoundclowns"), nil)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}

			strs := strings.Fields(string(validChannelsStr))
			recentsIndex, err = strconv.ParseUint(strs[0], 10, 64)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			strs = strs[1:]
			for i, v := range strs {
				id, err := strconv.ParseUint(v, 10, 64)
				if err != nil {
					bbb.Logger.Error(err.Error())
					return
				}
				recents[i] = uint(id)
			}
		})

		sendNewSoundclown := func() {
			// request soundcloud
			resp, err := scClient.Request("GET", "recent-tracks/soundclown", struct {
				Limit      int    `url:"limit"`
				Offset     int    `url:"offset"`
				LinkedPart int    `url:"linked_partitioning"`
				Version    uint64 `url:"app_version"`
				Locale     string `url:"app_locale"`
			}{
				Limit:      20,
				LinkedPart: 1,
				Version:    1715268073,
				Locale:     "en",
			}, "")
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			defer resp.Body.Close()
			if resp.StatusCode != 200 {
				bbb.Logger.Error(fmt.Errorf("couldnt get soundclouds: %s", resp.Status).Error())
				return
			}

			// get recent tracks
			data, err := io.ReadAll(resp.Body)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			tracks := struct {
				Collection []struct {
					Artwork      string    `json:"artwork_url"`
					Title        string    `json:"title"`
					Description  string    `json:"description"`
					Comments     uint      `json:"comment_count"`
					Likes        uint      `json:"likes_count"`
					Plays        uint      `json:"playback_count"`
					Reposts      uint      `json:"reposts_count"`
					CreatedAt    time.Time `json:"created_at"`
					Duration     uint      `json:"duration"`
					EmbeddableBy string    `json:"embeddable_by"`
					Id           uint      `json:"id"`
					Kind         string    `json:"kind"`
					Permalink    string    `json:"permalink_url"`
					Public       bool      `json:"public"`
					Sharing      string    `json:"sharing"`
				} `json:"collection"`
				Next string `json:"next_href"`
			}{}
			err = json.Unmarshal(data, &tracks)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}

			// filter sent already
			toSend, found := tracks.Collection[0], false
			for _, track := range tracks.Collection {
				sentAlready := false
				for _, rec := range recents {
					if track.Id == rec {
						sentAlready = true
						break
					}
				}
				if !sentAlready {
					toSend = track
					found = true
					break
				}
			}

			if !found {
				bbb.Logger.Error("could not find a soundcloud within 20 tracks")
				return
			}

			// add to recents
			recents[recentsIndex] = toSend.Id
			recentsIndex += 1
			if recentsIndex >= 30 {
				recentsIndex = 0
			}
			var str []byte
			str = append(strconv.AppendUint(str, recentsIndex, 10), ' ')
			for i := 0; i < 30; i++ {
				str = append(strconv.AppendUint(str, uint64(recents[i]), 10), ' ')
			}
			bbb.LevelDB.Put([]byte("recentSoundclowns"), str, nil)

			// send
			log.Println("sending soundclown")
			bbb.Logger.Assert2(client.SendMessage(opts.Channel, toSend.Permalink))
		}

		client.AddHandler(func(*gateway.ReadyEvent) {
			// get soundcloud token
			cltId, err := bbb.LevelDB.Get([]byte("soundcloudClientId"), nil)
			if err != nil {
				bbb.Logger.Error(err.Error())
				err = scClient.GetClientId()
				if err != nil {
					bbb.Logger.Error(err.Error())
				}
			} else {
				scClient.ClientId = string(cltId)
			}

			url := "https://soundcloud.com/"
			urlLen := len(url)
			var mut sync.Mutex
			bbb.Logger.Assert2(bbb.Cron.NewJob(gocron.CronJob(opts.Cron, true), gocron.NewTask(func() {
				mut.Lock()
				defer mut.Unlock()
				messages, err := client.Messages(opts.Channel, 1)
				if err != nil {
					bbb.Logger.Error(err.Error())
					return
				}
				message := messages[0]
				if len(message.Content) >= urlLen && message.Content[:urlLen] == url {
					fail, _ := bbb.Logger.Assert2(client.CrosspostMessage(opts.Channel, messages[0].ID))
					if !fail {
						scStat.Increment(1)
					}
				}

				sendNewSoundclown()
			}), gocron.WithSingletonMode(gocron.LimitModeReschedule)))
		})

		client.AddHandler(func(message *gateway.MessageDeleteEvent) {
			if message.ChannelID != opts.Channel {
				return
			}

			sendNewSoundclown()
		})
	}

	{ // get logs
		router.AddFunc("getlog", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options = struct {
				Id string `discord:"id"`
			}{}
			if err := data.Options.Unmarshal(&options); err != nil {
				return bbb.CommandError(err)
			}

			buffer, err := os.ReadFile(bbb.Logger.Directory + options.Id + ".log")
			if err != nil {
				return bbb.CommandError(err)
			}

			if len(buffer) > 2000 {
				return bbb.CommandError(errors.New("too long woops"))
			}

			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("```\n%s\n```", string(buffer))),
			}
		})
	}

	{ // sex command
		router.AddFunc("sex", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			sndr := data.Event.SenderID()
			if sndr == 0 {
				bbb.Logger.Error("sender is 0")
				return &api.InteractionResponseData{
					Content: option.NewNullableString("how the fuck"),
					Flags:   discord.EphemeralMessage,
				}
			}
			ok, err := bbb.Logger.Assert(client.Ban(data.Event.GuildID, sndr, api.BanData{
				DeleteDays:     option.ZeroUint,
				AuditLogReason: "sex command",
			}))
			if !ok {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("error: " + err.Error()),
					Flags:   discord.EphemeralMessage,
				}
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString("idk"),
				Flags:   discord.EphemeralMessage,
			}
		})
	}

	{ // extract ad id
		opts := struct {
			ChannelId uint64 `ini:"adextractorchannel"`
			Channel   discord.ChannelID
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))

		client.AddHandler(func(message *gateway.MessageCreateEvent) {
			if message.ChannelID != opts.Channel {
				return
			}
			if message.Author.Bot {
				return
			}

			if len(message.Attachments) < 1 {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			toDownload := message.Attachments[0]
			for _, attachemnt := range message.Attachments {
				if attachemnt.Filename == "message.txt" {
					toDownload = attachemnt
					break
				}
			}

			if toDownload.Size > 25000 {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fileBuffer := make([]byte, toDownload.Size)
			resp, err := http.Get(toDownload.URL)
			if err != nil {
				bbb.Logger.Error(err.Error())
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			if _, err := io.ReadFull(resp.Body, fileBuffer); err != nil {
				bbb.Logger.Error(err.Error())
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			debugInfo := struct {
				AdVideoId string `json:"addebug_videoId"`
			}{}
			fail, _ := bbb.Logger.Assert(json.Unmarshal(fileBuffer, &debugInfo))
			if fail {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fail, _ = bbb.Logger.Assert2(client.SendMessageReply(opts.Channel, "https://www.youtube.com/watch?v="+debugInfo.AdVideoId, message.ID))
			if fail {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
			}
		})
	}

	{
		opts := struct {
			Channel   discord.ChannelID
			ChannelId uint64        `ini:"pingchannel"`
			StatsId   uint64        `ini:"pingstatchannel"`
			Freq      time.Duration `ini:"pingfreq"`
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))
		var toPingMux sync.Mutex
		toPing := map[discord.UserID]uint64{}
		var pingerLock bool

		pgStat := Stat{
			Name:      "Pings",
			Value:     0,
			Client:    client.Client,
			LevelDB:   bbb.LevelDB,
			ChannelID: discord.ChannelID(opts.StatsId),
			Delay:     time.Second * 5,
		}
		pgStat.Initialise()

		wakePinger := func() {
			if pingerLock {
				return
			}
			pingerLock = true

			go func() {
				for {
					for i := range toPing {
						client.SendMessage(opts.Channel, "<@"+i.String()+">")
						pgStat.Increment(1)
						toPingMux.Lock()
						toPing[i] -= 1
						if toPing[i] <= 0 {
							delete(toPing, i)
						}
						toPingMux.Unlock()
						time.Sleep(opts.Freq)
					}
					if len(toPing) <= 0 {
						break
					}
				}
				pingerLock = false
			}()
		}

		router.AddFunc("pingme", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options = struct {
				Times float64 `discord:"times"`
			}{}
			if err := data.Options.Unmarshal(&options); err != nil {
				return bbb.CommandError(err)
			}
			userId := data.Event.SenderID()
			if userId <= 0 {
				return nil
			}

			toPingMux.Lock()
			defer toPingMux.Unlock()
			val, ok := toPing[userId]
			if ok {
				if math.Signbit(options.Times) {
					abs := uint64(math.Abs(options.Times))
					if abs < val {
						toPing[userId] = val - abs
					} else {
						delete(toPing, userId)
					}
				} else {
					toPing[userId] += uint64(math.Abs(options.Times))
				}
			} else {
				toPing[userId] = uint64(max(0, options.Times))
			}

			wakePinger()

			if _, ok := toPing[userId]; !ok {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("set to no longer ping you"),
				}
			}

			timeToTake := time.Now()
			for _, v := range toPing {
				timeToTake = timeToTake.Add(opts.Freq * time.Duration(v))
			}

			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("set to ping you %d times\nthis will be finished <t:%d:R> aproximately", toPing[userId], timeToTake.Unix())),
			}
		})
	}

	client.AddInteractionHandler(router)
	client.Open(client.Context())
	bbb.AddClient(client)
	bbb.CoroutineGroup.Done()
}
