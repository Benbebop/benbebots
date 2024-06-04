package main

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/google/go-querystring/query"
	"github.com/syndtr/goleveldb/leveldb"
	"golang.org/x/net/html"
)

type SoundcloudClient struct {
	ClientId   string
	LevelDB    *leveldb.DB
	Cookie     string
	MaxRetries uint
}

func (S *SoundcloudClient) GetClientId() error {
	resp, err := http.Get("https://soundcloud.com/")
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	tokenizer := html.NewTokenizer(resp.Body)
	for {
		if tokenizer.Next() == html.ErrorToken {
			break
		}

		token := tokenizer.Token()
		if token.Type != html.StartTagToken && token.Data != "script" {
			continue
		}

		var url string
		valid := false
		for _, v := range token.Attr {
			if v.Key == "crossorigin" {
				valid = true
			} else if v.Key == "src" {
				url = v.Val
			}
		}

		if !valid || url == "" {
			continue
		}

		resp, err := http.Get(url)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		prog := 0
		data := make([]byte, 2048)
		for {
			n, err := resp.Body.Read(data)

			for _, c := range data[:n] {
				if prog >= 10 {
					if c == '"' || c == '\'' {
						prog = -1
						break
					}
					S.ClientId += string(c)
					continue
				}

				if c == ("client_id=")[prog] {
					prog += 1
				} else if c != ' ' {
					prog = 0
				}
			}
			if prog < 0 {
				break
			}
			if err == io.EOF {
				break
			}
		}

		if S.ClientId != "" {
			break
		}
	}

	S.LevelDB.Put([]byte("soundcloudClientId"), []byte(S.ClientId), nil)

	return nil
}

func (S *SoundcloudClient) req(depth uint, method string, endpoint string, values url.Values, body string) (*http.Response, error) {
	values.Set("client_id", S.ClientId)
	resp, err := http.Get(fmt.Sprintf("https://api-v2.soundcloud.com/%s?%s", endpoint, values.Encode()))
	if err != nil {
		return nil, err
	}

	if resp.StatusCode == 401 {
		resp.Body.Close()
		if depth++; depth > S.MaxRetries {
			return nil, errors.New("too many retries")
		}
		err = S.GetClientId()
		if err != nil {
			return nil, err
		}
		return S.req(depth, method, endpoint, values, body)
	}
	return resp, nil
}

func (S *SoundcloudClient) Request(method string, endpoint string, qry interface{}, body string) (*http.Response, error) {
	values, err := query.Values(qry)
	if err != nil {
		return nil, err
	}
	return S.req(0, method, endpoint, values, body)
}
