package main

import (
	"database/sql"
	"log"
	"os"

	netrc "github.com/fhs/go-netrc/netrc"
	"gopkg.in/ini.v1"
)

var cfg *ini.File
var db *sql.DB

func main() {
	if os.Args[1] == "command-update" {

	} else if os.Args[1] == "sql-update" {
		sqlUpdate()
	} else {
		mach, _, err := netrc.ParseFile("tokens.netrc")
		if err != nil {
			log.Fatal(err)
		}

		var tokens [4]netrc.Machine
		for _, e := range mach {
			switch e.Name {
			case "benbebot":
				tokens[0] = *e
			case "familyguy":
				tokens[1] = *e
			case "gnerb":
				tokens[2] = *e
			case "cannedFood":
				tokens[3] = *e
			}
		}

		file, err := ini.LooseLoad("config.ini")
		if err != nil {
			log.Fatal(err)
		}

		cfg = file

		db, err = sql.Open("mysql", "")
		if err != nil {
			log.Fatal(err)
		}
		err = db.Ping()
		if err == nil {
			db = nil
		} else {
			log.Println(err)
			return
		}

		benbebot(tokens[0].Password)
		familyguy(tokens[1].Password)

		gnerb(tokens[2].Password)
		cannedfood()
	}
}
