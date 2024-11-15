package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"reflect"
	"sync"
	"syscall"
	"time"

	"benbebop.net/benbebots/internal/components"
	"benbebop.net/benbebots/internal/generated/version"
	"benbebop.net/benbebots/internal/heartbeat"
	"benbebop.net/benbebots/internal/log"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/state"
	"github.com/diamondburned/arikawa/v3/utils/ws"
	netrc "github.com/fhs/go-netrc/netrc"
	"github.com/go-co-op/gocron/v2"
	"github.com/pelletier/go-toml/v2"
	probing "github.com/prometheus-community/pro-bing"
	"github.com/syndtr/goleveldb/leveldb"
)

type Benbebots struct{}

const defaultFileMode fs.FileMode = 0700

var (
	cron        gocron.Scheduler
	lvldb       *leveldb.DB
	heartbeater heartbeat.Heartbeater
	tokens      map[string]netrc.Machine
)

var config struct {
	LogHook    string                `toml:"log_hook"`
	StatusHook string                `toml:"status_hook"`
	LogLevel   int                   `toml:"log_level"`
	Http       bool                  `toml:"http_interactions"`
	Components components.Components `toml:"components"`
	Programs   struct {
		FFMpeg string `toml:"ffmpeg" exe:"ffmpeg"`
	} `toml:"programs"`
	Dirs struct {
		Run   string `toml:"run"`
		Cache string `toml:"cache"`
		Log   string `toml:"log"`
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
		var path string
		if ed, ok := os.LookupEnv("CONFIGURATION_DIRECTORY"); ok {
			path = filepath.Join(ed, "config.toml")
		} else {
			path = "config.toml"
		}
		f, err := os.Open(path)
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
		config.Dirs.Run = func() string {
			if config.Dirs.Run != "" {
				return config.Dirs.Run
			}

			if ed, ok := os.LookupEnv("RUNTIME_DIRECTORY"); ok {
				return ed
			}

			if wd, err := os.Getwd(); err == nil {
				return filepath.Join(wd, "runtime")
			}

			return "."
		}()
		os.MkdirAll(config.Dirs.Run, defaultFileMode)

		config.Dirs.Log = func() string {
			if config.Dirs.Log != "" {
				return config.Dirs.Log
			}

			if ed, ok := os.LookupEnv("LOGS_DIRECTORY"); ok {
				return ed
			}

			if config.Dirs.Cache != "" {
				return filepath.Join(config.Dirs.Cache, "log")
			}

			if cd, err := os.UserCacheDir(); err == nil {
				return filepath.Join(cd, "benbebots/log")
			}

			if wd, err := os.Getwd(); err == nil {
				return filepath.Join(wd, "log")
			}

			return "."
		}()
		os.MkdirAll(config.Dirs.Log, defaultFileMode)

		config.Dirs.Cache = func() string {
			if config.Dirs.Cache != "" {
				return config.Dirs.Cache
			}

			if ed, ok := os.LookupEnv("CACHE_DIRECTORY"); ok {
				return ed
			}

			if cd, err := os.UserCacheDir(); err == nil {
				return filepath.Join(cd, "benbebots")
			}

			if wd, err := os.Getwd(); err == nil {
				return filepath.Join(wd, "cache")
			}

			return "."
		}()
		os.MkdirAll(config.Dirs.Cache, defaultFileMode)

		config.Dirs.Temp = func() string {
			if config.Dirs.Temp != "" {
				return config.Dirs.Temp
			}

			return filepath.Join(os.TempDir(), "benbebots")
		}()
		os.MkdirAll(config.Dirs.Temp, defaultFileMode)
	}

	{ // logger
		log.Directory = config.Dirs.Log
		log.PrintLogLevel = config.LogLevel
		log.FileLogLevel = 2
		log.WebLogLevel = 2
		log.Webhook, err = webhook.NewFromURL(config.LogHook)
		log.OnFatal = func() {
			os.Exit(1)
		}
		if err != nil {
			log.FatalQuick(err)
		}

		log.Assert(log.CatchCrash())

		ws.WSError = func(err error) {
			log.ErrorQuick(err)
		}
		ws.WSDebug = func(v ...interface{}) {
			log.Debug("%s", fmt.Sprint(v...))
		}

		dirs := reflect.ValueOf(config.Dirs)
		for i := 0; i < dirs.NumField(); i++ {
			log.Debug("%s dir: %s", dirs.Type().Field(i).Name, dirs.Field(i).String())
		}
	}

	{ // programs
		programs := reflect.ValueOf(&config.Programs).Elem()

		for i := 0; i < programs.NumField(); i++ {
			program := programs.Field(i)

			if program.Interface().(string) == "" {
				p, err := exec.LookPath(programs.Type().Field(i).Tag.Get("exe"))
				if err != nil {
					log.FatalQuick(err)
				}
				program.SetString(p)
			}
		}
	}

	{ // heartbeater
		heartbeater.Filepath = filepath.Join(config.Dirs.Temp, "heartbeat")
		heartbeater.Webhook = config.StatusHook
	}

	{ // cron
		cron, err = gocron.NewScheduler(gocron.WithLogger(&log.SLogCompat{}))
		if err != nil {
			log.Fatal("%s", err)
		}
	}

	{ // tokens
		tokens = map[string]netrc.Machine{}
		mach, _, err := netrc.ParseFile("tokens.netrc")
		if err != nil {
			log.Fatal("%s", err)
		}

		for _, e := range mach {
			tokens[e.Name] = *e
		}
	}

	{ // leveldb
		lvldb, err = leveldb.OpenFile(filepath.Join(config.Dirs.Cache, "leveldb"), nil)
		if err != nil {
			log.Fatal("%s", err)
		}

		defer lvldb.Close()
	}

	// read args
	argLen := len(os.Args)
	if argLen > 1 {
		switch os.Args[1] {
		case "update-commands":
			updateCommands(true) //argLen > 2 && os.Args[2] == "remove")
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
				log.Fatal("%s", err)
			}
			return
		}
	}

	// connectivity check
	const cc = "%s, skipping connectivity check"
	if !func() bool {
		endpoint, err := url.Parse(api.BaseEndpoint)
		if err != nil {
			log.Warn(cc, err)
			return true
		}

		pinger, err := probing.NewPinger(endpoint.Hostname())
		if err != nil {
			log.Warn(cc, err)
			return true
		}

		pinger.SetPrivileged(true)

		pinger.Timeout = time.Second * 5
		pinger.Count = 1
		err = pinger.Run()
		if err != nil {
			log.Warn(cc, err)
			return true
		}

		stats := pinger.Statistics()
		return stats.PacketsRecv >= 1
	}() {
		log.Error("cant connect to discord")
		return
	}

	var socket net.Listener
	var mux *http.ServeMux
	{ // http
		spath := filepath.Join(config.Dirs.Run, "http.socket")
		os.Remove(spath)
		var err error
		socket, err = net.Listen("unix", spath)
		if err != nil {
			log.FatalQuick(err)
		}

		mux = http.NewServeMux()
		go func() {
			err := http.Serve(socket, mux)
			if err != nil {
				log.Debug("%s", err)
			}
		}()
	}

	bots := reflect.TypeFor[Benbebots]()
	var clients struct {
		sync.Mutex
		sessions []*session.Session
	}

	exit := make(chan os.Signal, 1)

	log.OnFatal = func() {
		exit <- syscall.SIGABRT
		select {}
	}

	go func() {
		var waitGroup sync.WaitGroup
		values := []reflect.Value{
			reflect.ValueOf(Benbebots{}),
		}
		clients.sessions = make([]*session.Session, 0, bots.NumMethod())
		for i := 0; i < bots.NumMethod(); i++ {
			bot := bots.Method(i)
			waitGroup.Add(1)
			go func() {
				rs := bot.Func.Call(values)
				for _, r := range rs {
					r := r.Interface()
					switch r := r.(type) {
					case *session.Session, *state.State:
						s, ok := r.(*session.Session)
						if !ok {
							r := r.(*state.State)
							if r == nil {
								continue
							}
							s = r.Session
						} else if s == nil {
							continue
						}
						/*if config.Http {
							app, err := s.CurrentApplication()
							if err == nil {
								srv, err := webhook.NewInteractionServer(app.VerifyKey, nil)
								if err != nil {
									log.FatalQuick(err)
								}
								prefix := filepath.Join("/interactions/", strings.ToLower(bot.Name))
								mux.Handle(prefix, http.StripPrefix(prefix, srv))
							} else {
								log.Warn("%s", err)
							}
						}*/

						ready := make(chan *gateway.ReadyEvent)

						rm := s.AddHandler(ready)

						go func() {
							ctx := context.Background()
							opts := s.GatewayOpts()

							for {
								if err := s.Open(ctx); err != nil {
									if opts.ErrorIsFatalClose(err) || ctx.Err() != nil {
										log.Fatal("%s", err)
									}
									log.Warn("%s", err)
									continue
								}

								if err := s.Wait(ctx); err != nil {
									if opts.ErrorIsFatalClose(err) {
										log.Fatal("%s", err)
									}
									if ctx.Err() != nil {
										break
									}
									log.Warn("%s", err)
								}
							}
						}()

						ev := <-ready
						rm()
						close(ready)

						log.Info("%s is ready", ev.User.Username)

						clients.Lock()
						clients.sessions = append(clients.sessions, s)
						clients.Unlock()
					case *api.Client:
						if r == nil {
							continue
						}

						u, err := r.Me()
						if err != nil {
							log.Fatal("%s", err)
						}
						log.Info("%s is ready", u.Username)
					case error:
						if r != nil {
							log.Fatal("%s", r)
						}
					}
				}
				waitGroup.Done()
			}()
		}
		waitGroup.Wait()

		if version.Hash != "unknown version" {
			if hash, err := lvldb.Get([]byte("currentVersion"), nil); (err == nil || errors.Is(err, leveldb.ErrNotFound)) && string(hash) != version.Hash {
				if f, _ := log.Assert(lvldb.Put([]byte("currentVersion"), []byte(version.Hash), nil)); !f {
					heartbeater.Output(fmt.Sprintf("running new version `%s`.", version.HashShort))
				}
			}
		}

		cron.Start()
	}()

	signal.Notify(exit, os.Interrupt, syscall.SIGTERM)

	sig := <-exit
	var code int
	switch sig {
	case syscall.SIGABRT:
		code = 1
	default:
		code = 0
		log.Info("interrupt recieved, closing")
	}

	log.Assert(socket.Close())

	clients.Lock()
	var notSuccess bool
	for _, session := range clients.sessions {
		s, _ := log.Assert(session.Close())
		notSuccess = notSuccess || s
	}
	if !notSuccess {
		log.Info("successfully terminated discord clients")
	}
	os.Exit(code)
}
