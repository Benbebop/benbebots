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

func (l *Logger) Error(inErr error) string {
	os.Mkdir(l.Directory, 0777)
	var output string

	// add error
	output += inErr.Error()

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
		return ""
	}
	_, err = file.Write([]byte(output))
	if err != nil {
		return ""
	}
	file.Close()

	// log to stdout
	log.Printf("%s: %s", id, inErr.Error())

	// send log to discord server
	data, err := json.Marshal(struct {
		Content string `json:"content"`
	}{
		Content: fmt.Sprintf("error `%s`: %s", id, inErr.Error()),
	})
	if err != nil {
		return id
	}
	req, err := http.NewRequest(http.MethodPost, l.Webhook, bytes.NewReader(data))
	if err != nil {
		return id
	}
	req.Header.Add("Content-Type", "application/json")
	http.DefaultClient.Do(req)
	return id
}

func (l *Logger) Assert(inErr error) (bool, string, error) {
	if inErr != nil {
		return true, l.Error(inErr), inErr
	}
	return false, "", inErr
}

// i dont like this but i cant think of anything better
func (l *Logger) Assert2(_ any, inErr error) (bool, string, error) {
	return l.Assert(inErr)
}
