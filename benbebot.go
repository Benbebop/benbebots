package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
	"github.com/go-co-op/gocron/v2"
	"github.com/google/go-querystring/query"
	"golang.org/x/net/html"
)

func scrapeSoundcloudClient() (string, error) {
	// first scrape for a token
	var clientId string

	resp, err := http.Get("https://soundcloud.com/")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// search page scripts for client id
	tokenizer := html.NewTokenizer(resp.Body)
	for {
		if tokenizer.Next() == html.ErrorToken {
			break
		}

		token := tokenizer.Token()
		if token.Type != html.StartTagToken && token.Data != "script" {
			continue
		}

		var url string
		valid := false
		for _, v := range token.Attr {
			if v.Key == "crossorigin" {
				valid = true
			} else if v.Key == "src" {
				url = v.Val
			}
		}

		if !valid || url == "" {
			continue
		}

		resp, err := http.Get(url)
		if err != nil {
			lgr.Error(err)
			continue
		}
		defer resp.Body.Close()

		prog := 0
		data := make([]byte, 2048)
		for {
			n, err := resp.Body.Read(data)

			for _, c := range data[:n] {
				if prog >= 10 {
					if c == '"' || c == '\'' {
						prog = -1
						break
					}
					clientId += string(c)
					continue
				}

				if c == ("client_id=")[prog] {
					prog += 1
				} else if c != ' ' {
					prog = 0
				}
			}
			if prog < 0 {
				break
			}
			if err == io.EOF {
				break
			}
		}

		if clientId != "" {
			break
		}
	}

	ldb.Put([]byte("soundcloudClientId"), []byte(clientId), nil)

	return clientId, nil
}

func benbebot() {
	cfgSec := cfg.Section("bot.benbebot")

	client := session.New("Bot " + tokens["benbebot"].Password)
	client.AddIntents(gateway.IntentGuildPresences | gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddIntents(gateway.IntentGuildMessages | gateway.IntentDirectMessages)
	client.AddIntents(gateway.IntentGuilds)
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})
	router := cmdroute.NewRouter()

	{ // soundclown
		opts := struct {
			Cron      string `ini:"motdcron"`
			ChannelId uint64 `ini:"motdchannel"`
			Channel   discord.ChannelID
			EndPoint  string `ini:"motdendpoint"`
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))

		var recents [30]uint
		var recentsIndex uint64
		client.AddHandler(func(*gateway.ReadyEvent) {
			validChannelsStr, err := ldb.Get([]byte("recentSoundclowns"), nil)
			if err != nil {
				lgr.Error(err)
				return
			}

			strs := strings.Fields(string(validChannelsStr))
			recentsIndex, err = strconv.ParseUint(strs[0], 10, 64)
			if err != nil {
				lgr.Error(err)
				return
			}
			strs = strs[1:]
			for i, v := range strs {
				id, err := strconv.ParseUint(v, 10, 64)
				if err != nil {
					lgr.Error(err)
					return
				}
				recents[i] = uint(id)
			}
		})

		var clientId string

		sendNewSoundclown := func() {
			// request soundcloud
			options := struct {
				ClientId   string `url:"client_id"`
				Query      string `url:"q"`                   // query, * for anything
				GenreTag   string `url:"filter.genre_or_tag"` // tag to search for
				CreatedAt  string `url:"filter.created_at"`
				Sort       string `url:"sort"` // sort order
				Limit      int    `url:"limit"`
				Offset     int    `url:"offset"`
				LinkedPart int    `url:"linked_partitioning"`
				Version    uint64 `url:"app_version"`
				Locale     string `url:"app_locale"`
			}{
				ClientId:   clientId,
				Query:      "*",
				GenreTag:   "soundclown",
				CreatedAt:  "last_month",
				Sort:       "recent",
				Limit:      20,
				LinkedPart: 1,
				Version:    1714468731,
				Locale:     "en",
			}
			var resp *http.Response
		reqLoop:
			for i := 0; i < 4; i++ {
				qry, err := query.Values(options)
				if err != nil {
					lgr.Error(err)
					return
				}
				resp, err = http.Get("https://api-v2.soundcloud.com/search/tracks?" + qry.Encode())
				if err != nil {
					lgr.Error(err)
					return
				}
				switch resp.StatusCode {
				case 401:
					clientId, err = scrapeSoundcloudClient()
					if err != nil {
						lgr.Error(err)
						return
					}
					options.ClientId = clientId
				case 200:
					break reqLoop
				default:
					lgr.Error(fmt.Errorf("couldnt get soundclouds: %s", resp.Status))
					break reqLoop
				}
			}
			if resp.StatusCode != 200 {
				lgr.Error(fmt.Errorf("couldnt get soundclouds: %s", resp.Status))
				return
			}

			// get recent tracks
			data, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				lgr.Error(err)
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
				lgr.Error(err)
				return
			}

			// sort by most recent
			sort.Slice(tracks.Collection, func(i, j int) bool {
				return tracks.Collection[i].CreatedAt.After(tracks.Collection[j].CreatedAt)
			})

			// filter sent already
			toSend := tracks.Collection[0]
			for _, track := range tracks.Collection {
				sentAlready := false
				for _, rec := range recents {
					if track.Id == rec {
						sentAlready = true
						break
					}
				}
				toSend = track
				if !sentAlready {
					toSend = track
					break
				}
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
			ldb.Put([]byte("recentSoundclowns"), str, nil)

			// send
			log.Println("sending soundclown")
			lgr.Assert2(client.SendMessage(opts.Channel, toSend.Permalink))
		}

		client.AddHandler(func(*gateway.ReadyEvent) {
			// get soundcloud token
			cltId, err := ldb.Get([]byte("soundcloudClientId"), nil)
			if err != nil {
				lgr.Error(err)
				clientId, err = scrapeSoundcloudClient()
				if err != nil {
					lgr.Error(err)
				}
			} else {
				clientId = string(cltId)
			}

			var scLock bool

			url := "https://soundcloud.com/"
			urlLen := len(url)
			lgr.Assert2(crn.NewJob(gocron.CronJob(opts.Cron, true), gocron.NewTask(func() {
				if scLock {
					return
				}
				scLock = true
				messages, err := client.Messages(opts.Channel, 1)
				if err != nil {
					lgr.Error(err)
					sendNewSoundclown()
					scLock = false
					return
				}
				message := messages[0]
				if !(len(message.Content) >= urlLen && message.Content[:urlLen] == url) {
					sendNewSoundclown()
					scLock = false
					return
				}
				lgr.Assert2(client.CrosspostMessage(opts.Channel, messages[0].ID))

				sendNewSoundclown()
				scLock = false
			})))
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
				return cmdErrorResp(err)
			}

			buffer, err := os.ReadFile(lgr.Directory + options.Id + ".log")
			if err != nil {
				return cmdErrorResp(err)
			}

			if len(buffer) > 2000 {
				return cmdErrorResp(errors.New("too long woops"))
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
				lgr.Error(errors.New("sender is 0"))
				return &api.InteractionResponseData{
					Content: option.NewNullableString("how the fuck"),
					Flags:   discord.EphemeralMessage,
				}
			}
			ok, id, err := lgr.Assert(client.Ban(data.Event.GuildID, sndr, api.BanData{
				DeleteDays:     option.ZeroUint,
				AuditLogReason: "sex command",
			}))
			if !ok {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("error `" + id + "`: " + err.Error()),
					Flags:   discord.EphemeralMessage,
				}
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString("kys"),
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
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
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
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fileBuffer := make([]byte, toDownload.Size)
			resp, err := http.Get(toDownload.URL)
			if err != nil {
				lgr.Error(err)
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			if _, err := io.ReadFull(resp.Body, fileBuffer); err != nil {
				lgr.Error(err)
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			debugInfo := struct {
				AdVideoId string `json:"addebug_videoId"`
			}{}
			fail, _, _ := lgr.Assert(json.Unmarshal(fileBuffer, &debugInfo))
			if fail {
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fail, _, _ = lgr.Assert2(client.SendMessageReply(opts.Channel, "https://www.youtube.com/watch?v="+debugInfo.AdVideoId, message.ID))
			if fail {
				lgr.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
			}
		})
	}

	client.AddInteractionHandler(router)
	client.Open(client.Context())
	botGoroutineGroup.Done()
}
