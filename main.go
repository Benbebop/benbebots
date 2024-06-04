package main

import (
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"runtime"
	"sync"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/session"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-co-op/gocron/v2"
	"github.com/syndtr/goleveldb/leveldb"
	"gopkg.in/ini.v1"
)

// startup //

type Benbebots struct {
	Cron        gocron.Scheduler
	Logger      Logger
	Config      *ini.File
	LevelDB     *leveldb.DB
	Heartbeater Heartbeater
	Tokens      map[string]netrc.Machine
	Dirs        struct {
		Data string
		Temp string
	}
	clients        []*session.Session
	clientsMutex   sync.Mutex
	CoroutineGroup sync.WaitGroup
}

func (b *Benbebots) CommandError(inErr error) *api.InteractionResponseData {
	b.Logger.Error(inErr.Error())

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
				URL:         "https://github.com/Benbebop/benbebots/issues/new?body=my%20error%20id%3A%20",
				Title:       "idk",
				Description: inErr.Error(),
				Footer: &discord.EmbedFooter{
					Text: stk,
				},
			},
		},
	}
}

func (b *Benbebots) GetDirs() error {
	dir, err := os.UserCacheDir()
	if err != nil {
		return err
	}
	b.Dirs.Data = dir + "/benbebots/"
	if _, err := os.Stat(b.Dirs.Data); errors.Is(err, os.ErrNotExist) {
		os.Mkdir(b.Dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return err
	}

	b.Dirs.Temp = os.TempDir() + "/benbebots/"
	if _, err := os.Stat(b.Dirs.Temp); errors.Is(err, os.ErrNotExist) {
		err := os.MkdirAll(b.Dirs.Temp, 0777)
		if err != nil {
			log.Println(err)
		}
	} else if err != nil {
		return err
	}
	return nil
}

func (b *Benbebots) ParseConfig() error {
	var err error
	b.Config, err = ini.LoadSources(ini.LoadOptions{
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

func (b *Benbebots) InitHeartbeater() error {
	b.Heartbeater.Filepath = b.Dirs.Temp + "heartbeat"
	k, err := b.Config.Section("webhooks").GetKey("status")
	if err != nil {
		return err
	}
	b.Heartbeater.Webhook = k.String()
	return nil
}

func (b *Benbebots) InitLogger() error {
	b.Logger.Directory = b.Dirs.Data + "logs/"
	k, err := b.Config.Section("webhooks").GetKey("log")
	if err != nil {
		return err
	}
	b.Logger.Webhook = k.String()
	return nil
}

type LoggerCron interface {
}

func (b *Benbebots) InitCron() error {
	var err error
	b.Cron, err = gocron.NewScheduler(gocron.WithLogger(&b.Logger))
	if err != nil {
		return err
	}
	return nil
}

func (b *Benbebots) ParseTokens() error {
	b.Tokens = map[string]netrc.Machine{}
	mach, _, err := netrc.ParseFile("tokens.netrc")
	if err != nil {
		return err
	}

	for _, e := range mach {
		b.Tokens[e.Name] = *e
	}
	return nil
}

func (b *Benbebots) OpenLevelDB() error {
	var err error
	b.LevelDB, err = leveldb.OpenFile(b.Dirs.Data+"leveldb", nil)
	if err != nil {
		return err
	}
	return nil
}

func (b *Benbebots) AddClient(client *session.Session) {
	b.clientsMutex.Lock()
	b.clients = append(b.clients, client)
	b.clientsMutex.Unlock()
}

func (b *Benbebots) CloseClients() {
	for _, client := range b.clients {
		client.Close()
	}
}

func main() {
	var benbebots = Benbebots{}

	// initialise benbebots
	benbebots.GetDirs()
	benbebots.ParseConfig()
	benbebots.InitHeartbeater()
	benbebots.InitLogger()
	benbebots.InitCron()
	benbebots.ParseTokens()
	benbebots.OpenLevelDB()
	defer benbebots.LevelDB.Close()

	// read args
	argLen := len(os.Args)
	if argLen > 1 {
		switch os.Args[1] {
		case "update-commands":
			benbebots.UpdateCommands(argLen > 2 && os.Args[2] == "reset")
			return
		case "dump-leveldb":
			iter := benbebots.LevelDB.NewIterator(nil, nil)
			for iter.Next() {
				k, v := iter.Key(), iter.Value()
				os.Stdout.Write(k)
				os.Stdout.WriteString(": ")
				os.Stdout.Write(v)
				os.Stdout.WriteString("\n")
			}
			iter.Release()
			return
		}
	}

	defer benbebots.CloseClients()

	if argLen > 2 && os.Args[1] == "test" {
		benbebots.CoroutineGroup.Add(1)
		switch os.Args[2] {
		case "benbebot":
			benbebots.RunBenbebot()
		case "fnaf":
			benbebots.RunFnafBot()
		case "cannedfood":
			benbebots.RunCannedFood()
		case "familyguy":
			benbebots.RunFamilyGuy()
		case "sheldon":
			log.Fatalln("unimplemented")
		default:
			log.Fatalln("unknown")
		}
		benbebots.Cron.Start()
		select {}
	}

	benbebots.CoroutineGroup.Add(1)
	go benbebots.RunCannedFood()

	benbebots.CoroutineGroup.Add(1)
	go benbebots.RunFnafBot()

	benbebots.CoroutineGroup.Add(1)
	go benbebots.RunFamilyGuy()

	benbebots.CoroutineGroup.Add(1)
	go benbebots.RunBenbebot()

	benbebots.CoroutineGroup.Wait()

	log.Println("Launched all discord bots")

	benbebots.Cron.Start()

	select {}
}
