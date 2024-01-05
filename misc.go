package main

import (
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
)

func fnafBot() {
	client := session.New("Bot " + tokens["fnaf"].Password)
	client.AddIntents(gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddHandler(createReadyAnnouncer(*client))

	startSession(*client)
}
