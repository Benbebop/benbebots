package main

import (
	"strconv"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
)

type Stat struct {
	Name      string
	Value     int64
	Client    *api.Client
	ChannelID discord.ChannelID
	Delay     time.Duration
	locked    bool
}

func (S *Stat) Initialise() error {
	val, err := ldb.Get([]byte("STAT_"+S.Name), nil)
	if err != nil {
		return err
	}
	num, err := strconv.ParseInt(string(val), 10, 64)
	if err != nil {
		return err
	}
	S.Value = num
	return nil
}

func (S *Stat) sync(value int64) error {
	strVal := strconv.FormatInt(value, 10)
	err := ldb.Put([]byte("STAT_"+S.Name), []byte(strVal), nil)
	if err != nil {
		return err
	}

	err = S.Client.ModifyChannel(S.ChannelID, api.ModifyChannelData{
		Name: S.Name + " : " + strVal,
	})
	if err != nil {
		return err
	}
	return nil
}

func (S *Stat) Update() {
	if S.locked {
		return
	}
	S.locked = true
	go func() {
		before := S.Value
		lgr.Assert(S.sync(before))
		time.Sleep(S.Delay)
		after := S.Value
		if before == after {
			S.locked = false
			return
		}
		lgr.Assert(S.sync(S.Value))
		S.locked = false
	}()
}

func (S *Stat) Increment(count int64) {
	S.Value += count
	S.Update()
}

func (S *Stat) Set(value int64) {
	S.Value = value
	S.Update()
}
