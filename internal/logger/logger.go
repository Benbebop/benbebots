package logger

import (
	"bytes"
	"crypto/sha1"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"runtime/debug"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/api/webhook"
	"github.com/diamondburned/arikawa/v3/discord"
)

const logPerms = 0777

func NewDiscordLogger(loglevel int, dir string, wh string) (*DiscordLogger, error) {
	cl, err := webhook.NewFromURL(wh)
	if err != nil {
		return nil, err
	}

	return &DiscordLogger{
		FileLogLevel:  loglevel,
		PrintLogLevel: loglevel,
		WebLogLevel:   loglevel,
		Directory:     dir,
		Webhook:       cl,
		OnFatal: func() {
			os.Exit(1)
		},
	}, nil
}

type DiscordLogger struct {
	FileLogLevel  int
	PrintLogLevel int
	WebLogLevel   int
	Directory     string
	Webhook       *webhook.Client
	OnFatal       func()
}

var (
	traceSterliser   *regexp.Regexp = regexp.MustCompile("0[xX][0-9a-fA-F]+|goroutine [0-9]+")
	traceSelfRemover *regexp.Regexp = regexp.MustCompile(regexp.QuoteMeta(reflect.TypeFor[DiscordLogger]().PkgPath()) + ".+[\n\r]+.+[\n\r]+")
)

const (
	LevelDebug = iota - 1
	LevelInfo
	LevelWarn
	LevelError
	LevelFatal
	LevelPanic
	LevelNone
)

func (l *DiscordLogger) out(level int, msg string, args []any) uint32 {
	short := fmt.Sprintf(msg, args...)
	long := short

	// short outputs
	var label string
	switch level {
	case LevelPanic:
		label = "PNC"
	case LevelFatal:
		label = "FTL"
	case LevelError:
		label = "ERR"
	case LevelWarn:
		label = "WRN"
	case LevelInfo:
		label = "INF"
	case LevelDebug:
		label = "DBG"
	}
	if level >= l.FileLogLevel {
		// add traceback
		long += "\n\n" + string(debug.Stack())

		// generate id
		hasher := sha1.New()
		hasher.Write(traceSterliser.ReplaceAll([]byte(long), []byte("")))
		id := binary.BigEndian.Uint32(hasher.Sum(nil))

		idStr := hex.EncodeToString(binary.BigEndian.AppendUint32(nil, id))

		if level >= l.PrintLogLevel {
			fmt.Printf("[%s] (%s) %s\n", label, idStr, short)
		}

		if level >= l.WebLogLevel {
			l.Webhook.Execute(webhook.ExecuteData{
				Content: fmt.Sprintf("`%s` %s", idStr, short),
			})
		}

		// create log file
		file, err := os.OpenFile(filepath.Join(l.Directory, idStr+".log"), os.O_CREATE|os.O_WRONLY, logPerms)
		if err != nil {
			return 0
		}
		defer file.Close()
		_, err = file.Write(traceSelfRemover.ReplaceAll([]byte(long), []byte("")))
		if err != nil {
			return 0
		}

		return id
	}

	if level >= l.PrintLogLevel {
		fmt.Printf("[%s] %s\n", label, short)
	}

	if level >= l.WebLogLevel {
		l.Webhook.Execute(webhook.ExecuteData{
			Content: short,
		})
	}

	return 0
}

func (l *DiscordLogger) Dump(r io.Reader, level int, msg string, args ...any) uint32 {
	id := l.out(level, msg, args)

	file, err := os.OpenFile(filepath.Join(l.Directory, hex.EncodeToString(binary.BigEndian.AppendUint32(nil, id))+".dmp"), os.O_CREATE|os.O_WRONLY, 0777)
	if err != nil {
		return 0
	}
	_, err = io.Copy(file, r)
	if err != nil {
		return 0
	}
	file.Close()
	return id
}

func (l *DiscordLogger) DumpResponse(resp *http.Response, body bool, level int, msg string, args ...any) (uint32, error) {
	b, err := httputil.DumpResponse(resp, body)
	if err != nil {
		return 0, err
	}
	return l.Dump(bytes.NewReader(b), level, msg, args...), nil
}

func (l *DiscordLogger) Fatal(msg string, args ...any) {
	l.out(LevelFatal, msg, args)
	l.OnFatal()
}

func (l *DiscordLogger) FatalQuick(err error) {
	l.Fatal("%s", err)
}

func (l *DiscordLogger) Error(msg string, args ...any) uint32 {
	return l.out(LevelError, msg, args)
}

func (l *DiscordLogger) ErrorQuick(err error) uint32 {
	return l.Error("%s", err)
}

func (l *DiscordLogger) Warn(msg string, args ...any) uint32 {
	return l.out(LevelWarn, msg, args)
}

func (l *DiscordLogger) Info(msg string, args ...any) uint32 {
	return l.out(LevelInfo, msg, args)
}

func (l *DiscordLogger) Debug(msg string, args ...any) uint32 {
	return l.out(LevelDebug, msg, args)
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
	idStr := hex.EncodeToString(binary.BigEndian.AppendUint32(nil, id))

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

func (l *DiscordLogger) CatchCrash() error {
	// emit last log
	fp := filepath.Join(l.Directory, "crash.log")
	b, err := os.ReadFile(fp)
	if !errors.Is(err, os.ErrNotExist) && err != nil {
		return err
	}
	os.Remove(fp)

	if len(b) > 0 {
		short := string(b[:bytes.IndexByte(b, '\n')])
		if LevelPanic >= l.FileLogLevel {
			hasher := sha1.New()
			hasher.Write(traceSterliser.ReplaceAll(b, []byte("")))
			idStr := hex.EncodeToString(hasher.Sum(nil)[:4])
			os.WriteFile(filepath.Join(l.Directory, idStr+".log"), b, logPerms)

			if LevelPanic >= l.WebLogLevel {
				l.Webhook.Execute(webhook.ExecuteData{
					Content: fmt.Sprintf("`%s` %s", idStr, short),
				})
			}
		} else {
			if LevelPanic >= l.WebLogLevel {
				l.Webhook.Execute(webhook.ExecuteData{
					Content: short,
				})
			}
		}
	}

	// setup new logger
	fd, err := os.OpenFile(fp, os.O_WRONLY|os.O_CREATE, logPerms)
	if err != nil {
		return err
	}
	return debug.SetCrashOutput(fd, debug.CrashOptions{})
}
