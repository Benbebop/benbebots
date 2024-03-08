package logger

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Logger struct {
	Directory string
	Webhook   string
}

var randomMask uint64 = 0xFFFFF00000000000

func (l Logger) Error(inErr error) string {
	os.Mkdir(l.Directory, 0777)
	id := strings.ToUpper(strconv.FormatUint((uint64(time.Now().UnixMilli()) & ^randomMask)|(rand.Uint64()&randomMask), 36))

	// create log file
	file, err := os.OpenFile(fmt.Sprintf("%s%s.log", l.Directory, id), os.O_CREATE|os.O_WRONLY, 0777)
	if err != nil {
		return ""
	}
	_, err = file.Write([]byte(inErr.Error() + "\n\n"))
	if err != nil {
		return ""
	}
	b := make([]byte, 2048)
	n := runtime.Stack(b, false)
	_, err = file.Write(b[:n])
	if err != nil {
		return ""
	}
	file.Close()

	// log to stdout
	log.Println(fmt.Sprintf("%s: %s", id, inErr.Error()))

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

func (l Logger) Assert(inErr error) (bool, string) {
	if inErr != nil {
		return true, l.Error(inErr)
	}
	return false, ""
}

// i dont like this but i cant think of anything better
func (l Logger) Assert2(_ any, inErr error) (bool, string) {
	return l.Assert(inErr)
}