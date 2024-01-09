package main

import (
	"log"

	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/state"
)

func familyguy(name string) {
	client := state.New("Bot " + tokens[name].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})

	err := client.Connect(client.Context())
	log.Fatalln("client closed: ", err)
}
