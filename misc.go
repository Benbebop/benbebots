package main

import (
	"log"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
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

func fnafBot() { // gnerb
	client := api.NewClient("Bot " + tokens["fnaf"].Password)

	gnerbtime, _ := getCfg("bot.fnaf", "gnerbtime").Uint()
	desination, _ := getCfg("bot.fnaf", "destination").Uint64()

	defer func() {
		go func() {
			channel := discord.ChannelID(desination)
			sleep, postTime := getWaitTime(time.Now().UTC(), gnerbtime, 0)
			log.Printf("Sending next gnerb in %dm.", sleep/time.Minute)
			for {
				time.Sleep(sleep)

				m, err := client.SendMessageComplex(channel, api.SendMessageData{
					Content: "test",
				})
				if err != nil {
					log.Println(err)
				}
				messageRecieved := m.ID.Time().UTC()
				log.Printf("Sent gnerb, lost %dms (%s, %s).", messageRecieved.Sub(postTime)/time.Millisecond, postTime.Local().Format(time.Layout), messageRecieved.Local().Format(time.Layout))

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
