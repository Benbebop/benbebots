package main

import (
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"runtime"
	"sync"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-co-op/gocron/v2"
	"github.com/go-sql-driver/mysql"
	"github.com/syndtr/goleveldb/leveldb"
	"gopkg.in/ini.v1"
)

func cmdErrorResp(inErr error) *api.InteractionResponseData {
	id := lgr.Error(inErr)

	var stk string
	for i := 1; i < 6; i++ {
		pc, file, line, ok := runtime.Caller(i)
		stk += "\n"
		if !ok {
			stk += "..."
			break
		}
		stk += fmt.Sprintf("%s:%d 0x%x", file, line, pc)
	}

	return &api.InteractionResponseData{
		Flags: discord.EphemeralMessage,
		Embeds: &[]discord.Embed{
			{
				Author: &discord.EmbedAuthor{
					Name: "There was an error!",
				},
				URL:         "https://github.com/Benbebop/benbebots/issues/new?body=my%20error%20id%3A%20" + id,
				Title:       id,
				Description: inErr.Error(),
				Footer: &discord.EmbedFooter{
					Text: stk,
				},
			},
		},
	}
}

// startup //

var crn gocron.Scheduler
var lgr Logger
var cfg *ini.File
var db *sql.DB
var ldb *leveldb.DB
var hrt Heartbeater
var tokens = map[string]netrc.Machine{}
var dirs struct {
	Data string
	Temp string
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

var botGoroutineGroup sync.WaitGroup

func main() {
	// initialise data directories
	dir, err := os.UserCacheDir()
	if err != nil {
		return
	}
	dirs.Data = dir + "/benbebots/"
	if _, err := os.Stat(dirs.Data); errors.Is(err, os.ErrNotExist) {
		os.Mkdir(dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return
	}

	dirs.Temp = os.TempDir() + "/benbebots/"
	if _, err := os.Stat(dirs.Temp); errors.Is(err, os.ErrNotExist) {
		err := os.MkdirAll(dirs.Temp, 0777)
		if err != nil {
			log.Println(err)
		}
	} else if err != nil {
		return
	}

	// parse config
	cfg, err = ini.LoadSources(ini.LoadOptions{
		Loose:                     true,
		Insensitive:               true,
		UnescapeValueDoubleQuotes: true,
		AllowShadows:              true,
	}, "config.ini")
	if err != nil {
		return
	}

	// init heartbeater
	hrt.Filepath = dirs.Temp + "heartbeat"
	k, err := cfg.Section("webhooks").GetKey("status")
	if err != nil {
		return
	}
	hrt.Webhook = k.String()

	// init logger
	lgr.Directory = dirs.Data + "logs/"
	k, err = cfg.Section("webhooks").GetKey("log")
	if err != nil {
		return
	}
	lgr.Webhook = k.String()

	// init cron
	crn, err = gocron.NewScheduler()
	if err != nil {
		return
	}

	// parse tokens
	mach, _, err := netrc.ParseFile("tokens.netrc")
	if err != nil {
		return
	}

	for _, e := range mach {
		tokens[e.Name] = *e
	}

	// initialize leveldb
	ldb, err = leveldb.OpenFile(dirs.Data+"leveldb", nil)
	if err != nil {
		return
	}
	defer ldb.Close()

	// read args
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
		botGoroutineGroup.Add(1)
		switch os.Args[2] {
		case "benbebot":
			benbebot()
		case "fnaf":
			fnafBot()
		case "cannedfood":
			cannedFood()
		case "familyguy":
			familyguy()
		case "sheldon":
			familyguy()
		default:
			log.Fatalln("unknown")
		}
		crn.Start()
		select {}
	}

	botGoroutineGroup.Add(1)
	go cannedFood()

	botGoroutineGroup.Add(1)
	go fnafBot()

	botGoroutineGroup.Add(1)
	go familyguy()

	botGoroutineGroup.Add(1)
	go benbebot()

	botGoroutineGroup.Wait()

	log.Println("Launched all discord bots")

	crn.Start()

	select {}
}
