package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/state"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

var sqlTables = map[string]string{
	"familyGuy": "family_guy",
	"sheldon":   "young_sheldon",
}

func familyguy(name string) {
	opts := struct {
		CacheChannel uint64        `ini:"cachechannel"`
		Frequency    time.Duration `ini:"frequency"`
	}{}
	sqlTable := sqlTables[name]

	client := state.New("Bot " + tokens[name].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})

	var deferResp = api.InteractionResponse{
		Type: api.DeferredMessageInteractionWithSource,
	}

	// add clips
	r := cmdroute.NewRouter()
	r.Sub("clip", func(sr *cmdroute.Router) {
		sr.AddFunc("add", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options = struct {
				Attachment discord.Attachment `discord:"file"`
			}{}
			if err := data.Options.Unmarshal(&options); err != nil {
				return cmdErrorResp(err)
			}
			client.RespondInteraction(data.Event.ID, data.Event.Token, deferResp)
			localFile, err := os.CreateTemp(dirs.Temp, name+"_*")
			if err != nil {
				return cmdErrorResp(err)
			}
			defer localFile.Close()
			s := len(options.Attachment.Filename) - 32
			if s < 0 {
				s = 0
			}
			truncatedFileName := options.Attachment.Filename[s:]
			remoteFile := sendpart.File{
				Name: options.Attachment.Filename,
			}
			var remoteWriter *io.PipeWriter
			remoteFile.Reader, remoteWriter = io.Pipe()
			splitter := io.MultiWriter(localFile, remoteWriter)
			res, err := http.Get(options.Attachment.URL)
			if err != nil {
				return cmdErrorResp(err)
			}
			go io.Copy(splitter, res.Body)
			msg, err := client.SendMessageComplex(discord.ChannelID(opts.CacheChannel), api.SendMessageData{
				Files: []sendpart.File{
					remoteFile,
				},
			})
			localFile.Close()
			if err != nil {
				return cmdErrorResp(err)
			}
			rows, err := db.Exec("INSERT INTO discord_clips."+sqlTable+" ( message, name ) VALUES ( ?, ? )", uint64(msg.ID), truncatedFileName)
			if err != nil {
				return cmdErrorResp(err)
			}
			id, err := rows.LastInsertId()
			if err != nil {
				return cmdErrorResp(err)
			}
			os.Rename(localFile.Name(), dirs.Data+"clips/"+name+"_"+strconv.FormatInt(id, 36))
			return &api.InteractionResponseData{
				Embeds: &[]discord.Embed{
					{
						Title: "Added " + truncatedFileName,
						Fields: []discord.EmbedField{
							{
								Name:  "ID",
								Value: fmt.Sprint(id),
							},
						},
					},
				},
			}
		})
	})

	client.AddInteractionHandler(r)

	client.Open(client.Context())
	botGoroutineGroup.Done()
}
