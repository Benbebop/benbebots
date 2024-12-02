package benbebots

import (
	"errors"
	"io"
	"math/rand/v2"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/scheduler"
	"benbebop.net/benbebots/internal/wordfile"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

type DonCheadleConfig struct {
	Font     string            `toml:"font_file"`
	Source   string            `toml:"src"`
	SendTime time.Duration     `toml:"send_time"`
	Channel  discord.ChannelID `toml:"channel"`
}

func (Benbebots) DONCHEADLE() *api.Client {
	if !config.Components.IsEnabled("don_cheadle") {
		log.Info("don cheadle component has been disabled")
		return nil
	}
	wordArchive := filepath.Join(config.Dirs.Cache, "words.dat")
	if _, err := os.Stat(wordArchive); errors.Is(err, os.ErrNotExist) {
		log.Info("word archive does not exist, generating")
		CommandLine{}.UPDATE_WORDS([]string{})
	}
	client := api.NewClient("Bot " + tokens["doncheadle"].Password)

	var textArgs = "drawtext=fontcolor=white:borderw=3:fontsize=62:fontfile='" + config.Bot.DonCheadle.Font + "':x=(w-text_w)/2"

	go func() {
		var release io.Closer
		for {
			if release != nil {
				release.Close()
				release = nil
			}
			wait := scheduler.TimeToDaily(config.Bot.DonCheadle.SendTime)
			log.Info("sending next don cheadle wotd in %fh", wait.Hours())
			time.Sleep(wait)

			wr, err := wordfile.NewWordReader(wordArchive)
			if err != nil {
				log.ErrorQuick(err)
				continue
			}
			wordb, err := wr.Get(rand.IntN(wr.Length()))
			if err != nil {
				log.ErrorQuick(err)
				continue
			}
			word := string(wordb)

			c := exec.Command(config.Programs.FFMpeg,
				"-i", config.Bot.DonCheadle.Source,
				"-vf", "[in]"+textArgs+":y=14:text='DON CHEADLE',"+
					textArgs+":y=94:text='WORD OF THE DAY',"+
					textArgs+":y=(h)-76:text='"+strings.ToUpper(word)+"'"+"[out]",
				"-f", "mjpeg",
				"-",
			)

			out, err := c.StdoutPipe()
			if err != nil {
				log.ErrorQuick(err)
				continue
			}

			err = c.Start()
			if err != nil {
				log.ErrorQuick(err)
				continue
			}

			_, err = client.SendMessageComplex(config.Bot.DonCheadle.Channel, api.SendMessageData{
				Files: []sendpart.File{
					{
						Name:   word + ".jpg",
						Reader: out,
					},
				},
			})
			if err != nil {
				log.ErrorQuick(err)
				continue
			}

			err = c.Wait()
			if err != nil {
				log.ErrorQuick(err)
				continue
			}
		}
	}()

	return client
}
