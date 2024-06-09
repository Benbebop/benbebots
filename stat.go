package main

import (
	"encoding/binary"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
	"github.com/syndtr/goleveldb/leveldb"
)

type Stat struct {
	Name      string
	Value     int64
	Client    *api.Client
	ChannelID discord.ChannelID
	Delay     time.Duration
	LevelDB   *leveldb.DB
	mutex     sync.Mutex
}

func getKey(name string) []byte {
	return []byte("stat" + strings.ReplaceAll(name, " ", ""))
}

func (S *Stat) Initialise() error {
	oldName, newName := []byte("STAT_"+S.Name), getKey(S.Name)
	hasOld, err := S.LevelDB.Has(oldName, nil)
	if err != nil {
		return err
	} else if hasOld {
		val, err := S.LevelDB.Get(oldName, nil)
		if err != nil {
			return err
		}
		num, err := strconv.ParseInt(string(val), 10, 64)
		if err != nil {
			return err
		}
		S.Value = num
		err = S.LevelDB.Put(newName, binary.AppendVarint(nil, num), nil)
		if err != nil {
			return err
		}
		err = S.LevelDB.Delete(oldName, nil)
		if err != nil {
			return err
		}
	} else {
		val, err := S.LevelDB.Get(newName, nil)
		if err != nil {
			return err
		}
		num, _ := binary.Varint(val)
		S.Value = num
	}
	return nil
}

func (S *Stat) sync(value int64) error {
	err := S.LevelDB.Put([]byte(getKey(S.Name)), binary.AppendVarint(nil, value), nil)
	if err != nil {
		return err
	}

	err = S.Client.ModifyChannel(S.ChannelID, api.ModifyChannelData{
		Name: S.Name + " : " + strconv.FormatInt(value, 10),
	})
	if err != nil {
		return err
	}
	return nil
}

func (S *Stat) Update() {
	if !S.mutex.TryLock() {
		return
	}
	go func() {
		defer S.mutex.Unlock()
		after := S.Value
		for {
			before := after
			err := S.sync(before)
			if err != nil {
				log.Println(err)
				return
			}
			time.Sleep(S.Delay)
			after = S.Value
			if before == after {
				break
			}
		}
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
