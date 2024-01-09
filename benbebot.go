package main

import (
	"log"

	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
)

func benbebot() {
	client := session.New("Bot " + tokens["benbebot"].Password)
	client.AddIntents(gateway.IntentGuildPresences | gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddIntents(gateway.IntentGuildMessages | gateway.IntentDirectMessages)
	client.AddIntents(gateway.IntentGuilds)
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})

	err := client.Connect(client.Context())
	log.Fatalln("client closed: ", err)
}
