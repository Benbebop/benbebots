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
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
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

	client.AddHandler(func(*gateway.ReadyEvent) { // soundclown
		opts := struct {
			Frequency time.Duration `ini:"motdfreq"`
			ChannelId uint64        `ini:"motdchannel"`
			Channel   discord.ChannelID
			EndPoint  string `ini:"motdendpoint"`
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))
		var recents [30]string
		recentsIndex := 0

		msgs, err := client.Messages(opts.Channel, 30)
		if err != nil {
			lgr.Error(err)
			return
		}
		url := "https://soundcloud.com/"
		urlLen := len(url)
		for _, message := range msgs {
			if len(message.Content) >= urlLen && message.Content[:urlLen] == url {
				recents[recentsIndex] = message.Content
				recentsIndex += 1
			}
		}

		crn.AddFunc("0 0 0,12 * * *", func() {
			id, err := scrapeSoundcloudClient()
			if err != nil {
				lgr.Error(err)
				return
			}

			options, err := query.Values(struct {
				ClientId   string `url:"client_id"`
				Limit      int    `url:"limit"`
				Offset     int    `url:"offset"`
				LinkedPart int    `url:"linked_partitioning"`
				Version    uint64 `url:"app_version"`
				Locale     string `url:"app_locale"`
			}{
				ClientId:   id,
				Limit:      20,
				LinkedPart: 1,
				Version:    1708424140,
				Locale:     "en",
			})
			if err != nil {
				lgr.Error(err)
				return
			}

			tracks := struct {
				Collection []struct {
					Artwork      string    `json:"artwork_url"`
					Title        string    `json:"title"`
					Description  string    `json:"description"`
					Comments     int       `json:"comment_count"`
					Likes        int       `json:"likes_count"`
					Plays        int       `json:"playback_count"`
					Reposts      int       `json:"reposts_count"`
					CreatedAt    time.Time `json:"created_at"`
					Duration     int       `json:"duration"`
					EmbeddableBy string    `json:"embeddable_by"`
					Id           int       `json:"id"`
					Kind         string    `json:"kind"`
					Permalink    string    `json:"permalink_url"`
					Public       bool      `json:"public"`
					Sharing      string    `json:"sharing"`
				} `json:"collection"`
				Next string `json:"next_href"`
			}{}
			resp, err := http.Get("https://api-v2.soundcloud.com/recent-tracks/soundclown?" + options.Encode())
			if err != nil {
				lgr.Error(err)
				return
			}
			data, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				lgr.Error(err)
				return
			}
			err = json.Unmarshal(data, &tracks)
			if err != nil {
				lgr.Error(err)
				return
			}

			toSend, toSendValue := tracks.Collection[0], 0
			for _, track := range tracks.Collection {
				sentAlready := false
				for _, rec := range recents {
					if track.Permalink == rec {
						sentAlready = true
						break
					}
				}
				if sentAlready {
					continue
				}
				value := track.Likes + max(int(float32(track.Plays)*0.15), 1)
				if value > toSendValue {
					toSend, toSendValue = track, value
				}
			}

			recents[recentsIndex] = toSend.Permalink
			recentsIndex += 1
			if recentsIndex >= len(recents) {
				recentsIndex = 0
			}
			client.SendMessage(opts.Channel, toSend.Permalink)
		})
	})

	r := cmdroute.NewRouter()
	r.AddFunc("getlog", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
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

	client.AddInteractionHandler(r)

	client.Open(client.Context())
	botGoroutineGroup.Done()
}
