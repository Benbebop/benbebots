package platform

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
)

func mkDirIfNotExists(path string) error {
	if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
		return os.MkdirAll(path, fs.FileMode(0777))
	} else if err != nil {
		return err
	}
	return nil
}

func GetTempDir(perm fs.FileMode) (string, error) {
	dir := os.TempDir()
	dir = filepath.Join(dir, "benbebots")
	return dir, mkDirIfNotExists(dir)
}

func GetDataDir(perm fs.FileMode) (string, error) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	dir = filepath.Join(dir, "benbebots")
	return dir, mkDirIfNotExists(dir)
}
