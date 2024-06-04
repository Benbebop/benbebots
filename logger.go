package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"runtime"
)

type Logger struct {
	Directory string
	Webhook   string
}

var traceSterliser *regexp.Regexp = regexp.MustCompile("0[xX][0-9a-fA-F]+|goroutine [0-9]+")

func (l *Logger) output(mode string, str string) {
	os.Mkdir(l.Directory, 0777)
	var output string

	// add error
	output += str

	// add traceback
	trc := make([]byte, 2048)
	n := runtime.Stack(trc, false)
	output += "\n\n" + string(trc[:n])

	// generate id
	hasher := sha1.New()
	hasher.Write(traceSterliser.ReplaceAll([]byte(output), []byte("")))
	id := base64.URLEncoding.EncodeToString(hasher.Sum(nil))
	id = id[:12]

	// create log file
	file, err := os.OpenFile(fmt.Sprintf("%s%s.log", l.Directory, id), os.O_CREATE|os.O_WRONLY, 0777)
	if err != nil {
		return
	}
	_, err = file.Write([]byte(output))
	if err != nil {
		return
	}
	file.Close()

	// log to stdout
	log.Printf("%s: %s", id, str)

	// send log to discord server
	data, err := json.Marshal(struct {
		Content string `json:"content"`
	}{
		Content: fmt.Sprintf("%s `%s`: %s", mode, id, str),
	})
	if err != nil {
		return
	}
	req, err := http.NewRequest(http.MethodPost, l.Webhook, bytes.NewReader(data))
	if err != nil {
		return
	}
	req.Header.Add("Content-Type", "application/json")
	http.DefaultClient.Do(req)
}

func (l *Logger) Debug(msg string, args ...any) {
	log.Printf(msg, args...)
}

func (l *Logger) Error(msg string, args ...any) {
	l.output("error", fmt.Sprintf(msg, args...))
}

func (l *Logger) Info(msg string, args ...any) {
	log.Printf(msg, args...)
}

func (l *Logger) Warn(msg string, args ...any) {
	l.output("warning", fmt.Sprintf(msg, args...))
}

func (l *Logger) Assert(inErr error, _ ...any) (bool, error) {
	if inErr != nil {
		l.Error(inErr.Error())
		return true, inErr
	}
	return false, inErr
}

// i dont like this but i cant think of anything better
func (l *Logger) Assert2(_ any, inErr error, _ ...any) (bool, error) {
	return l.Assert(inErr)
}
