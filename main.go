package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"

	"benbebop.net/benbebots/internal/heartbeat"
	"benbebop.net/benbebots/internal/logger"
	"github.com/diamondburned/arikawa/v3/session"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-co-op/gocron/v2"
	"github.com/syndtr/goleveldb/leveldb"
	"gopkg.in/ini.v1"
)

// startup //

type Benbebots struct {
	Cron        gocron.Scheduler
	Logger      *logger.DiscordLogger
	Config      *ini.File
	Components  Components
	LevelDB     *leveldb.DB
	Heartbeater heartbeat.Heartbeater
	Tokens      map[string]netrc.Machine
	Dirs        struct {
		Data string
		Temp string
	}
	clients        []*session.Session
	clientsMutex   sync.Mutex
	CoroutineGroup sync.WaitGroup
}

func (b *Benbebots) GetDirs() error {
	sec := b.Config.Section("directories")

	dir, err := os.UserCacheDir()
	if err != nil {
		return err
	}
	b.Dirs.Data = sec.Key("cache").MustString(dir + "/benbebots/")
	if _, err := os.Stat(b.Dirs.Data); errors.Is(err, os.ErrNotExist) {
		os.Mkdir(b.Dirs.Data, fs.FileMode(0777))
	} else if err != nil {
		return err
	}

	b.Dirs.Temp = sec.Key("temp").MustString(os.TempDir() + "/benbebots/")
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
	k, err := b.Config.Section("webhooks").GetKey("log")
	if err != nil {
		return err
	}
	b.Logger, err = logger.NewDiscordLogger(1, filepath.Join(b.Dirs.Data, "logs"), k.String())
	return err
}

type LoggerCron interface {
}

func (b *Benbebots) InitCron() error {
	var err error
	b.Cron, err = gocron.NewScheduler(gocron.WithLogger(&logger.SLogCompat{
		DL: b.Logger,
	}))
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

func (b *Benbebots) StartHTTP() error {

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
	err := benbebots.ParseConfig()
	if err != nil {
		log.Println(err)
	}
	err = benbebots.GetDirs()
	if err != nil {
		log.Println(err)
	}
	err = benbebots.InitLogger()
	if err != nil {
		log.Println(err)
	}
	benbebots.Logger.Assert(benbebots.Components.Init(benbebots.Config.Section("components")))
	benbebots.Logger.Assert(benbebots.InitHeartbeater())
	benbebots.Logger.Assert(benbebots.InitCron())
	benbebots.Logger.Assert(benbebots.ParseTokens())
	benbebots.Logger.Assert(benbebots.OpenLevelDB())
	defer benbebots.LevelDB.Close()

	// read args
	argLen := len(os.Args)
	if argLen > 1 {
		switch os.Args[1] {
		case "update-commands":
			err := benbebots.UpdateCommands(argLen > 2 && os.Args[2] == "reset")
			if err != nil {
				log.Fatalln(err)
			}
			return
		case "dump-leveldb":
			toParse := argLen > 2 && os.Args[2] == "parse"
			iter := benbebots.LevelDB.NewIterator(nil, nil)
			for iter.Next() {
				k, v := iter.Key(), iter.Value()
				os.Stdout.Write(k)
				os.Stdout.WriteString(": ")
				if toParse {
					if num, read := binary.Varint(v); read > 0 {
						fmt.Print(num)
					}
				} else {
					for _, c := range v {
						if uint8(c) < 32 || uint8(c) > 126 {
							fmt.Printf("\\%03d", c)
						} else if c == '\\' {
							fmt.Print("\\\\")
						} else {
							os.Stdout.Write([]byte{c})
						}
					}
				}
				os.Stdout.WriteString("\n")
			}
			iter.Release()
			return
		case "reset-stats":
			err := benbebots.ResetStats()
			if err != nil {
				log.Fatalln(err)
			}
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
	} else {
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
	}

	benbebots.Cron.Start()

	exit := make(chan os.Signal, 1)
	signal.Notify(exit, syscall.SIGTERM, syscall.SIGINT)

	<-exit

	benbebots.CloseClients()
	log.Println("successfully terminated discord clients")
	os.Exit(0)
}
