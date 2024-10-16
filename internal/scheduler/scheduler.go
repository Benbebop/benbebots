package scheduler

import "time"

const minTime = time.Second * 5

func TimeToDaily(t time.Duration) time.Duration {
	wait := time.Until(time.Now().Add(-t).Round(time.Hour * 24).Add(t))
	if wait <= minTime {
		return minTime
	}
	return wait
}
