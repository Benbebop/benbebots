package main

import (
	"log"

	netrc "github.com/fhs/go-netrc/netrc"
	"gopkg.in/ini.v1"
)

var cfg *ini.File

func main() {
	mach, _, err := netrc.ParseFile("tokens.netrc")
	if err != nil {
		log.Fatal(err)
	}

	var tokens [3]string
	for _, e := range mach {
		switch e.Name {
		case "benbebot":
			tokens[0] = e.Password
		case "familyguy":
			tokens[1] = e.Password
		case "gnerb":
			tokens[2] = e.Password
		}
	}

	file, err := ini.LooseLoad("config.ini")
	if err != nil {
		log.Fatal(err)
	}

	cfg = file

	benbebot(tokens[0])
	familyguy(tokens[1])

	gnerb(tokens[2])
	cannedfood()
}
