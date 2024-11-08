package log

type SLogCompat struct{}

func (l *SLogCompat) Debug(msg string, args ...any) {
	Debug(msg, args...)
}

func (l *SLogCompat) Error(msg string, args ...any) {
	Error(msg, args...)
}

func (l *SLogCompat) Info(msg string, args ...any) {
	Info(msg, args...)
}

func (l *SLogCompat) Warn(msg string, args ...any) {
	Warn(msg, args...)
}
