package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/diamondburned/arikawa/v3/gateway"
)

type Heartbeater struct {
	Filepath string
	Webhook  string
	interval time.Duration
	mut      sync.Mutex
}

func (h *Heartbeater) output(str string) {
	log.Println(str)
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
	h.mut.Lock()
	timestamp := time.Now()
	bytes, err := os.ReadFile(h.Filepath)
	if err == nil {
		out := timestamp.Sub(time.UnixMilli(int64(binary.LittleEndian.Uint64(bytes))))
		if out > h.interval {
			h.output(fmt.Sprintf("back online, out for %dm.", int(out.Minutes())))
		}
	} else {
		h.output("back online")
	}
	bytes = make([]byte, 8)
	binary.LittleEndian.PutUint64(bytes, uint64(timestamp.UnixMilli()))
	os.WriteFile(h.Filepath, bytes, 0777)
	h.mut.Unlock()
}
