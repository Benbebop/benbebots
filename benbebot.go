package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
	"github.com/diamondburned/arikawa/v3/voice"
	"github.com/diamondburned/arikawa/v3/voice/udp"
	"github.com/diamondburned/arikawa/v3/voice/voicegateway"
	"github.com/diamondburned/oggreader"
	"github.com/go-co-op/gocron/v2"
	"github.com/google/go-querystring/query"
)

type MRadio struct {
	sync.Mutex
	benbebots     *Benbebots
	session       *voice.Session
	tracks        []uint64
	Active        bool
	Channel       discord.ChannelID
	soundcloud    *SoundcloudClient
	FFmpegPath    string `ini:"ffmpeg"`
	YtdlpPath     string `ini:"ytdlp"`
	ffmpeg        *exec.Cmd
	frameDuration time.Duration
	ytdlp         *exec.Cmd
}

func (mr *MRadio) Init(bbb *Benbebots, state *session.Session, sc *SoundcloudClient, frameDur time.Duration, timeInc uint32) error {
	mr.benbebots = bbb
	mr.soundcloud = sc
	v, err := voice.NewSession(state)
	if err != nil {
		return err
	}

	mr.frameDuration = frameDur
	v.SetUDPDialer(udp.DialFuncWithFrequency(
		mr.frameDuration,
		timeInc,
	))

	mr.session = v

	if mr.FFmpegPath == "" {
		mr.FFmpegPath, _ = exec.LookPath("ffmpeg")
	}
	if mr.YtdlpPath == "" {
		mr.YtdlpPath, _ = exec.LookPath("yt-dlp")
	}
	return nil
}

func (mr *MRadio) GetTracks(endpoint string) error {
	mr.Lock()
	defer mr.Unlock()
	tracks := struct {
		Collection []struct {
			Created string `json:"created_at"`
			Kind    string `json:"kind"`
			Track   struct {
				Id uint64 `json:"id"`
			}
		}
		Next string `json:"next_href"`
	}{
		Next: endpoint,
	}
	for {
		parts, err := url.Parse(tracks.Next)
		if err != nil {
			return err
		}
		query := parts.Query()
		query.Set("limit", "100")
		query.Set("app_version", "1719992714")
		query.Set("app_locale", "en")

		resp, err := mr.soundcloud.Request("GET", parts.Path, query, "")
		if err != nil {
			return err
		}
		if resp.StatusCode != 200 {
			resp.Body.Close()
			log.Println(resp.StatusCode, resp.Status)
			return nil
		}
		data, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return err
		}
		err = json.Unmarshal(data, &tracks)
		if err != nil {
			return err
		}

		if len(tracks.Collection) <= 0 {
			break
		}

		for _, v := range tracks.Collection {
			mr.tracks = append(mr.tracks, v.Track.Id)
		}
	}
	log.Println("got soundcloud radio tracks")
	return nil
}

func (mr *MRadio) Start() error {
	mr.Lock()
	if mr.Active {
		mr.Unlock()
		return nil
	}
	err := mr.session.JoinChannel(context.Background(), mr.Channel, false, false)
	if err != nil {
		mr.Unlock()
		return err
	}
	mr.Active = true
	mr.Unlock()

	for mr.Active {
		id := mr.tracks[rand.Intn(len(mr.tracks))]

		mr.ffmpeg = exec.Command(mr.FFmpegPath,
			"-hide_banner", //"-loglevel", "error",
			"-threads", "2",
			"-i", "-",
			"-c:a", "libopus",
			"-b:a", "96k",
			"-frame_duration", strconv.FormatInt(mr.frameDuration.Milliseconds(), 10),
			"-vbr", "off",
			"-f", "opus",
			"-",
		)

		mr.ytdlp = exec.Command(mr.YtdlpPath,
			"--ignore-config",
			"--write-info-json", "--write-thumbnail",
			"--cache-dir", mr.benbebots.Dirs.Data+"yt-dlp/", "--cookies", mr.benbebots.Dirs.Data+"yt-dlp/cookies.netscape",
			"--use-extractors", "soundcloud",
			"--output", "-",
			"https://api.soundcloud.com/tracks/"+strconv.FormatUint(id, 10),
		)

		mr.ffmpeg.Dir, mr.ytdlp.Dir = mr.benbebots.Dirs.Temp, mr.benbebots.Dirs.Temp
		mr.ffmpeg.Stderr, mr.ytdlp.Stderr = os.Stderr, os.Stderr

		// link yt-dlp and ffmpeg
		r, err := mr.ffmpeg.StdinPipe()
		if err != nil {
			mr.benbebots.Logger.Error(err.Error())
			break
		}
		mr.ytdlp.Stdout = bufio.NewWriter(r)

		// link ffmpeg to discord
		o, err := mr.ffmpeg.StdoutPipe()
		if err != nil {
			mr.benbebots.Logger.Error(err.Error())
			break
		}

		if err := mr.ffmpeg.Start(); err != nil {
			mr.benbebots.Logger.Error(err.Error())
			break
		}
		if err := mr.ytdlp.Start(); err != nil {
			mr.benbebots.Logger.Error(err.Error())
			break
		}

		go func() {
			mr.ytdlp.Wait()
			time.Sleep(2 * time.Second)
			mr.ffmpeg.Process.Kill()
		}()

		mr.session.Speaking(context.Background(), voicegateway.Microphone)
		if err := oggreader.DecodeBuffered(mr.session, o); err != nil {
			mr.benbebots.Logger.Error(err.Error())
			break
		}
		mr.session.Speaking(context.Background(), voicegateway.NotSpeaking)
	}
	mr.ffmpeg.Process.Kill()
	mr.ytdlp.Process.Kill()
	mr.session.Leave(context.Background())
	return nil
}

func (mr *MRadio) Stop() {
	mr.Lock()
	mr.Active = false
	mr.ytdlp.Process.Kill()
	mr.ffmpeg.Process.Kill()
	mr.Unlock()
}

type BankSoundFile struct {
	Id        string `xml:"Id,attr"`
	ShortName string
	Path      string
}

func (sound BankSoundFile) PutInto(fileMap map[uint64]string) error {
	id, err := strconv.ParseUint(sound.Id, 10, 64)
	if err != nil {
		return err
	}
	fileMap[id] = filepath.Join(filepath.Dir(sound.Path), sound.ShortName)
	return nil
}

type OutlastTrialsDiff struct {
	SteamCMD  string        `ini:"steamcmd"`
	QuickBMS  string        `ini:"quickbms"`
	Interval  time.Duration `ini:"outlasttrialscheckinterval"`
	Username  string
	Password  string
	OutputDir string
}

var ErrUpToDate = errors.New("already up to date")
var ErrUnidentified = errors.New("could not parse error")
var ErrAlreadyExists = errors.New("this build has already been decompiled")

// var matchUpdateStatus, _ = regexp.Compile(`AppID\s*(\d+)\s*\((.*)\):`)
var matchSuccess, _ = regexp.Compile(`(:?Success|ERROR)!\s*([^\r\n]*)`)
var matchInstallDir, _ = regexp.Compile(`-\s*install\s*dir:\s*"([^"\n\r]+)`)
var matchBuildID, _ = regexp.Compile(`-\s*size\s*on\s*disk:\s*(\d+)\s*bytes,\s*BuildID\s*(\d+)`)

func limitBytes(b []byte, l int) []byte {
	if len(b) <= l {
		return b
	}
	return b[len(b)-l:]
}

func (o OutlastTrialsDiff) Execute() error {
	var errorList []string

	// update game to most recent
	var steamcmd *exec.Cmd
	if filepath.Ext(o.SteamCMD) == "sh" {
		steamcmd = exec.Command("bash", o.SteamCMD, "+login", o.Username, o.Password, "+app_update", "1304930", "+app_status", "1304930", "+quit")
	} else {
		steamcmd = exec.Command(o.SteamCMD, "+login", o.Username, o.Password, "+app_update", "1304930", "+app_status", "1304930", "+quit")
	}

	out, err := steamcmd.StdoutPipe()
	if err != nil {
		return err
	}

	steamcmd.Start()

	data, err := io.ReadAll(out)
	if err != nil {
		return err
	}

	steamcmd.Wait()

	data = limitBytes(data, 2048)

	stuff := matchSuccess.FindSubmatch(data)
	if len(stuff) != 3 {
		return ErrUnidentified
	}

	if !bytes.Equal(stuff[1], []byte("Success")) {
		log.Println(string(stuff[2]))
		return ErrUnidentified
	} else if bytes.Contains(stuff[2], []byte("already up to date")) {
		return ErrUpToDate
	} else if !bytes.Contains(stuff[2], []byte("fully installed")) {
		return ErrUnidentified
	}

	stuff = matchInstallDir.FindSubmatch(data)
	if len(stuff) != 2 {
		return ErrUnidentified
	}
	installationDir := string(stuff[1])

	stuff = matchBuildID.FindSubmatch(data)
	if len(stuff) != 3 {
		return ErrUnidentified
	}
	buildID := string(stuff[2])

	// decompile with bms
	currentDir := filepath.Join(o.OutputDir, buildID)
	os.MkdirAll(currentDir, 0777)

	bmsScript, err := os.Getwd()
	if err != nil {
		return err
	}
	bmsScript = filepath.Join(bmsScript, "resource/outlast-trials.bms")

	err = filepath.WalkDir(installationDir, func(pth string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if entry.IsDir() {
			return nil
		}

		ext := filepath.Ext(pth)
		switch ext {
		case ".pak":
			quickbms := exec.Command(o.QuickBMS+"_4gb_files", "-K", bmsScript, pth, currentDir)

			quickbms.Stdout = os.Stdout
			out, err = quickbms.StderrPipe()
			if err != nil {
				return err
			}

			quickbms.Start()

			data, err = io.ReadAll(out)
			if err != nil {
				return err
			}

			quickbms.Wait()

			data = limitBytes(data, 2048)
		default:
			source, err := os.Open(pth)
			if err != nil {
				return err
			}
			defer source.Close()

			rel, err := filepath.Rel(installationDir, pth)
			if err != nil {
				return err
			}
			output := filepath.Join(currentDir, rel)

			err = os.MkdirAll(filepath.Dir(output), 0777)
			if err != nil {
				return err
			}
			destination, err := os.Create(output)
			if err != nil {
				return err
			}
			defer destination.Close()

			_, err = io.Copy(destination, source)
			if err != nil {
				return err
			}
			log.Println(rel)
		}
		return nil
	})

	if err != nil {
		return err
	}

	// diff
	decomps, err := os.ReadDir(o.OutputDir)
	if err != nil {
		return err
	}

	var compareDir string
	{
		currentBID, err := strconv.ParseUint(buildID, 10, 64)
		if err != nil {
			return err
		}

		var compareBID uint64
		for _, d := range decomps {
			if !d.IsDir() {
				continue
			}

			compareBIDNew, err := strconv.ParseUint(d.Name(), 10, 64)
			if err != nil {
				errorList = append(errorList, filepath.Join(o.OutputDir, d.Name())+"\n\t"+err.Error())
				continue
			}

			if compareBIDNew > compareBID && compareBIDNew < currentBID {
				compareBID = compareBIDNew
				compareDir = filepath.Join(o.OutputDir, d.Name())
			}
		}
	}

	changelog, err := os.Create(filepath.Join(o.OutputDir, "changelog_"+buildID+".txt"))
	if err != nil {
		return err
	}
	defer changelog.Close()

	var addedFiles uint

	err = filepath.WalkDir(currentDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if d.IsDir() {
			if d.Name() == "WwiseAudio" {
				mount, err := filepath.Rel(currentDir, path)
				if err != nil {
					return err
				}

				systems, err := os.ReadDir(path)
				if err != nil {
					return err
				}
				for _, system := range systems {
					if !system.IsDir() {
						continue
					}

					systemPath := filepath.Join(path, system.Name())

					// read all indexing files
					wwiseFileMap := map[uint64]string{}

					err := filepath.WalkDir(systemPath, func(path string, d fs.DirEntry, err error) error {
						if err != nil {
							return err
						}

						if d.IsDir() {
							return nil
						}

						if filepath.Ext(path) != ".xml" {
							return nil
						}

						bankInfoFile, err := os.Open(path)
						if err != nil {
							return err
						}
						defer bankInfoFile.Close()

						SoundBankInfo := struct {
							StreamedFiles          []BankSoundFile `xml:"StreamedFiles>File"`
							MediaFilesNotInAnyBank []BankSoundFile `xml:"MediaFilesNotInAnyBank>File"`
							SoundBanks             []struct {
								IncludedEvents []struct {
									ExcludedMemoryFiles []BankSoundFile `xml:"ExcludedMemoryFiles>File"`
								}
							}
						}{}

						err = xml.NewDecoder(bankInfoFile).Decode(&SoundBankInfo)
						if err != nil {
							erro := path + "\n\t" + err.Error()
							if strings.Contains(err.Error(), "ï") {
								erro += "\n\tNOTE: this is likely because the file contains a utf8 bom"
							}
							errorList = append(errorList, erro)
							return nil
						}

						for i, sound := range SoundBankInfo.StreamedFiles {
							err = sound.PutInto(wwiseFileMap)
							if err != nil {
								errorList = append(errorList, fmt.Sprintf("%s\n\tSoundBanksInfo.StreamedFiles[%d]\n\t%s", path, i, err.Error()))
							}
						}
						for i, sound := range SoundBankInfo.MediaFilesNotInAnyBank {
							err = sound.PutInto(wwiseFileMap)
							if err != nil {
								errorList = append(errorList, fmt.Sprintf("%s\n\tSoundBanksInfo.MediaFilesNotInAnyBank[%d]\n\t%s", path, i, err.Error()))
							}
						}
						for bi, bank := range SoundBankInfo.SoundBanks {
							for ei, event := range bank.IncludedEvents {
								for i, sound := range event.ExcludedMemoryFiles {
									err = sound.PutInto(wwiseFileMap)
									if err != nil {
										errorList = append(errorList, fmt.Sprintf("%s\n\tSoundBanksInfo.SoundBanks[%d].IncludedEvents[%d].ExcludedMemoryFiles[%d]\n\t%s", path, bi, ei, i, err.Error()))
									}
								}
							}
						}
						return nil
					})

					if err != nil {
						return err
					}

					err = filepath.WalkDir(path, func(path string, d fs.DirEntry, err error) error {
						if err != nil {
							return err
						}

						if d.IsDir() {
							return nil
						}

						if filepath.Ext(path) != ".wem" {
							return nil
						}

						rel, err := filepath.Rel(currentDir, path)
						if err != nil {
							return err
						}

						_, err = os.Stat(filepath.Join(compareDir, rel))
						if errors.Is(err, os.ErrNotExist) {
							id, err := strconv.ParseUint(strings.TrimRight(filepath.Base(path), ".wem"), 10, 64)
							if err != nil {
								errorList = append(errorList, path+"\n\t"+err.Error())
								return nil
							}

							ath, ok := wwiseFileMap[id]

							if ok {
								changelog.WriteString("+ " + filepath.Join(mount, ath) + "\n")
							} else {
								changelog.WriteString("+ " + rel + "\n")
							}
							addedFiles += 1
						} else if err != nil {
							errorList = append(errorList, filepath.Join(compareDir, rel)+"\n\t"+err.Error())
						}

						return nil
					})

					if err != nil {
						return err
					}
				}

				return filepath.SkipDir
			}
			return nil
		}

		switch filepath.Ext(d.Name()) {
		case ".uexp":
			return nil
		case ".ubulk":
			return nil
		}

		rel, err := filepath.Rel(currentDir, path)
		if err != nil {
			return err
		}

		_, err = os.Stat(filepath.Join(compareDir, rel))
		if errors.Is(err, os.ErrNotExist) {
			changelog.WriteString("+ " + rel + "\n")
			addedFiles += 1
		} else if err != nil {
			errorList = append(errorList, filepath.Join(compareDir, rel)+"\n\t"+err.Error())
		}
		return nil
	})

	if err != nil {
		errorList = append(errorList, o.OutputDir+"\n\t"+err.Error())
	}

	changelog.WriteString(fmt.Sprintf("\n%d new files, %d removed files, %d modified files\n", addedFiles, 0, 0))

	changelog.WriteString("\nerrors:\n\n")
	for _, err := range errorList {
		changelog.WriteString(err + "\n\n")
	}

	log.Fatalln("DONE!")

	return err
}

func (bbb *Benbebots) RunBenbebot() {
	cfgSec := bbb.Config.Section("bot.benbebot")

	client := session.New("Bot " + bbb.Tokens["benbebot"].Password)
	client.AddIntents(gateway.IntentGuildPresences | gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddIntents(gateway.IntentGuildMessages | gateway.IntentDirectMessages)
	client.AddIntents(gateway.IntentGuilds)
	client.AddHandler(func(*gateway.ReadyEvent) {
		me, _ := client.Me()
		log.Println("Connected to discord as", me.Tag())
	})
	client.AddHandler(bbb.Heartbeater.Init)
	client.AddHandler(bbb.Heartbeater.Heartbeat)
	router := cmdroute.NewRouter()

	scClient := SoundcloudClient{
		MaxRetries: 1,
		LevelDB:    bbb.LevelDB,
	}
	scClient.GetClientId()
	{ // soundclown
		opts := struct {
			Cron        string `ini:"motdcron"`
			ChannelId   uint64 `ini:"motdchannel"`
			Channel     discord.ChannelID
			EndPoint    string `ini:"motdendpoint"`
			StatChannel uint64 `ini:"motdstatchannel"`
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))

		scStat := Stat{
			Name:      "Soundclowns",
			Value:     0,
			Client:    client.Client,
			LevelDB:   bbb.LevelDB,
			ChannelID: discord.ChannelID(opts.StatChannel),
			Delay:     time.Second * 5,
		}
		scStat.Initialise()

		var recents [30]uint
		var recentsIndex uint64
		client.AddHandler(func(*gateway.ReadyEvent) {
			validChannelsStr, err := bbb.LevelDB.Get([]byte("recentSoundclowns"), nil)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}

			strs := strings.Fields(string(validChannelsStr))
			recentsIndex, err = strconv.ParseUint(strs[0], 10, 64)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			strs = strs[1:]
			for i, v := range strs {
				id, err := strconv.ParseUint(v, 10, 64)
				if err != nil {
					bbb.Logger.Error(err.Error())
					return
				}
				recents[i] = uint(id)
			}
		})

		sendNewSoundclown := func() {
			// request soundcloud
			vals, _ := query.Values(struct {
				Limit      int    `url:"limit"`
				Offset     int    `url:"offset"`
				LinkedPart int    `url:"linked_partitioning"`
				Version    uint64 `url:"app_version"`
				Locale     string `url:"app_locale"`
			}{
				Limit:      20,
				LinkedPart: 1,
				Version:    1715268073,
				Locale:     "en",
			})
			resp, err := scClient.Request("GET", "/recent-tracks/soundclown", vals, "")
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			defer resp.Body.Close()
			if resp.StatusCode != 200 {
				bbb.Logger.Error(fmt.Errorf("couldnt get soundclouds: %s", resp.Status).Error())
				return
			}

			// get recent tracks
			data, err := io.ReadAll(resp.Body)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}
			tracks := struct {
				Collection []struct {
					Artwork      string    `json:"artwork_url"`
					Title        string    `json:"title"`
					Description  string    `json:"description"`
					Comments     uint      `json:"comment_count"`
					Likes        uint      `json:"likes_count"`
					Plays        uint      `json:"playback_count"`
					Reposts      uint      `json:"reposts_count"`
					CreatedAt    time.Time `json:"created_at"`
					Duration     uint      `json:"duration"`
					EmbeddableBy string    `json:"embeddable_by"`
					Id           uint      `json:"id"`
					Kind         string    `json:"kind"`
					Permalink    string    `json:"permalink_url"`
					Public       bool      `json:"public"`
					Sharing      string    `json:"sharing"`
				} `json:"collection"`
				Next string `json:"next_href"`
			}{}
			err = json.Unmarshal(data, &tracks)
			if err != nil {
				bbb.Logger.Error(err.Error())
				return
			}

			// filter sent already
			toSend, found := tracks.Collection[0], false
			for _, track := range tracks.Collection {
				sentAlready := false
				for _, rec := range recents {
					if track.Id == rec {
						sentAlready = true
						break
					}
				}
				if !sentAlready {
					toSend = track
					found = true
					break
				}
			}

			if !found {
				bbb.Logger.Error("could not find a soundcloud within 20 tracks")
				return
			}

			// add to recents
			recents[recentsIndex] = toSend.Id
			recentsIndex += 1
			if recentsIndex >= 30 {
				recentsIndex = 0
			}
			var str []byte
			str = append(strconv.AppendUint(str, recentsIndex, 10), ' ')
			for i := 0; i < 30; i++ {
				str = append(strconv.AppendUint(str, uint64(recents[i]), 10), ' ')
			}
			bbb.LevelDB.Put([]byte("recentSoundclowns"), str, nil)

			// send
			log.Println("sending soundclown")
			bbb.Logger.Assert2(client.SendMessage(opts.Channel, toSend.Permalink))
		}

		client.AddHandler(func(*gateway.ReadyEvent) {
			// get soundcloud token
			cltId, err := bbb.LevelDB.Get([]byte("soundcloudClientId"), nil)
			if err != nil {
				bbb.Logger.Error(err.Error())
				err = scClient.GetClientId()
				if err != nil {
					bbb.Logger.Error(err.Error())
				}
			} else {
				scClient.ClientId = string(cltId)
			}

			url := "https://soundcloud.com/"
			urlLen := len(url)
			var mut sync.Mutex
			bbb.Logger.Assert2(bbb.Cron.NewJob(gocron.CronJob(opts.Cron, true), gocron.NewTask(func() {
				mut.Lock()
				defer mut.Unlock()
				messages, err := client.Messages(opts.Channel, 1)
				if err != nil {
					bbb.Logger.Error(err.Error())
					return
				}
				message := messages[0]
				if len(message.Content) >= urlLen && message.Content[:urlLen] == url {
					fail, _ := bbb.Logger.Assert2(client.CrosspostMessage(opts.Channel, messages[0].ID))
					if !fail {
						scStat.Increment(1)
					}
				}

				sendNewSoundclown()
			}), gocron.WithSingletonMode(gocron.LimitModeReschedule)))
		})

		client.AddHandler(func(message *gateway.MessageDeleteEvent) {
			if message.ChannelID != opts.Channel {
				return
			}

			sendNewSoundclown()
		})
	}

	{ // mashup radio
		client.AddIntents(gateway.IntentGuildVoiceStates)
		var radio MRadio
		bbb.Config.Section("programs").MapTo(&radio)
		radio.Init(bbb, client, &scClient, 60*time.Millisecond, 2880)

		opts := struct {
			ChannelId uint64 `ini:"mrchannel"`
			Endpoint  string `ini:"mrendpoint"`
		}{}
		cfgSec.MapTo(&opts)
		radio.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))
		go func() {
			bbb.Logger.Assert(radio.GetTracks(opts.Endpoint))
		}()

		client.AddHandler(func(state *gateway.VoiceStateUpdateEvent) {
			if state.ChannelID != radio.Channel {
				return
			}
			go func() {
				bbb.Logger.Assert(radio.Start())
			}()
		})
	}

	{ // get logs
		router.AddFunc("getlog", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options = struct {
				Id string `discord:"id"`
			}{}
			if err := data.Options.Unmarshal(&options); err != nil {
				return bbb.CommandError(err)
			}

			buffer, err := os.ReadFile(bbb.Logger.Directory + options.Id + ".log")
			if err != nil {
				return bbb.CommandError(err)
			}

			if len(buffer) > 2000 {
				return bbb.CommandError(errors.New("too long woops"))
			}

			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("```\n%s\n```", string(buffer))),
			}
		})
	}

	{ // sex command
		router.AddFunc("sex", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			sndr := data.Event.SenderID()
			if sndr == 0 {
				bbb.Logger.Error("sender is 0")
				return &api.InteractionResponseData{
					Content: option.NewNullableString("how the fuck"),
					Flags:   discord.EphemeralMessage,
				}
			}
			ok, err := bbb.Logger.Assert(client.Ban(data.Event.GuildID, sndr, api.BanData{
				DeleteDays:     option.ZeroUint,
				AuditLogReason: "sex command",
			}))
			if !ok {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("error: " + err.Error()),
					Flags:   discord.EphemeralMessage,
				}
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString("idk"),
				Flags:   discord.EphemeralMessage,
			}
		})
	}

	{ // extract ad id
		opts := struct {
			ChannelId uint64 `ini:"adextractorchannel"`
			Channel   discord.ChannelID
		}{}
		cfgSec.MapTo(&opts)
		opts.Channel = discord.ChannelID(discord.Snowflake(opts.ChannelId))

		client.AddHandler(func(message *gateway.MessageCreateEvent) {
			if message.ChannelID != opts.Channel {
				return
			}
			if message.Author.Bot {
				return
			}

			if len(message.Attachments) < 1 {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			toDownload := message.Attachments[0]
			for _, attachemnt := range message.Attachments {
				if attachemnt.Filename == "message.txt" {
					toDownload = attachemnt
					break
				}
			}

			if toDownload.Size > 25000 {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fileBuffer := make([]byte, toDownload.Size)
			resp, err := http.Get(toDownload.URL)
			if err != nil {
				bbb.Logger.Error(err.Error())
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			if _, err := io.ReadFull(resp.Body, fileBuffer); err != nil {
				bbb.Logger.Error(err.Error())
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			debugInfo := struct {
				AdVideoId string `json:"addebug_videoId"`
			}{}
			fail, _ := bbb.Logger.Assert(json.Unmarshal(fileBuffer, &debugInfo))
			if fail {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
				return
			}

			fail, _ = bbb.Logger.Assert2(client.SendMessageReply(opts.Channel, "https://www.youtube.com/watch?v="+debugInfo.AdVideoId, message.ID))
			if fail {
				bbb.Logger.Assert(client.DeleteMessage(opts.Channel, message.ID, ""))
			}
		})
	}

	{
		opts := struct {
			StatsId uint64        `ini:"pingstatchannel"`
			Freq    time.Duration `ini:"pingfreq"`
		}{}
		cfgSec.MapTo(&opts)
		k, err := bbb.Config.Section("webhooks").GetKey("pinger")
		if err != nil {
			bbb.Logger.Error(err.Error())
		}
		pinghook, err := webhook.NewFromURL(string(k.String()))
		if err != nil {
			bbb.Logger.Error(err.Error())
		}

		var toPingMux sync.Mutex
		toPing := map[discord.UserID]uint64{}
		var toPingPendingDel []discord.UserID
		var pingerLock bool

		iter := bbb.LevelDB.NewIterator(nil, nil)
		for iter.Next() {
			k, v := iter.Key(), iter.Value()
			if string(k[:len("pingsFor")]) == "pingsFor" {
				id, err := strconv.ParseUint(string(k[len("pingsFor"):]), 10, 64)
				if err != nil {
					bbb.Logger.Error(err.Error())
					continue
				}
				toPing[discord.UserID(discord.Snowflake(id))], _ = binary.Uvarint(v)
			}
		}
		iter.Release()

		pgStat := Stat{
			Name:      "Pings",
			Value:     0,
			Client:    client.Client,
			LevelDB:   bbb.LevelDB,
			ChannelID: discord.ChannelID(opts.StatsId),
			Delay:     time.Second * 5,
		}
		pgStat.Initialise()

		wakePinger := func() {
			if pingerLock {
				return
			}
			pingerLock = true

			go func() {
				for {
					if len(toPing) <= 0 {
						break
					}
					var str string
					toPingMux.Lock()
					for i := range toPing {
						str += i.Mention()
						toPing[i] -= 1
						if toPing[i] <= 0 {
							toPingPendingDel = append(toPingPendingDel, i)
							delete(toPing, i)
						}
					}
					toPingMux.Unlock()
					pinghook.Execute(webhook.ExecuteData{
						Content: str,
					})
					pgStat.Increment(1)
					time.Sleep(opts.Freq)
				}
				pingerLock = false
			}()
			go func() {
				for pingerLock {
					time.Sleep(time.Second * 5)
					for i, v := range toPing {
						bbb.LevelDB.Put([]byte("pingsFor"+i.String()), binary.AppendUvarint(nil, v), nil)
					}
					for _, v := range toPingPendingDel {
						bbb.LevelDB.Delete([]byte("pingsFor"+v.String()), nil)
					}
					toPingPendingDel = make([]discord.UserID, 0)
				}
			}()
		}

		client.AddHandler(func(*gateway.ReadyEvent) {
			wakePinger()
		})

		router.AddFunc("pingme", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options = struct {
				Times float64 `discord:"times"`
			}{}
			if err := data.Options.Unmarshal(&options); err != nil {
				return bbb.CommandError(err)
			}
			userId := data.Event.SenderID()
			if userId <= 0 {
				return nil
			}

			if options.Times == 0 {
				return &api.InteractionResponseData{
					Content: option.NewNullableString(fmt.Sprintf("you have %d pings remaining\nthis will be finished <t:%d:R> aproximately", toPing[userId], time.Now().Add(opts.Freq*time.Duration(toPing[userId])).Unix())),
				}
			}

			toPingMux.Lock()
			defer toPingMux.Unlock()
			val, ok := toPing[userId]
			if ok {
				if math.Signbit(options.Times) {
					abs := uint64(math.Abs(options.Times))
					if abs <= val {
						toPing[userId] = val - abs
					} else {
						toPingPendingDel = append(toPingPendingDel, userId)
						delete(toPing, userId)
					}
				} else {
					toPing[userId] += uint64(math.Abs(options.Times))
				}
			} else {
				toPing[userId] = uint64(max(0, options.Times))
			}

			wakePinger()

			if _, ok := toPing[userId]; !ok {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("set to no longer ping you"),
				}
			}

			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("set to ping you %d times\nthis will be finished <t:%d:R> aproximately", toPing[userId], time.Now().Add(opts.Freq*time.Duration(toPing[userId])).Unix())),
			}
		})
	}

	{ // outlast trials diff
		var otd OutlastTrialsDiff
		cfgSec.MapTo(&otd)
		bbb.Config.Section("programs").MapTo(&otd)
		otd.Username = bbb.Tokens["steam"].Login
		otd.Password = bbb.Tokens["steam"].Password
		otd.OutputDir = filepath.Join(bbb.Dirs.Data, "opp-decomp")

		client.AddHandler(func(*gateway.ReadyEvent) {
			bbb.Logger.Assert(otd.Execute())
		})
	}

	client.AddInteractionHandler(router)
	client.Open(client.Context())
	bbb.AddClient(client)
	bbb.CoroutineGroup.Done()
}
