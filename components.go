package main

import "gopkg.in/ini.v1"

type Components struct {
	enabled map[string]bool
}

func (c *Components) Init(sec *ini.Section) error {
	c.enabled = map[string]bool{}
	for _, key := range sec.Keys() {
		value, err := key.Bool()
		if err != nil {
			return err
		}

		c.enabled[key.Name()] = value
	}
	return nil
}

func (c *Components) IsEnabled(name string) bool {
	for n, e := range c.enabled {
		if n == name {
			return e
		}
	}
	return true
}
