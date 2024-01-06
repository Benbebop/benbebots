package main

import (
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
)

func familyguy(name string) {
	client := session.New("Bot " + tokens[name].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(createReadyAnnouncer(*client))

	startSession(*client)
}
