package platform

import (
	"io/fs"
)

const rtDir = "/run/benbebots/"

func GetRuntimeDir(perm fs.FileMode) (string, error) {
	return rtDir, mkDirIfNotExists(rtDir)
}
