package logger

import (
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/discord"
)

type SLogCompat struct {
	DL *DiscordLogger
}

func (l *SLogCompat) Debug(msg string, args ...any) {
	l.DL.out(-1, msg, args)
}

func (l *SLogCompat) Error(msg string, args ...any) {
	l.DL.out(2, msg, args)
}

func (l *SLogCompat) Info(msg string, args ...any) {
	l.DL.out(0, msg, args)
}

func (l *SLogCompat) Warn(msg string, args ...any) {
	l.DL.out(1, msg, args)
}

func NewDiscordLogger(loglevel int, dir string, wh string) (*DiscordLogger, error) {
	cl, err := webhook.NewFromURL(wh)
	if err != nil {
		return nil, err
	}

	return &DiscordLogger{
		WebhookLogLevel: loglevel,
		OutLogLevel:     loglevel,
		Directory:       dir,
		Webhook:         cl,
	}, nil
}

type DiscordLogger struct {
	WebhookLogLevel int
	OutLogLevel     int
	Directory       string
	Webhook         *webhook.Client
}

var traceSterliser *regexp.Regexp = regexp.MustCompile("0[xX][0-9a-fA-F]+|goroutine [0-9]+")

func (l *DiscordLogger) out(level int, msg string, args []any) uint32 {
	out := fmt.Sprintf(msg, args...)

	// short outputs
	var label string
	switch level {
	case 2:
		label = "ERR"
	case 1:
		label = "WRN"
	case 0:
		label = "INF"
	case -1:
		label = "DBG"
	}
	log.Printf("[%s] %s", label, out)
	if level >= l.WebhookLogLevel {
		l.Webhook.Execute(webhook.ExecuteData{
			Content: out,
		})
	}

	if level >= l.OutLogLevel {
		// add traceback
		trc := make([]byte, 2048)
		n := runtime.Stack(trc, false)
		out += "\n\n" + string(trc[:n])

		// generate id
		hasher := sha1.New()
		hasher.Write(traceSterliser.ReplaceAll([]byte(out), []byte("")))
		id := binary.BigEndian.Uint32(hasher.Sum(nil))

		// create log file
		file, err := os.OpenFile(filepath.Join(l.Directory, base64.URLEncoding.EncodeToString(binary.BigEndian.AppendUint32(nil, id))+".log"), os.O_CREATE|os.O_WRONLY, 0777)
		if err != nil {
			return 0
		}
		_, err = file.Write([]byte(out))
		if err != nil {
			return 0
		}
		file.Close()

		return id
	}

	return 0
}

func (l *DiscordLogger) Dump(data []byte, level int, msg string, args ...any) uint32 {
	id := l.out(level, msg, args)

	file, err := os.OpenFile(filepath.Join(l.Directory, base64.URLEncoding.EncodeToString(binary.BigEndian.AppendUint32(nil, id))+".dmp"), os.O_CREATE|os.O_WRONLY, 0777)
	if err != nil {
		return 0
	}
	_, err = file.Write(data)
	if err != nil {
		return 0
	}
	file.Close()
	return id
}

func (l *DiscordLogger) Error(msg string, args ...any) uint32 {
	return l.out(2, msg, args)
}

func (l *DiscordLogger) ErrorQuick(err error) uint32 {
	return l.Error("%s", err)
}

func (l *DiscordLogger) Warn(msg string, args ...any) uint32 {
	return l.out(1, msg, args)
}

func (l *DiscordLogger) Info(msg string, args ...any) uint32 {
	return l.out(0, msg, args)
}

func (l *DiscordLogger) Debug(msg string, args ...any) uint32 {
	return l.out(-1, msg, args)
}

var errType = reflect.TypeFor[error]()

func (l *DiscordLogger) Assert(returns ...any) (bool, uint32) {
	for _, ret := range returns {
		if reflect.TypeOf(ret) == errType {
			return true, l.Error("%s", ret)
		}
	}

	return false, 0
}

func (l *DiscordLogger) InteractionResponse(id uint32, title string) *api.InteractionResponseData {
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
	idStr := base64.URLEncoding.EncodeToString(binary.BigEndian.AppendUint32(nil, id))

	return &api.InteractionResponseData{
		Flags: discord.EphemeralMessage,
		Embeds: &[]discord.Embed{
			{
				Author: &discord.EmbedAuthor{
					Name: "There was an error!",
				},
				URL:         "https://github.com/Benbebop/benbebots/issues/new?body=" + url.QueryEscape(fmt.Sprintf("error code: %s\n\n", idStr)),
				Title:       idStr,
				Description: title,
				Footer: &discord.EmbedFooter{
					Text: stk,
				},
			},
		},
	}
}