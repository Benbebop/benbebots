package heartbeat

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	"benbebop.net/benbebots/internal/log"
	"github.com/diamondburned/arikawa/v3/gateway"
)

type Heartbeater struct {
	sync.Mutex
	Filepath string
	Webhook  string
	interval time.Duration
}

func (h *Heartbeater) Output(str string) {
	data, err := json.Marshal(struct {
		Content string `json:"content"`
	}{
		Content: str,
	})
	if err != nil {
		return
	}
	http.Post(h.Webhook, "application/json", bytes.NewReader(data))
}

func (h *Heartbeater) Init(hello *gateway.HelloEvent) {
	h.interval = hello.HeartbeatInterval.Duration() + 20*time.Second
	h.Heartbeat(nil)
}

func (h *Heartbeater) Heartbeat(*gateway.HeartbeatAckEvent) {
	h.Lock()
	timestamp := time.Now()
	bytes, err := os.ReadFile(h.Filepath)
	if err == nil {
		out := timestamp.Sub(time.UnixMilli(int64(binary.LittleEndian.Uint64(bytes))))
		if out > h.interval {
			h.Output(fmt.Sprintf("back online, out for %dm.", int(out.Minutes())))
		}
	} else {
		h.Output("back online.")
	}
	bytes = make([]byte, 8)
	binary.LittleEndian.PutUint64(bytes, uint64(timestamp.UnixMilli()))
	err = os.WriteFile(h.Filepath, bytes, 0777)
	if err != nil {
		log.ErrorQuick(err)
	}
	h.Unlock()
}
