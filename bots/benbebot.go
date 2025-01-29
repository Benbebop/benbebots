package benbebots

import (
	"bufio"
	"bytes"
	"context"
	crand "crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"benbebop.net/benbebots/internal/generated/commands"
	"benbebop.net/benbebots/internal/log"
	"benbebop.net/benbebots/internal/soundcloud"
	"benbebop.net/benbebots/internal/stats"
	"benbebop.net/benbebots/internal/webscrobbler"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/cmdroute"
	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/diamondburned/arikawa/v3/gateway"
	"github.com/diamondburned/arikawa/v3/session"
	"github.com/diamondburned/arikawa/v3/state"
	"github.com/diamondburned/arikawa/v3/utils/json/option"
	"github.com/diamondburned/arikawa/v3/voice"
	"github.com/diamondburned/arikawa/v3/voice/udp"
	"github.com/diamondburned/arikawa/v3/voice/voicegateway"
	"github.com/diamondburned/oggreader"
	"github.com/go-co-op/gocron/v2"
	"github.com/google/go-querystring/query"
	"github.com/syndtr/goleveldb/leveldb"
	"gopkg.in/gographics/imagick.v2/imagick"
)

type MRadio struct {
	sync.Mutex
	session       *voice.Session
	tracks        []uint64
	Active        bool
	Channel       discord.ChannelID
	soundcloud    *soundcloud.Client
	FFmpegPath    string `ini:"ffmpeg"`
	YtdlpPath     string `ini:"ytdlp"`
	ffmpeg        *exec.Cmd
	frameDuration time.Duration
	ytdlp         *exec.Cmd
}

func (mr *MRadio) Init(state *session.Session, sc *soundcloud.Client, frameDur time.Duration, timeInc uint32) error {
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
			log.Warn("%d: %s", resp.StatusCode, resp.Status)
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
	log.Info("got soundcloud radio tracks")
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
			"--cache-dir", config.Dirs.Cache+"yt-dlp/", "--cookies", config.Dirs.Cache+"yt-dlp/cookies.netscape",
			"--use-extractors", "soundcloud",
			"--output", "-",
			"https://api.soundcloud.com/tracks/"+strconv.FormatUint(id, 10),
		)

		mr.ffmpeg.Dir, mr.ytdlp.Dir = config.Dirs.Temp, config.Dirs.Temp
		mr.ffmpeg.Stderr, mr.ytdlp.Stderr = os.Stderr, os.Stderr

		// link yt-dlp and ffmpeg
		r, err := mr.ffmpeg.StdinPipe()
		if err != nil {
			log.ErrorQuick(err)
			break
		}
		mr.ytdlp.Stdout = bufio.NewWriter(r)

		// link ffmpeg to discord
		o, err := mr.ffmpeg.StdoutPipe()
		if err != nil {
			log.ErrorQuick(err)
			break
		}

		if err := mr.ffmpeg.Start(); err != nil {
			log.ErrorQuick(err)
			break
		}
		if err := mr.ytdlp.Start(); err != nil {
			log.ErrorQuick(err)
			break
		}

		go func() {
			mr.ytdlp.Wait()
			time.Sleep(2 * time.Second)
			mr.ffmpeg.Process.Kill()
		}()

		mr.session.Speaking(context.Background(), voicegateway.Microphone)
		if err := oggreader.DecodeBuffered(mr.session, o); err != nil {
			log.ErrorQuick(err)
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

type benbebot struct{}

type motdConfig struct {
	Cron        string            `toml:"cron"`
	Channel     discord.ChannelID `toml:"channel"`
	Endpoint    string            `toml:"endpoint"`
	StatChannel discord.ChannelID `toml:"stat_channel"`
}

func (benbebot) MOTD(client *state.State) {
	scClient := soundcloud.Client{
		MaxRetries: 1,
		LevelDB:    lvldb,
	}
	scClient.GetClientId()
	scStat := stats.Stat{
		Name:      "Soundclowns",
		Value:     0,
		Client:    client.Client,
		LevelDB:   lvldb,
		ChannelID: config.Bot.Benbebots.MOTD.StatChannel,
		Delay:     time.Second * 5,
	}
	scStat.Initialise()

	var recents [30]uint
	var recentsIndex uint64
	client.AddHandler(func(*gateway.ReadyEvent) {
		validChannelsStr, err := lvldb.Get([]byte("recentSoundclowns"), nil)
		if err != nil {
			log.ErrorQuick(err)
			return
		}

		strs := strings.Fields(string(validChannelsStr))
		recentsIndex, err = strconv.ParseUint(strs[0], 10, 64)
		if err != nil {
			log.ErrorQuick(err)
			return
		}
		strs = strs[1:]
		for i, v := range strs {
			id, err := strconv.ParseUint(v, 10, 64)
			if err != nil {
				log.ErrorQuick(err)
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
			log.ErrorQuick(err)
			return
		}
		defer resp.Body.Close()
		if resp.StatusCode != 200 {
			log.Error("couldnt get soundclouds: %s", resp.Status)
			return
		}

		// get recent tracks
		data, err := io.ReadAll(resp.Body)
		if err != nil {
			log.ErrorQuick(err)
			return
		}
		tracks := struct {
			Collection []struct {
				Artwork      string    `json:"artwork_url"`
				Title        string    `json:"title"`
				Description  string    `json:"description"`
				Comments     int       `json:"comment_count"`
				Likes        int       `json:"likes_count"`
				Plays        int       `json:"playback_count"`
				Reposts      int       `json:"reposts_count"`
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
			log.ErrorQuick(err)
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
			log.Error("could not find a soundcloud within 20 tracks")
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
		lvldb.Put([]byte("recentSoundclowns"), str, nil)

		// send
		log.Assert(client.SendMessage(config.Bot.Benbebots.MOTD.Channel, toSend.Permalink))
		log.Info("submitted new mashup: %s", toSend.Title)
	}

	client.AddHandler(func(*gateway.ReadyEvent) {
		// get soundcloud token
		cltId, err := lvldb.Get([]byte("soundcloudClientId"), nil)
		if err != nil {
			log.ErrorQuick(err)
			err = scClient.GetClientId()
			if err != nil {
				log.ErrorQuick(err)
			}
		} else {
			scClient.ClientId = string(cltId)
		}

		url := "https://soundcloud.com/"
		urlLen := len(url)
		var mut sync.Mutex
		log.Assert(cron.NewJob(gocron.CronJob(config.Bot.Benbebots.MOTD.Cron, true), gocron.NewTask(func() {
			mut.Lock()
			defer mut.Unlock()
			messages, err := client.Messages(config.Bot.Benbebots.MOTD.Channel, 1)
			if err != nil {
				log.ErrorQuick(err)
				return
			}
			message := messages[0]
			if len(message.Content) >= urlLen && message.Content[:urlLen] == url {
				fail, _ := log.Assert(client.CrosspostMessage(config.Bot.Benbebots.MOTD.Channel, messages[0].ID))
				if !fail {
					scStat.Increment(1)
				}
			}

			sendNewSoundclown()
		}), gocron.WithSingletonMode(gocron.LimitModeReschedule)))
	})

	client.AddHandler(func(message *gateway.MessageDeleteEvent) {
		if message.ChannelID != config.Bot.Benbebots.MOTD.Channel {
			return
		}

		sendNewSoundclown()
	})
}

var errTooLong = errors.New("too long woops")

func (benbebot) LOG_COMMAND(_ *state.State, router *cmdroute.Router) {
	router.AddFunc("getlog", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
		var options = struct {
			Id string `discord:"id"`
		}{}
		if err := data.Options.Unmarshal(&options); err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}

		buffer, err := os.ReadFile(log.Directory + options.Id + ".log")
		if err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}

		if len(buffer) > 2000 {
			return log.InteractionResponse(log.ErrorQuick(errTooLong), errTooLong.Error())
		}

		return &api.InteractionResponseData{
			Content: option.NewNullableString(fmt.Sprintf("```\n%s\n```", string(buffer))),
		}
	})
}

var errSenderNil = errors.New("sender is 0")

func (benbebot) SEX_COMMAND(client *state.State, router *cmdroute.Router) {
	router.AddFunc(commands.SexName, func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
		sndr := data.Event.SenderID()
		if sndr == 0 {
			return log.InteractionResponse(log.ErrorQuick(errSenderNil), errSenderNil.Error())
		}
		err := client.Ban(data.Event.GuildID, sndr, api.BanData{
			DeleteDays:     option.ZeroUint,
			AuditLogReason: "sex command",
		})
		if err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}
		return &api.InteractionResponseData{
			Content: option.NewNullableString("idk"),
			Flags:   discord.EphemeralMessage,
		}
	})
}

type adExtractorConfig struct {
	Channel discord.ChannelID `toml:"channel"`
}

func (benbebot) AD_EXTRACTOR(client *state.State) {
	client.AddHandler(func(message *gateway.MessageCreateEvent) {
		if message.ChannelID != config.Bot.Benbebots.AdExtractor.Channel {
			return
		}
		if message.Author.Bot {
			return
		}

		if len(message.Attachments) < 1 {
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
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
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
			return
		}

		fileBuffer := make([]byte, toDownload.Size)
		resp, err := http.Get(toDownload.URL)
		if err != nil {
			log.ErrorQuick(err)
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
			return
		}

		if _, err := io.ReadFull(resp.Body, fileBuffer); err != nil {
			log.ErrorQuick(err)
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
			return
		}

		debugInfo := struct {
			AdVideoId string `json:"addebug_videoId"`
		}{}
		fail, _ := log.Assert(json.Unmarshal(fileBuffer, &debugInfo))
		if fail {
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
			return
		}

		fail, _ = log.Assert(client.SendMessageReply(config.Bot.Benbebots.AdExtractor.Channel, "https://www.youtube.com/watch?v="+debugInfo.AdVideoId, message.ID))
		if fail {
			log.Assert(client.DeleteMessage(config.Bot.Benbebots.AdExtractor.Channel, message.ID, ""))
		}
	})
}

type pingerConfig struct {
	StatChannel discord.ChannelID `toml:"stat_channel"`
	Frequency   time.Duration     `toml:"frequency"`
	Webhook     string            `toml:"webhook"`
}

type pinger struct {
	sync.Mutex
	hook       *webhook.Client
	stat       stats.Stat
	toPing     map[discord.UserID]uint64
	pendingDel []discord.UserID
	lock       bool
}

func (p *pinger) wake() {
	if p.lock {
		return
	}
	p.lock = true

	go func() {
		for {
			if len(p.toPing) <= 0 {
				break
			}
			var str string
			p.Lock()
			for i := range p.toPing {
				str += i.Mention()
				p.toPing[i] -= 1
				if p.toPing[i] <= 0 {
					p.pendingDel = append(p.pendingDel, i)
					delete(p.toPing, i)
				}
			}
			p.Unlock()
			p.hook.Execute(webhook.ExecuteData{
				Content: str,
			})
			p.stat.Increment(1)
			time.Sleep(config.Bot.Benbebots.Pinger.Frequency)
		}
		p.lock = false
	}()
	go func() {
		for p.lock {
			time.Sleep(time.Second * 5)
			for i, v := range p.toPing {
				lvldb.Put([]byte("pingsFor"+i.String()), binary.AppendUvarint(nil, v), nil)
			}
			for _, v := range p.pendingDel {
				lvldb.Delete([]byte("pingsFor"+v.String()), nil)
			}
			p.pendingDel = make([]discord.UserID, 0)
		}
	}()
}

const pingerDatabasePrefix = "pingsFor"

func (benbebot) PINGER(client *state.State, router *cmdroute.Router) {
	ping := pinger{
		stat: stats.Stat{
			Name:      "Pings",
			Value:     0,
			Client:    client.Client,
			LevelDB:   lvldb,
			ChannelID: config.Bot.Benbebots.Pinger.StatChannel,
			Delay:     time.Second * 5,
		},
		toPing: make(map[discord.UserID]uint64),
	}
	var err error
	ping.hook, err = webhook.NewFromURL(config.Bot.Benbebots.Pinger.Webhook)
	if err != nil {
		log.ErrorQuick(err)
	}

	iter := lvldb.NewIterator(nil, nil)
	for iter.Next() {
		k, v := iter.Key(), iter.Value()
		if len(k) >= len(pingerDatabasePrefix) && string(k[:len(pingerDatabasePrefix)]) == "pingsFor" {
			id, err := strconv.ParseUint(string(k[len("pingsFor"):]), 10, 64)
			if err != nil {
				log.ErrorQuick(err)
				continue
			}
			ping.toPing[discord.UserID(discord.Snowflake(id))], _ = binary.Uvarint(v)
		}
	}
	iter.Release()

	client.AddHandler(func(*gateway.ReadyEvent) {
		ping.wake()
	})

	router.AddFunc(commands.PingMeName, func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
		var options = struct {
			Times float64 `discord:"times"`
		}{}
		if err := data.Options.Unmarshal(&options); err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}
		userId := data.Event.SenderID()
		if userId <= 0 {
			return nil
		}

		if options.Times == 0 {
			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("you have %d pings remaining\nthis will be finished <t:%d:R> aproximately", ping.toPing[userId], time.Now().Add(config.Bot.Benbebots.Pinger.Frequency*time.Duration(ping.toPing[userId])).Unix())),
			}
		}

		ping.Lock()
		defer ping.Unlock()
		val, ok := ping.toPing[userId]
		if ok {
			if math.Signbit(options.Times) {
				abs := uint64(math.Abs(options.Times))
				if abs <= val {
					ping.toPing[userId] = val - abs
				} else {
					ping.pendingDel = append(ping.pendingDel, userId)
					delete(ping.toPing, userId)
				}
			} else {
				ping.toPing[userId] += uint64(math.Abs(options.Times))
			}
		} else {
			ping.toPing[userId] = uint64(max(0, options.Times))
		}

		ping.wake()

		if _, ok := ping.toPing[userId]; !ok {
			return &api.InteractionResponseData{
				Content: option.NewNullableString("set to no longer ping you"),
			}
		}

		return &api.InteractionResponseData{
			Content: option.NewNullableString(fmt.Sprintf("set to ping you %d times\nthis will be finished <t:%d:R> aproximately", ping.toPing[userId], time.Now().Add(config.Bot.Benbebots.Pinger.Frequency*time.Duration(ping.toPing[userId])).Unix())),
		}
	})
}

type permaroles struct {
	DB *leveldb.DB
}

type userRole struct {
	User discord.UserID `discord:"user?"`
	Role discord.RoleID `discord:"role?"`
}

func (p *permaroles) getKey(user discord.UserID) []byte {
	return binary.BigEndian.AppendUint64([]byte("permaroleProfile"), uint64(user))
}

func (p *permaroles) find(ur userRole) ([]byte, []byte, []byte, int, error) {
	key := p.getKey(ur.User)
	role := binary.BigEndian.AppendUint64([]byte(""), uint64(ur.Role))

	val, err := p.DB.Get(key, nil)
	if errors.Is(err, leveldb.ErrNotFound) {
		return key, role, []byte{}, -1, nil
	} else if err != nil {
		return nil, nil, nil, 0, err
	}

	for i := 0; i < len(val); i += 8 {
		if bytes.Equal(val[i:i+8], role) {
			return key, role, val, i, nil
		}
	}
	return key, role, val, -1, nil
}

var ErrAlreadyExists = errors.New("permarole already added")

func (p *permaroles) Add(ur userRole) error {
	key, role, val, index, err := p.find(ur)
	if err != nil {
		return err
	}

	if index < 0 {
		return p.DB.Put(key, append(val, role...), nil)
	}

	return ErrAlreadyExists
}

var ErrNotExists = errors.New("role does not exist")

func (p *permaroles) Remove(ur userRole) error {
	key, _, val, index, err := p.find(ur)
	if err != nil {
		return err
	}

	if index >= 0 {
		return p.DB.Put(key, append(val[:index], val[index+8:]...), nil)
	}

	return ErrNotExists
}

func (p *permaroles) RemoveAll(user discord.UserID) error {
	return p.DB.Delete(p.getKey(user), nil)
}

func (p *permaroles) Get(user discord.UserID) ([]discord.RoleID, error) {
	val, err := p.DB.Get(p.getKey(user), nil)
	if err != nil {
		return nil, err
	}

	roles := make([]discord.RoleID, 0, len(val)/8)
	for i := 0; i < len(val); i += 8 {
		roles = append(roles, discord.RoleID(binary.BigEndian.Uint64(val[i:i+8])))
	}
	return roles, nil
}

func (benbebot) PERMAROLES(client *state.State, router *cmdroute.Router) {
	pr := permaroles{
		DB: lvldb,
	}

	router.Sub(commands.ManagePermarolesName, func(r *cmdroute.Router) {
		r.AddFunc("add", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options userRole

			if err := data.Options.Unmarshal(&options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			if _, err := client.Member(data.Data.GuildID, options.User); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			if err := pr.Add(options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("succesfully added role %d to user %d", options.Role, options.User)),
			}
		})
		r.AddFunc("remove", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options userRole

			if err := data.Options.Unmarshal(&options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			if _, err := client.Member(data.Data.GuildID, options.User); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			if err := pr.Remove(options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("succesfully removed role %d from user %d", options.Role, options.User)),
			}
		})
		r.AddFunc("list", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options userRole

			if err := data.Options.Unmarshal(&options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			if _, err := client.Member(data.Data.GuildID, options.User); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			roles, err := pr.Get(options.User)
			if errors.Is(err, leveldb.ErrNotFound) {
				return &api.InteractionResponseData{
					Content:         option.NewNullableString("user has no permaroles"),
					AllowedMentions: &api.AllowedMentions{},
				}
			} else if err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			var roleStr string
			for _, role := range roles {
				roleStr += role.Mention()
			}

			return &api.InteractionResponseData{
				Content:         option.NewNullableString(roleStr),
				AllowedMentions: &api.AllowedMentions{},
			}
		})
	})
	router.Sub(commands.PermaroleName, func(r *cmdroute.Router) {
		r.AddFunc("add", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options userRole

			if err := data.Options.Unmarshal(&options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			options.User = data.Event.SenderID()

			// see if user has role
			member, err := client.Member(data.Data.GuildID, options.User)
			if err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			var exists bool
			for _, role := range member.RoleIDs {
				if role == options.Role {
					exists = true
					break
				}
			}

			if !exists {
				return &api.InteractionResponseData{
					Content: option.NewNullableString("you must already have a role to add it as a permarole"),
				}
			}

			if err := pr.Add(options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("succesfully added role %d", options.Role)),
			}
		})
		r.AddFunc("remove", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			var options userRole

			if err := data.Options.Unmarshal(&options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			options.User = data.Event.SenderID()

			if err := pr.Remove(options); err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}
			return &api.InteractionResponseData{
				Content: option.NewNullableString(fmt.Sprintf("succesfully removed role %d", options.Role)),
			}
		})
		r.AddFunc("list", func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
			roles, err := pr.Get(data.Event.SenderID())
			if errors.Is(err, leveldb.ErrNotFound) {
				return &api.InteractionResponseData{
					Content:         option.NewNullableString("you have no permaroles"),
					AllowedMentions: &api.AllowedMentions{},
				}
			} else if err != nil {
				return log.InteractionResponse(log.ErrorQuick(err), err.Error())
			}

			var roleStr string
			for _, role := range roles {
				roleStr += role.Mention()
			}

			return &api.InteractionResponseData{
				Content:         option.NewNullableString(roleStr),
				AllowedMentions: &api.AllowedMentions{},
			}
		})
	})

	client.AddHandler(func(member *gateway.GuildMemberAddEvent) {
		if member.GuildID != config.Servers.BreadBag {
			return
		}

		roles, err := pr.Get(member.User.ID)
		if err != nil {
			log.ErrorQuick(err)
			return
		}

		for _, role := range roles {
			client.AddRole(config.Servers.BreadBag, member.User.ID, role, api.AddRoleData{
				AuditLogReason: api.AuditLogReason("Adding user permaroles"),
			})
		}
	})
}

var matchEverything, _ = regexp.Compile("@everything")

type pingEverythingConfig struct {
	StatChannel discord.ChannelID `toml:"stat_channel"`
}

func (benbebot) PING_EVERYTHING(client *state.State) {
	eStat := stats.Stat{
		Name:      "Everythings Pinged",
		Value:     0,
		Client:    client.Client,
		LevelDB:   lvldb,
		ChannelID: config.Bot.Benbebots.PingEverything.StatChannel,
		Delay:     time.Second * 5,
	}
	eStat.Initialise()

	mentionCache := struct {
		mentions []string
		gentime  time.Time
	}{}

	var lock sync.Mutex
	client.AddHandler(func(message *gateway.MessageCreateEvent) {
		if message.GuildID != config.Servers.BreadBag {
			return
		}

		if message.Author.Bot {
			return
		}

		if !matchEverything.MatchString(message.Content) {
			return
		}

		lock.Lock()
		defer lock.Unlock()

		if time.Since(mentionCache.gentime) > 5*time.Minute {
			roles, err := client.Roles(config.Servers.BreadBag)
			if err != nil {
				log.ErrorQuick(err)
				return
			}
			members, err := client.Members(config.Servers.BreadBag)
			if err != nil {
				log.ErrorQuick(err)
				return
			}
			channels, err := client.Channels(config.Servers.BreadBag)
			if err != nil {
				log.ErrorQuick(err)
				return
			}

			mentionCache.mentions = make([]string, 0, len(roles)+len(members)+len(channels))

			for _, role := range roles {
				mentionCache.mentions = append(mentionCache.mentions, role.Mention())
			}

			for _, member := range members {
				mentionCache.mentions = append(mentionCache.mentions, member.Mention())
			}

			for _, channel := range channels {
				mentionCache.mentions = append(mentionCache.mentions, channel.Mention())
			}
		}

		mentions := mentionCache.mentions

		for i := range mentions {
			j := rand.Intn(i + 1)
			mentions[i], mentions[j] = mentions[j], mentions[i]
		}

		var str string
		for _, mention := range mentions {
			if len(str)+len(mention) > 2000 {
				_, err := client.SendMessage(message.ChannelID, str)
				if err != nil {
					log.ErrorQuick(err)
				}
				str = ""
			}

			str += mention
		}
		if str != "" {
			_, err := client.SendMessage(message.ChannelID, str)
			if err != nil {
				log.ErrorQuick(err)
			}
		}

		eStat.Increment(1)
	})
}

type extraWebhooksConfig struct {
	Category discord.ChannelID `toml:"category"`
	Webhook  string            `toml:"webhook"`
}

func (benbebot) EXTRA_WEBHOOKS(client *state.State) {
	wh, err := webhook.NewFromURL(config.Bot.Benbebots.ExtraWebhooks.Webhook)
	if err != nil {
		log.Fatal("%s", err)
	}
	var category struct {
		channel discord.ChannelID
		guild   discord.GuildID
	}
	category.channel = config.Bot.Benbebots.ExtraWebhooks.Category

	var master discord.ChannelID
	var proxies []discord.ChannelID

	client.AddHandler(func(*gateway.ReadyEvent) {
		channel, err := client.Channel(category.channel)
		if err != nil {
			log.ErrorQuick(err)
			return
		}
		category.guild = channel.GuildID

		m, err := lvldb.Get([]byte("extwhMaster"), nil)
		if errors.Is(err, leveldb.ErrNotFound) {
			channel, err := client.CreateChannel(category.guild, api.CreateChannelData{
				Name:       "extra-webhooks-master",
				Type:       discord.GuildText,
				CategoryID: category.channel,
			})
			if err != nil {
				log.ErrorQuick(err)
				return
			}
			master = channel.ID
			proxies = []discord.ChannelID{master}
			lvldb.Put([]byte("extwhMaster"), binary.BigEndian.AppendUint64(nil, uint64(master)), nil)
			lvldb.Put([]byte("extwhProxies"), binary.BigEndian.AppendUint64(nil, uint64(master)), nil)
			return
		} else if err != nil {
			log.ErrorQuick(err)
			return
		}
		master = discord.ChannelID(binary.BigEndian.Uint64(m))

		m, err = lvldb.Get([]byte("extwhProxies"), nil)
		if err != nil {
			log.ErrorQuick(err)
			return
		}

		for i := 0; i < len(m); i += 8 {
			proxies = append(proxies, discord.ChannelID(binary.BigEndian.Uint64(m[i:i+8])))
		}

		m, err = lvldb.Get([]byte("extwhLastRecieved"), nil)
		if false && !errors.Is(err, leveldb.ErrNotFound) { // disable this cause it doesnt seem to work
			if err != nil {
				log.ErrorQuick(err)
				return
			}
			nLR := discord.MessageID(binary.BigEndian.Uint64(m[:8]))
			nLRT := nLR.Time()

			for _, channel := range proxies {
				msgs, err := client.MessagesAfter(channel, nLR, 0)
				if err != nil {
					log.ErrorQuick(err)
					continue
				}
				for _, message := range msgs {
					if message.Type == discord.ChannelFollowAddMessage {
						continue
					}

					files := "\n"
					for _, file := range message.Attachments {
						files += file.URL + "\n"
					}

					content := message.Content
					if len(content)+len(files) <= 2000 {
						content += files
					}

					wh.Execute(webhook.ExecuteData{
						Content:         content,
						Username:        message.Author.Username,
						AvatarURL:       message.Author.AvatarURL(),
						TTS:             message.TTS,
						Embeds:          message.Embeds,
						Components:      message.Components,
						AllowedMentions: &api.AllowedMentions{},
					})

					if message.ID.Time().After(nLRT) {
						nLR = message.ID
						nLRT = message.ID.Time()
					}
				}
			}
			err = lvldb.Put([]byte("extwhLastRecieved"), binary.BigEndian.AppendUint64(nil, uint64(nLR)), nil)
			if err != nil {
				log.ErrorQuick(err)
				return
			}
		}
	})

	var followLock sync.Mutex

	client.AddHandler(func(message *gateway.MessageCreateEvent) {
		if message.GuildID != category.guild {
			return
		}

		if message.Type == discord.ChannelFollowAddMessage {
			followLock.Lock()
			defer followLock.Unlock()

			if message.ChannelID != master {
				return
			}

			webhooks, err := client.ChannelWebhooks(message.ChannelID)
			if err != nil {
				log.ErrorQuick(err)
				return
			}

			if len(webhooks) < 15 {
				return
			}

			log.Assert(client.ModifyChannel(master, api.ModifyChannelData{
				Name: fmt.Sprintf("extra-webhooks-%x", len(proxies)),
			}))

			channel, err := client.CreateChannel(category.guild, api.CreateChannelData{
				Name:       "extra-webhooks-master",
				Type:       discord.GuildText,
				CategoryID: category.channel,
			})
			if err != nil {
				log.ErrorQuick(err)
				return
			}

			master = channel.ID
			proxies = append(proxies, master)
			var proxStr []byte
			for _, proxy := range proxies {
				proxStr = binary.BigEndian.AppendUint64(proxStr, uint64(proxy))
			}
			lvldb.Put([]byte("extwhMaster"), binary.BigEndian.AppendUint64(nil, uint64(master)), nil)
			lvldb.Put([]byte("extwhProxies"), proxStr, nil)
			return
		}

		var valid bool
		for _, channel := range proxies {
			if message.ChannelID == channel {
				valid = true
				break
			}
		}

		if !valid {
			return
		}

		files := "\n"
		for _, file := range message.Attachments {
			files += file.URL + "\n"
		}

		content := message.Content
		if len(content)+len(files) <= 2000 {
			content += files
		}

		wh.Execute(webhook.ExecuteData{
			Content:         content,
			Username:        message.Author.Username,
			AvatarURL:       message.Author.AvatarURL(),
			TTS:             message.TTS,
			Embeds:          message.Embeds,
			Components:      message.Components,
			AllowedMentions: &api.AllowedMentions{},
		})
		err = lvldb.Put([]byte("extwhLastRecieved"), binary.BigEndian.AppendUint64(nil, uint64(message.ID)), nil)
		if err != nil {
			log.ErrorQuick(err)
			return
		}
	})
}

type firstAMConfig struct {
	Webhook string `toml:"webhook"`
}

const faKeyLength = 24

func (benbebot) FIRSTAM(client *state.State, router *cmdroute.Router) {
	wh, err := webhook.NewFromURL(config.Bot.Benbebots.FirstAM.Webhook)
	if err != nil {
		log.Fatal("%s", err)
	}

	mux.HandleFunc("POST /firstam/{user}/{id}", func(w http.ResponseWriter, r *http.Request) {
		userId, err := discord.ParseSnowflake(r.PathValue("user")) // TODO: contribute to arikawa to deprecate this and replace it with snowflake.UnmarshalText
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		}
		key, err := base64.RawURLEncoding.DecodeString(r.PathValue("id"))
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		} else if len(key) != faKeyLength {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, "invalid key length\n")
			return
		}

		userKey, err := lvldb.Get(binary.BigEndian.AppendUint64([]byte("firstAMKey"), uint64(userId)), nil)
		if errors.Is(err, leveldb.ErrNotFound) {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusNotFound)
			io.WriteString(w, "user not found\n")
			return
		} else if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		}

		if subtle.ConstantTimeCompare(userKey, key) != 1 {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusForbidden)
			return
		}

		var event webscrobbler.Event

		err = json.NewDecoder(r.Body).Decode(&event)
		if err != nil {
			if _, ok := err.(*json.SyntaxError); ok {
				w.WriteHeader(http.StatusBadRequest)
			} else if _, ok := err.(*json.UnmarshalTypeError); ok {
				w.WriteHeader(http.StatusBadRequest)
			} else {
				w.WriteHeader(http.StatusInternalServerError)
			}
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		}

		if event.EventName != "scrobble" {
			w.WriteHeader(http.StatusOK)
			return
		}

		member, err := client.Member(config.Servers.Benbebots, discord.UserID(userId))
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusGone)
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		}

		songs := event.Data.Songs
		if len(songs) <= 0 {
			songs = []webscrobbler.Song{
				event.Data.Song,
			}
		}

		var embeds []discord.Embed
		for _, song := range songs {
			embed := discord.NewEmbed()
			if song.Metadata.TrackArtURL != "" {
				embed.Image = &discord.EmbedImage{}
				embed.Image.URL = song.Metadata.TrackArtURL
			} else if song.Parsed.TrackArt != "" {
				embed.Image = &discord.EmbedImage{}
				embed.Image.URL = song.Parsed.TrackArt
			}
			if embed.Image != nil {
				embed.Color = func() discord.Color {
					resp, err := http.Get(embed.Image.URL)
					if err != nil {
						return discord.NullColor
					}

					imgData, err := io.ReadAll(resp.Body)
					if err != nil {
						return discord.NullColor
					}

					mw := imagick.NewMagickWand()
					err = mw.ReadImageBlob(imgData)
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}

					err = mw.ResizeImage(1, 1, imagick.FILTER_BOX, 0)
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}

					err = mw.SetDepth(8)
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}
					err = mw.SetFormat("RGB")
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}
					err = mw.SetSize(1, 1)
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}
					rawData, err := mw.GetImageBlob()
					if err != nil {
						log.ErrorQuick(err)
						return discord.NullColor
					}

					rawData = append(rawData, '\x00')
					if e := mw.GetImageEndian(); e == imagick.ENDIAN_LSB {
						return discord.Color(binary.LittleEndian.Uint32(rawData))
					} else if e == imagick.ENDIAN_MSB {
						return discord.Color(binary.BigEndian.Uint32(rawData))
					}
					return discord.NullColor
				}()
			}

			if song.Processed.Track != "" {
				embed.Title = song.Processed.Track
			} else if song.Parsed.Track != "" {
				embed.Title = song.Parsed.Track
			}

			if song.Metadata.TrackURL != "" {
				embed.URL = song.Metadata.TrackURL
			} else if song.Parsed.OriginURL != "" {
				embed.URL = song.Parsed.OriginURL
			}

			if song.Processed.Artist != "" {
				embed.Author = &discord.EmbedAuthor{}
				embed.Author.Name = song.Processed.Artist
			} else if song.Parsed.Artist != "" {
				embed.Author = &discord.EmbedAuthor{}
				embed.Author.Name = song.Parsed.Artist
			}
			if embed.Author != nil && song.Metadata.ArtistURL != "" {
				embed.Author.URL = song.Metadata.ArtistURL
			}

			embeds = append(embeds, *embed)
		}

		err = wh.Execute(webhook.ExecuteData{
			Embeds:    embeds,
			Username:  member.User.Username,
			AvatarURL: member.User.AvatarURL(),
		})
		if err != nil {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusInternalServerError)
			io.WriteString(w, err.Error())
			w.Write([]byte{'\n'})
			return
		}

		w.WriteHeader(http.StatusOK)
	})

	router.AddFunc(commands.FirstAMName, func(ctx context.Context, data cmdroute.CommandData) *api.InteractionResponseData {
		s := data.Event.SenderID()

		id := make([]byte, faKeyLength)
		_, err := crand.Read(id)
		if err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}

		err = lvldb.Put(binary.BigEndian.AppendUint64([]byte("firstAMKey"), uint64(s)), id, nil)
		if err != nil {
			return log.InteractionResponse(log.ErrorQuick(err), err.Error())
		}

		return &api.InteractionResponseData{
			Content: option.NewNullableString(fmt.Sprintf(
				"https://api.benbebop.net/discord/firstam/%s/%s",
				s.String(),
				base64.RawURLEncoding.EncodeToString(id),
			)),
			Flags: discord.EphemeralMessage,
		}
	})
}

type BenbebotConfig struct {
	MOTD           motdConfig           `toml:"motd"`
	AdExtractor    adExtractorConfig    `toml:"ad_extractor"`
	Pinger         pingerConfig         `toml:"pinger"`
	PingEverything pingEverythingConfig `toml:"ping_everything"`
	ExtraWebhooks  extraWebhooksConfig  `toml:"extra_webhooks"`
	FirstAM        firstAMConfig        `toml:"firstam"`
}

func (Benbebots) BENBEBOT() *session.Session {
	client := state.New("Bot " + tokens["benbebot"].Password)
	client.AddIntents(gateway.IntentGuildPresences | gateway.IntentGuildMembers | gateway.IntentMessageContent) // privileged
	client.AddIntents(gateway.IntentGuildMessages | gateway.IntentDirectMessages)
	client.AddIntents(gateway.IntentGuilds)
	client.AddHandler(heartbeater.Init)
	client.AddHandler(heartbeater.Heartbeat)
	router := cmdroute.NewRouter()

	args := []reflect.Value{
		reflect.ValueOf(benbebot{}),
		reflect.ValueOf(client),
		reflect.ValueOf(router),
	}

	b := reflect.TypeFor[benbebot]()
	for i := 0; i < b.NumMethod(); i++ {
		m := b.Method(i)

		if config.Components.IsEnabled(strings.ToLower(m.Name)) {
			m.Func.Call(args[:m.Type.NumIn()])
		}
	}

	client.AddInteractionHandler(router)
	return client.Session
}
