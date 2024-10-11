package main

import (
	"encoding/binary"
	"fmt"
	"io/fs"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"syscall"

	"benbebop.net/benbebots/internal/components"
	"benbebop.net/benbebots/internal/heartbeat"
	"benbebop.net/benbebots/internal/logger"
	"benbebop.net/benbebots/internal/platform"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-co-op/gocron/v2"
	"github.com/pelletier/go-toml/v2"
	"github.com/syndtr/goleveldb/leveldb"
)

func AnnounceReady(ready *gateway.ReadyEvent) {
	logs.Info("%s is ready", ready.User.Username)
}

type Benbebots struct{}

var (
	cron        gocron.Scheduler
	logs        *logger.DiscordLogger
	lvldb       *leveldb.DB
	heartbeater heartbeat.Heartbeater
	tokens      map[string]netrc.Machine
	httpc       *http.ServeMux
)

var config struct {
	LogHook    string                `toml:"log_hook"`
	StatusHook string                `toml:"status_hook"`
	Components components.Components `toml:"components"`
	Dirs       struct {
		Cache string `toml:"cache"`
		Temp  string `toml:"temp"`
	} `toml:"directories"`
	Servers struct {
		Benbebots discord.GuildID `toml:"benbebots"`
		BreadBag  discord.GuildID `toml:"bread_bag"`
	} `toml:"servers"`
	Bot struct {
		Fnaf       FnafConfig       `toml:"fnaf"`
		CannedFood CannedFoodConfig `toml:"canned_food"`
		FamilyGuy  FamilyGuyConfig  `toml:"family_guy"`
		Benbebots  BenbebotConfig   `toml:"benbebot"`
		DonCheadle DonCheadleConfig `toml:"don_cheadle"`
	} `toml:"bot"`
}

func main() {
	var err error

	{ // config
		f, err := os.Open("config.toml")
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
		err = toml.NewDecoder(f).Decode(&config)
		f.Close()
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	}

	{ // directories
		if config.Dirs.Cache == "" {
			dir, err := platform.GetDataDir(fs.FileMode(0777))
			if err != nil {
				fmt.Println(err)
				os.Exit(1)
			}
			config.Dirs.Cache = dir
		}

		if config.Dirs.Temp == "" {
			dir, err := platform.GetTempDir(fs.FileMode(0777))
			if err != nil {
				fmt.Println(err)
				os.Exit(1)
			}
			config.Dirs.Temp = dir
		}
	}

	{ // logger
		logs, err = logger.NewDiscordLogger(2, filepath.Join(config.Dirs.Cache, "logs"), config.LogHook)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
		logs.PrintLogLevel = 0
	}

	{ // heartbeater
		heartbeater.Filepath = config.Dirs.Temp + "heartbeat"
		heartbeater.Webhook = config.StatusHook
	}

	{ // cron
		cron, err = gocron.NewScheduler(gocron.WithLogger(&logger.SLogCompat{
			DL: logs,
		}))
		if err != nil {
			logs.Fatal("%s", err)
		}
	}

	{ // tokens
		tokens = map[string]netrc.Machine{}
		mach, _, err := netrc.ParseFile("tokens.netrc")
		if err != nil {
			logs.Fatal("%s", err)
		}

		for _, e := range mach {
			tokens[e.Name] = *e
		}
	}

	{ // leveldb
		lvldb, err = leveldb.OpenFile(filepath.Join(config.Dirs.Cache, "leveldb"), nil)
		if err != nil {
			logs.Fatal("%s", err)
		}

		defer lvldb.Close()
	}

	// read args
	argLen := len(os.Args)
	if argLen > 1 {
		switch os.Args[1] {
		case "update-commands":
			err := updateCommands(argLen > 2 && os.Args[2] == "reset")
			if err != nil {
				logs.Fatal("%s", err)
			}
			return
		case "dump-leveldb":
			toParse := argLen > 2 && os.Args[2] == "parse"
			iter := lvldb.NewIterator(nil, nil)
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
			err := resetStats()
			if err != nil {
				logs.Fatal("%s", err)
			}
			return
		}
	}

	/*{ // http socket
		httpc = http.NewServeMux()

		httpc.HandleFunc("/discord/test/echo", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			io.Copy(w, r.Body)
		})

		client := &http.Server{
			Handler:  httpc,
			ErrorLog: log.New(log.Writer(), "[ERR] ", 0),
		}
		defer client.Shutdown(context.Background())

		l, err := net.Listen("unix", filepath.Join(config.Dirs.Temp, "http.sock"))
		if err != nil {
			logs.Fatal("%s", err)
		}
		go client.Serve(l)
	}*/

	bots := reflect.ValueOf(&Benbebots{})
	var clients struct {
		sync.Mutex
		sessions []*session.Session
	}

	var waitGroup sync.WaitGroup
	values := []reflect.Value{}
	if argLen > 2 && os.Args[1] == "test" {
		bot := bots.MethodByName(strings.ToUpper(os.Args[2]))
		if !bot.IsValid() || bot.IsZero() {
			fmt.Printf("bot %s does not exist\n", os.Args[2])
			return
		}
		waitGroup.Add(1)
		go func() {
			client := bot.Call(values)[0].Interface().(*session.Session)
			waitGroup.Done()
			if client == nil {
				return
			}

			clients.Lock()
			clients.sessions = []*session.Session{client}
			clients.Unlock()
		}()
	} else {
		clients.sessions = make([]*session.Session, 0, bots.NumMethod())
		for i := 0; i < bots.NumMethod(); i++ {
			bot := bots.Method(i)
			waitGroup.Add(1)
			go func() {
				client := bot.Call(values)[0].Interface().(*session.Session)
				waitGroup.Done()
				if client == nil {
					return
				}

				clients.Lock()
				clients.sessions = append(clients.sessions, client)
				clients.Unlock()
			}()
		}
	}
	waitGroup.Wait()

	cron.Start()

	exit := make(chan os.Signal, 1)
	signal.Notify(exit, syscall.SIGTERM, syscall.SIGINT)

	<-exit

	clients.Lock()
	for _, session := range clients.sessions {
		logs.Assert(session.Close())
	}
	logs.Info("successfully terminated discord clients")
}
