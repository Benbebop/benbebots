package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/session"
)

const DON_CHEADLE_MIN_TIME = time.Minute * 5
const RANDOM_WORD_URL = "https://random-word-api.herokuapp.com/word"

type DonCheadleConfig struct {
	SendTime time.Duration `toml:"send_time"`
	Webhook  string        `toml:"webhook"`
}

func (Benbebots) DONCHEADLE() *session.Session {
	if !config.Components.IsEnabled("doncheatle") {
		logs.Info("don cheadle component has been disabled")
		return nil
	}
	client, err := webhook.NewFromURL(config.Bot.DonCheadle.Webhook)
	if err != nil {
		logs.Fatal("%s", err)
	}

	go func() {
		var release io.Closer
		for {
			if release != nil {
				release.Close()
				release = nil
			}
			wait := time.Until(time.Now().Add(-config.Bot.DonCheadle.SendTime).Round(time.Hour * 24).Add(config.Bot.DonCheadle.SendTime))
			if wait <= DON_CHEADLE_MIN_TIME {
				time.Sleep(DON_CHEADLE_MIN_TIME)
				continue
			}
			logs.Info("sending next don cheadle wotd in %fh", wait.Hours())
			time.Sleep(wait)

			resp, err := http.Get(RANDOM_WORD_URL)
			if err != nil {
				logs.ErrorQuick(err)
				continue
			}
			release = resp.Body

			var raw bytes.Buffer
			var words []string
			s, _ := logs.Assert(json.NewDecoder(io.TeeReader(resp.Body, &raw)).Decode(&words))
			if s {
				continue
			} else if len(words) <= 0 {
				resp.Body = io.NopCloser(bytes.NewReader(raw.Bytes()))
				logs.DumpResponse(resp, true, 2, "no words returned")
				continue
			}

			logs.Assert(client.Execute(webhook.ExecuteData{
				Content: fmt.Sprintf("Don Cheadle word of the day: %s", words[0]),
			}))
		}
	}()
	return nil
}
