package main

import (
	"os"
	"os/signal"
	"syscall"

	benbebots "benbebop.net/benbebots/bots"
	"benbebop.net/benbebots/internal/log"
	"gopkg.in/gographics/imagick.v2/imagick"
)

func main() {
	benbebots.InitConfig()
	benbebots.InitDirs()
	benbebots.InitLogger()
	benbebots.InitPrograms()
	benbebots.InitHeartbeater()
	benbebots.InitCron()
	benbebots.InitTokens()
	benbebots.InitLeveldb()
	benbebots.InitHttp()
	imagick.Initialize()

	exit := make(chan os.Signal, 1)

	log.OnFatal = func() {
		exit <- syscall.SIGABRT
		select {}
	}

	ran := benbebots.RunCommandLine()
	if ran {
		return
	}

	go benbebots.Run()

	signal.Notify(exit, os.Interrupt, syscall.SIGTERM)

	sig := <-exit
	var code int
	switch sig {
	case syscall.SIGABRT:
		code = 1
	default:
		code = 0
		log.Info("interrupt recieved, closing")
	}

	imagick.Terminate()
	code = max(code, benbebots.Close())
	os.Exit(code)
}
