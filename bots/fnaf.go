package benbebots

import (
	"bytes"
	"os"
	"path/filepath"
	"time"

	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/scheduler"
	"benbebop.net/benbebots/internal/stats"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

type FnafConfig struct {
	Source      string            `toml:"source"`
	Time        time.Duration     `toml:"pou_time"`
	Destination discord.ChannelID `toml:"destination"`
	StatChannel discord.ChannelID `toml:"stat_channel"`
}

func (Benbebots) FNAF() *api.Client { // gnerb
	if !config.Components.IsEnabled("fnaf") {
		log.Info("fnaf component has been disabled")
		return nil
	}

	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	fnafStat := stats.Stat{
		Name:      "Gnerbs",
		Value:     0,
		Client:    client,
		ChannelID: config.Bot.Fnaf.StatChannel,
		LevelDB:   lvldb,
		Delay:     time.Second * 5,
	}
	fnafStat.Initialise()

	ext := filepath.Ext(config.Bot.Fnaf.Source)
	if ext != ".png" && ext != ".jpg" && ext != ".webp" {
		log.Fatal("invalid gnerb format")
	}

	content, err := os.ReadFile(config.Bot.Fnaf.Source)
	if err != nil {
		log.Fatal("%s", err)
	}

	go func() {
		for {
			wait := scheduler.TimeToDaily(config.Bot.Fnaf.Time)
			log.Info("sending next pou image in %fh", wait.Hours())
			time.Sleep(wait)

			client.SendMessageComplex(config.Bot.Fnaf.Destination, api.SendMessageData{
				Files: []sendpart.File{
					{
						Name:   "image" + ext,
						Reader: bytes.NewReader(content),
					},
				},
			})
		}
	}()

	return client
}
