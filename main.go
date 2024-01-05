package main

import (
	"context"
	"database/sql"
	"log"
	"os"

	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-sql-driver/mysql"
	"gopkg.in/ini.v1"
)

// bot utility commands //

func createReadyAnnouncer(client session.Session) func(*gateway.ReadyEvent) {
	return func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	}
}

func startSession(client session.Session) {
	if err := client.Open(context.Background()); err != nil {
		log.Fatalln("Failed to connect:", err)
	}

	_, err := client.Me()
	if err != nil {
		log.Fatalln("Failed to get myself:", err)
	}
}

// startup //

var cfg *ini.File
var db *sql.DB
var tokens = map[string]netrc.Machine{}

func parseTokens() error {
	mach, _, err := netrc.ParseFile("tokens.netrc")
	if err != nil {
		return err
	}

	for _, e := range mach {
		tokens[e.Name] = *e
	}
	return nil
}

func parseConfig() error {
	file, err := ini.LooseLoad("config.ini")
	if err != nil {
		return err
	}

	cfg = file
	return nil
}

func connectDatabase(user string, passwd string) error {
	sqlCfg := mysql.Config{
		User:                 user,
		Passwd:               passwd,
		AllowNativePasswords: true,
	}
	database, err := sql.Open("mysql", sqlCfg.FormatDSN())
	if err != nil {
		return err
	}
	err = database.Ping()
	if err != nil {
		return err
	}

	db = database
	return nil
}

func main() {
	err := parseTokens()
	if err != nil {
		log.Fatalln(err)
	}

	err = parseConfig()
	if err != nil {
		log.Fatalln(err)
	}

	if len(os.Args) > 1 {
		if os.Args[1] == "command-update" {
			commandUpdate()
		} else if os.Args[1] == "sql-update" {
			if len(os.Args) > 2 {
				err = connectDatabase("root", os.Args[2])
			} else {
				err = connectDatabase("benbebot", tokens["sql"].Password)
			}
			if err != nil {
				log.Fatalln(err)
			}

			sqlUpdate()
		}
	} else {
		err = connectDatabase("benbebot", tokens["sql"].Password)
		if err != nil {
			log.Fatalln(err)
		}
		log.Println("Connected to sql database as", sqlGetUsername())
		defer db.Close()

		go fnafBot()

		go familyguy()
		go familyguyTwo()

		go benbebot()

		select {}
	}
}
