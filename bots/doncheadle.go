package benbebots

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/scheduler"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

const RANDOM_WORD_URL = "https://random-word-api.herokuapp.com/word"

type DonCheadleConfig struct {
	Font     string            `toml:"font_file"`
	Source   string            `toml:"src"`
	SendTime time.Duration     `toml:"send_time"`
	Channel  discord.ChannelID `toml:"channel"`
}

var wordSteriliser, _ = regexp.Compile("[^a-zA-Z]")

func (Benbebots) DONCHEADLE() *api.Client {
	if !config.Components.IsEnabled("don_cheadle") {
		log.Info("don cheadle component has been disabled")
		return nil
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

			resp, err := http.Get(RANDOM_WORD_URL)
			if err != nil {
				log.ErrorQuick(err)
				continue
			}
			release = resp.Body

			var raw bytes.Buffer
			var words []string
			err = json.NewDecoder(io.TeeReader(resp.Body, &raw)).Decode(&words)
			resp.Body = io.NopCloser(bytes.NewReader(raw.Bytes()))
			if err != nil {
				log.DumpResponse(resp, true, 2, "%s", err)
				continue
			}
			if len(words) <= 0 {
				log.DumpResponse(resp, true, 2, "no words returned")
				continue
			}
			word := wordSteriliser.ReplaceAllString(words[0], "")

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
						Name:   words[0] + ".jpg",
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
