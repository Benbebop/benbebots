package logger

type SLogCompat struct {
	DL *DiscordLogger
}

func (l *SLogCompat) Debug(msg string, args ...any) {
	l.DL.out(-1, msg, args)
}

func (l *SLogCompat) Error(msg string, args ...any) {
	l.DL.out(2, msg, args)
}

func (l *SLogCompat) Info(msg string, args ...any) {
	l.DL.out(0, msg, args)
}

func (l *SLogCompat) Warn(msg string, args ...any) {
	l.DL.out(1, msg, args)
}
