package main

import (
	"database/sql"
	"errors"
	"io/fs"
	"log"
	"os"

	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-sql-driver/mysql"
	"gopkg.in/ini.v1"
)

// startup //

var cfg *ini.File
var db *sql.DB
var tokens = map[string]netrc.Machine{}
var dirs struct {
	Data string
	Temp string
}

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
	var err error
	cfg, err = ini.LoadSources(ini.LoadOptions{
		Loose:                     true,
		Insensitive:               true,
		UnescapeValueDoubleQuotes: true,
		AllowShadows:              true,
	}, "config.ini")
	if err != nil {
		return err
	}

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

func getCfg(section string, name string) *ini.Key {
	val, err := cfg.Section(section).GetKey(name)
	if err != nil {
		log.Fatalln(err)
	}
	return val
}

func getDirs() error {
	dir, err := os.UserCacheDir()
	if err != nil {
		return err
	}
	dirs.Data = dir + "/benbebots/"
	if _, err := os.Stat(dirs.Data); errors.Is(err, os.ErrNotExist) {
		return os.Mkdir(dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return err
	}

	dirs.Temp = os.TempDir() + "/benbebots/"
	if _, err := os.Stat(dirs.Data); errors.Is(err, os.ErrNotExist) {
		return os.MkdirAll(dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return err
	}
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

	err = getDirs()
	if err != nil {
		log.Fatalln(err)
	}

	argLen := len(os.Args)
	if argLen > 1 {
		if os.Args[1] == "update-commands" {
			if argLen > 2 && os.Args[2] == "reset" {
				commandUpdate(true)
			} else {
				commandUpdate(false)
			}
			return
		} else if os.Args[1] == "update-sql" {
			if argLen > 2 {
				err = connectDatabase("root", os.Args[2])
			} else {
				err = connectDatabase("benbebot", tokens["sql"].Password)
			}
			if err != nil {
				log.Fatalln(err)
			}

			sqlUpdate()
			return
		}
	}
	err = connectDatabase("benbebot", tokens["sql"].Password)
	if err != nil {
		log.Fatalln(err)
	}
	log.Println("Connected to sql database as", sqlGetUsername())
	defer db.Close()

	if argLen > 2 && os.Args[1] == "test" {
		switch os.Args[2] {
		case "benbebot":
			benbebot()
		case "fnaf":
			fnafBot()
		case "cannedfood":
			cannedFood()
		case "familyguy":
			familyguy("familyGuy")
		case "sheldon":
			familyguy("sheldon")
		default:
			log.Fatalln("unknown")
		}
		select {}
	}

	go cannedFood()

	go fnafBot()

	go familyguy("familyGuy")
	go familyguy("sheldon")

	go benbebot()

	select {}
}
