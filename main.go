package main

import (
	"database/sql"
	"log"
	"os"

	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-sql-driver/mysql"
	"gopkg.in/ini.v1"
)

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

	sqlToken, ok := tokens["sql"]
	if !ok {
		log.Println("WARNING: Missing sql token")
	}

	if len(os.Args) > 1 {
		if os.Args[1] == "command-update" {
			commandUpdate()
		} else if os.Args[1] == "sql-update" {
			if len(os.Args) > 2 {
				err = connectDatabase("root", os.Args[2])
			} else {
				err = connectDatabase(sqlToken.Login, sqlToken.Password)
			}
			if err != nil {
				log.Fatalln(err)
			}

			sqlUpdate()
		}
	} else {
		err = connectDatabase(sqlToken.Login, sqlToken.Password)
		if err != nil {
			log.Fatalln(err)
		}

		go benbebot()
		go familyguy()

		go gnerb()
		go cannedfood()
	}
}
