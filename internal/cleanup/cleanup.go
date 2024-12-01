package cleanup

import (
	"errors"
	"io"
	"sync"
)

type Cleaner struct {
	mut     sync.Mutex
	toClose []io.Closer
}

func (c *Cleaner) Add(addend io.Closer) {
	c.mut.Lock()
	defer c.mut.Unlock()
	c.toClose = append(c.toClose, addend)
}

func (c *Cleaner) Clean() []error {
	c.mut.Lock()
	defer c.mut.Unlock()
	errs := []error{}
	for _, v := range c.toClose {
		err := v.Close()
		if err != nil {
			errs = append(errs, err)
		}
	}
	return errs
}

func (c *Cleaner) Close() error {
	return errors.Join(c.Clean()...)
}
