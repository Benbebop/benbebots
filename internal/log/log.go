package log

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

const (
	LevelDebug = iota - 1
	LevelInfo
	LevelWarn
	LevelError
	LevelFatal
	LevelPanic
	levelLogger
	LevelNone
)

var (
	FileLogLevel  int
	PrintLogLevel int
	WebLogLevel   int
	Directory     string
	Webhook       *webhook.Client
	OnFatal       func()
)

type pkgPathSubject struct{}

var (
	traceSterliser   *regexp.Regexp = regexp.MustCompile("0[xX][0-9a-fA-F]+|goroutine [0-9]+")
	traceSelfRemover *regexp.Regexp = regexp.MustCompile(regexp.QuoteMeta(reflect.TypeFor[pkgPathSubject]().PkgPath()) + ".+[\n\r]+.+[\n\r]+")
)

func out(level int, short string) uint32 {
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
	case levelLogger:
		fmt.Printf("[LGR] %s\n", long)
		return 0
	}
	if level >= FileLogLevel {
		// add traceback
		long += "\n\n" + string(debug.Stack())

		// generate id
		hasher := sha1.New()
		_, err := hasher.Write(traceSterliser.ReplaceAll([]byte(long), []byte("")))
		if err != nil {
			internalError(err)
		}
		id := binary.BigEndian.Uint32(hasher.Sum(nil))

		idStr := hex.EncodeToString(binary.BigEndian.AppendUint32(nil, id))

		if level >= PrintLogLevel {
			fmt.Printf("[%s] (%s) %s\n", label, idStr, short)
		}

		if level >= WebLogLevel {
			err := Webhook.Execute(webhook.ExecuteData{
				Content: fmt.Sprintf("`%s` %s", idStr, short),
			})
			if err != nil {
				internalError(err)
			}
		}

		// create log file
		file, err := os.OpenFile(filepath.Join(Directory, idStr+".log"), os.O_CREATE|os.O_WRONLY, logPerms)
		if err != nil {
			internalError(err)
			return 0
		}
		defer file.Close()
		_, err = file.Write(traceSelfRemover.ReplaceAll([]byte(long), []byte("")))
		if err != nil {
			internalError(err)
			return 0
		}

		return id
	}

	if level >= PrintLogLevel {
		fmt.Printf("[%s] %s\n", label, short)
	}

	if level >= WebLogLevel {
		err := Webhook.Execute(webhook.ExecuteData{
			Content: short,
		})
		if err != nil {
			internalError(err)
		}
	}

	return 0
}

func Dump(r io.Reader, level int, msg string, args ...any) uint32 {
	id := out(level, fmt.Sprintf(msg, args...))

	file, err := os.OpenFile(filepath.Join(Directory, hex.EncodeToString(binary.BigEndian.AppendUint32(nil, id))+".dmp"), os.O_CREATE|os.O_WRONLY, 0777)
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

func DumpResponse(resp *http.Response, body bool, level int, msg string, args ...any) (uint32, error) {
	b, err := httputil.DumpResponse(resp, body)
	if err != nil {
		return 0, err
	}
	return Dump(bytes.NewReader(b), level, msg, args...), nil
}

func internalError(err error) {
	out(levelLogger, err.Error())
}

func Stop() {
	out(LevelFatal, "Stop Called")
	OnFatal()
}

func Fatal(msg string, args ...any) {
	out(LevelFatal, fmt.Sprintf(msg, args...))
	OnFatal()
}

func FatalQuick(err error) {
	out(LevelFatal, err.Error())
	OnFatal()
}

func Error(msg string, args ...any) uint32 {
	return out(LevelError, fmt.Sprintf(msg, args...))
}

func ErrorQuick(err error) uint32 {
	return out(LevelError, err.Error())
}

func Warn(msg string, args ...any) uint32 {
	return out(LevelWarn, fmt.Sprintf(msg, args...))
}

func Info(msg string, args ...any) uint32 {
	return out(LevelInfo, fmt.Sprintf(msg, args...))
}

func Debug(msg string, args ...any) uint32 {
	return out(LevelDebug, fmt.Sprintf(msg, args...))
}

func Assert(returns ...any) (bool, uint32) {
	for _, ret := range returns {
		err, isErr := ret.(error)
		if isErr {
			return true, ErrorQuick(err)
		}
	}

	return false, 0
}

func InteractionResponse(id uint32, title string) *api.InteractionResponseData {
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

func CatchCrash() error {
	// emit last log
	fp := filepath.Join(Directory, "crash.log")
	b, err := os.ReadFile(fp)
	if !errors.Is(err, os.ErrNotExist) && err != nil {
		return err
	}
	os.Remove(fp)

	if len(b) > 0 {
		short := string(b[:bytes.IndexByte(b, '\n')])
		if LevelPanic >= FileLogLevel {
			hasher := sha1.New()
			hasher.Write(traceSterliser.ReplaceAll(b, []byte("")))
			idStr := hex.EncodeToString(hasher.Sum(nil)[:4])
			os.WriteFile(filepath.Join(Directory, idStr+".log"), b, logPerms)

			if LevelPanic >= WebLogLevel {
				Webhook.Execute(webhook.ExecuteData{
					Content: fmt.Sprintf("`%s` %s", idStr, short),
				})
			}
		} else {
			if LevelPanic >= WebLogLevel {
				Webhook.Execute(webhook.ExecuteData{
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
