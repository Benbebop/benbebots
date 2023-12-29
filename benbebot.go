package main

import (
	"database/sql"
	"log"

	"github.com/bwmarrin/discordgo"
	_ "github.com/go-sql-driver/mysql"
)

func benbebot(token string) {
	client, err := discordgo.New("Bot " + token)
	if err != nil {
		log.Fatal(err)
	}

	db, err := sql.Open("mysql", "")
	if err != nil {
		log.Fatal(err)
	}
	err = db.Ping()
	if err != nil {
		log.Println(err)
		return
	}

	// STATISTICS //
	client.AddHandler(func(s *discordgo.Session, m *discordgo.MessageCreate) {

	})
}
