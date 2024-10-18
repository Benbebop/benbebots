package scheduler

import "time"

const minTime = time.Minute * 30
const day = time.Hour * 24

func TimeToDaily(t time.Duration) time.Duration {
	wait := time.Until(time.Now().Add(-t).Add(day).Truncate(day).Add(t))
	if wait <= minTime {
		return minTime
	}
	return wait
}
