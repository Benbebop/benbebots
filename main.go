package main

import (
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-sql-driver/mysql"
	"gopkg.in/ini.v1"
)

func writeErrorLog(inErr error) (string, error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	id := strings.ToUpper(strconv.FormatInt(time.Now().UnixMicro(), 36))
	os.Mkdir(dir+"/benbebots/errors/", fs.FileMode(0777))
	file, err := os.OpenFile(fmt.Sprintf("%s/benbebots/errors/%s.log", dir, id), os.O_CREATE|os.O_WRONLY, 0777)
	if err != nil {
		return "", err
	}
	_, err = file.Write([]byte(inErr.Error() + "\n\n"))
	if err != nil {
		return "", err
	}
	b := make([]byte, 2048)
	n := runtime.Stack(b, false)
	_, err = file.Write(b[:n])
	if err != nil {
		return "", err
	}
	file.Close()
	log.Println(id, inErr)
	return id, nil
}

func cmdErrorResp(inErr error) *api.InteractionResponseData {
	id, err := writeErrorLog(inErr)
	if err != nil {
		log.Println(err)
		id = "no id"
	}

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

var cfg *ini.File
var db *sql.DB
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
	// parse tokens
	mach, _, err := netrc.ParseFile("tokens.netrc")
	if err != nil {
		return
	}

	for _, e := range mach {
		tokens[e.Name] = *e
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
	if _, err := os.Stat(dirs.Data); errors.Is(err, os.ErrNotExist) {
		os.MkdirAll(dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return
	}

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
			familyguy("familyGuy")
		case "sheldon":
			familyguy("sheldon")
		default:
			log.Fatalln("unknown")
		}
		select {}
	}

	botGoroutineGroup.Add(1)
	go cannedFood()

	botGoroutineGroup.Add(1)
	go fnafBot()

	//disabled until i can fix attachment command options
	//botGoroutineGroup.Add(2)
	//go familyguy("familyGuy")
	//go familyguy("sheldon")

	botGoroutineGroup.Add(1)
	go benbebot()

	botGoroutineGroup.Wait()

	log.Println("Launched all discord bots")

	select {}
}
