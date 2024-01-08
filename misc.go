package main

import (
	"embed"
	"io"
	"log"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/utils/sendpart"
)

func getWaitTime(now time.Time, gnerbtime uint, dayAdd int) (time.Duration, time.Time) {
	year, month, day := now.Date()
	postTime := time.Date(year, month, day+dayAdd, 0, 0, 0, 0, now.Location()).Add(time.Duration(gnerbtime * uint(time.Millisecond)))
	waitTime := postTime.Sub(now)
	if waitTime < 0 {
		return getWaitTime(now, gnerbtime, dayAdd+1)
	}
	return waitTime, postTime
}

//go:embed resource/gnerb.jpg
var gnerbFS embed.FS
var gnerbReader io.Reader
var gnerbTimer *time.Timer
var err error

func fnafBot() { // gnerb
	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	gnerbtime, _ := getCfg("bot.fnaf", "gnerbtime").Uint()
	desination, _ := getCfg("bot.fnaf", "destination").Uint64()

	defer func() {
		go func() {
			channel := discord.ChannelID(desination)
			sleep, postTime := getWaitTime(time.Now().UTC(), gnerbtime, 0)
			var lostTime time.Duration
			log.Printf("Sending next gnerb in %dm.", sleep/time.Minute)
			for {
				gnerbTimer = time.NewTimer(sleep - lostTime)
				<-gnerbTimer.C

				gnerbReader, err = gnerbFS.Open("resource/gnerb.jpg")
				if err != nil {
					log.Fatalln(err)
				}
				m, err := client.SendMessageComplex(channel, api.SendMessageData{
					Files: []sendpart.File{{
						Name:   "gnerb.jpg",
						Reader: gnerbReader,
					}},
				})
				if err != nil {
					log.Println(err)
				}

				messageRecieved := m.ID.Time().UTC()
				lostTime = messageRecieved.Sub(postTime)
				db.Exec("REPLACE INTO gnerb.send_lost_time (lost) VALUES ( ? )", lostTime.Microseconds())
				log.Printf("Sent gnerb, lost %dms.", lostTime/time.Millisecond)

				sleep, postTime = getWaitTime(time.Now().UTC(), gnerbtime, 1)
			}
		}()
	}()

	me, err := client.Me()
	if err == nil {
		log.Println(me.Tag() + " is ready")
		return
	}
}
