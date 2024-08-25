package pubsubhubbub

import (
	"errors"
	"io"
	"net/http"
	"reflect"
	"strconv"
	"sync"
	"time"

	"github.com/google/go-querystring/query"
)

const (
	ModeSubscribe   = "subscribe"
	ModeUnsubscribe = "unsubscribe"
	ModeDenied      = "denied"
)

var (
	ErrErrored = errors.New("request errored")
	ErrDenied  = errors.New("request was denied")
	ErrTimeout = errors.New("validation timed out")
)

type SubscriptionValidation struct {
	Mode         string `url:"hub.mode"`
	Topic        string `url:"hub.topic"`
	Challenge    string `url:"hub.challenge,omitempty"`
	LeaseSeconds uint   `url:"hub.lease_seconds,omitempty"`
	Reason       string `url:"hub.reason,omitempty"`
}

type SubscriptionRequest struct {
	Callback string `url:"hub.callback"`
	Mode     string `url:"hub.mode"`
	Topic    string `url:"hub.topic"`
	Lease    uint   `url:"hub.lease_seconds,omitempty"`
	Secret   string `url:"hub.secret,omitempty"`
}

type SubscriptionError struct {
	Reason string
	Error  error
}

func NewClient(hub string) *Client {
	return &Client{
		hub:     hub,
		Timeout: time.Second * 5,
	}
}

type Client struct {
	hub   string
	queue struct {
		sync.Mutex
		q []func(SubscriptionValidation) bool
	}
	Timeout time.Duration
	Handler http.HandlerFunc
}

// send a subscription request to the hub and wait for validation
func (c *Client) Subscribe(data interface{}) SubscriptionError {
	form, err := query.Values(data)
	if err != nil {
		return SubscriptionError{
			Error: err,
		}
	}

	resp, err := http.PostForm(c.hub, form)
	if err != nil {
		return SubscriptionError{
			Error: err,
		}
	}
	if resp.StatusCode >= 400 {
		errorData, err := io.ReadAll(resp.Body)
		if err != nil {
			return SubscriptionError{
				Error: err,
			}
		}
		return SubscriptionError{
			Reason: string(errorData),
			Error:  ErrErrored,
		}
	}

	// there is probably a better way to do this but i dont know it, yet
	channel := make(chan SubscriptionError)
	c.queue.Lock()
	index := len(c.queue.q)
	c.queue.q = append(c.queue.q, func(val SubscriptionValidation) bool {
		if val.Topic == reflect.ValueOf(data).FieldByName("Topic").String() { // fix this ig
			if val.Mode == ModeDenied {
				channel <- SubscriptionError{
					Reason: val.Reason,
					Error:  ErrDenied,
				}
			} else {
				channel <- SubscriptionError{}
			}
			return true
		}
		return false
	})
	timeout := time.AfterFunc(c.Timeout, func() {
		channel <- SubscriptionError{
			Error: ErrTimeout,
		}
	})
	c.queue.Unlock()
	serr := <-channel
	timeout.Stop()
	c.queue.Lock()
	c.queue.q = append(c.queue.q[:index], c.queue.q[index+1:]...)
	c.queue.Unlock()
	if serr.Error != nil {
		return serr
	}

	return SubscriptionError{}
}

func (c *Client) Handle(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		vals := r.URL.Query()
		var validate SubscriptionValidation
		validate.Mode = vals.Get("hub.mode")
		validate.Topic = vals.Get("hub.topic")
		validate.Challenge = vals.Get("hub.challenge")
		i, err := strconv.ParseUint(vals.Get("hub.lease_seconds"), 10, 64)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(err.Error()))
		}
		validate.LeaseSeconds = uint(i)
		validate.Reason = vals.Get("hub.reason")
		var success bool
		c.queue.Lock()
		for _, f := range c.queue.q {
			success = f(validate)
			if success {
				break
			}
		}
		c.queue.Unlock()
		if !success {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(validate.Challenge))
		return
	case http.MethodPost:
		c.Handler(w, r)
		return
	default:
		w.Header().Add("Allow", http.MethodGet+", "+http.MethodPost)
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
}
