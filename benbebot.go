package main

import (
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	_ "github.com/go-sql-driver/mysql"
)

func benbebot(token string) {
	client := session.New("Bot" + token)

	if db != nil {
		client.AddHandler(func(message *gateway.MessageCreateEvent) {

		})
	}

}
