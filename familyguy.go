package main

import (
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
)

func familyguy() {
	client := session.New("Bot " + tokens["familyGuy"].Password)
	client.AddIntents(gateway.IntentGuildMembers) // privileged
	client.AddHandler(createReadyAnnouncer(*client))

	startSession(*client)
}

func familyguyTwo() {
	client := session.New("Bot " + tokens["sheldon"].Password)
	client.AddIntents(gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddHandler(createReadyAnnouncer(*client))

	startSession(*client)
}
