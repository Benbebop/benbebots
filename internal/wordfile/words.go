package wordfile

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"os"
)

var sizeOfInt = int64(len(binary.BigEndian.AppendUint32(nil, 0)))

var signature = []byte(fmt.Sprintf("WORDFILE%d", sizeOfInt*8))

func NewWordWriter(file string) (*WordWriter, error) {
	f, err := os.OpenFile(file, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0700)
	if err != nil {
		return nil, err
	}
	_, err = f.Write(signature)
	if err != nil {
		return nil, err
	}
	_, err = f.Write(binary.BigEndian.AppendUint32(nil, 0))
	if err != nil {
		return nil, err
	}
	return &WordWriter{
		file: f,
	}, nil
}

type WordWriter struct {
	file  *os.File
	index []int64
}

func (w *WordWriter) Add(word string) error {
	loc, err := w.file.Seek(0, io.SeekCurrent)
	if err != nil {
		return err
	}
	w.index = append(w.index, loc)
	_, err = w.file.Write([]byte(word))
	return err
}

func (w *WordWriter) Close() error {
	end, err := w.file.Seek(0, io.SeekCurrent)
	if err != nil {
		return err
	}
	newend := (end/sizeOfInt + 1) * sizeOfInt
	_, err = w.file.Write(bytes.Repeat([]byte{0x00}, int(newend-end)))
	if err != nil {
		return err
	}
	_, err = w.file.WriteAt(binary.BigEndian.AppendUint32(nil, uint32(newend)), int64(len(signature)))
	if err != nil {
		return err
	}
	for _, v := range w.index {
		_, err = w.file.Write(binary.BigEndian.AppendUint32(nil, uint32(v)))
		if err != nil {
			return err
		}
	}
	return w.file.Close()
}

var ErrSigIncorrect = errors.New("file signature is incorrect")

func NewWordReader(file string) (*WordReader, error) {
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	sig := signature
	_, err = f.Read(sig)
	if err != nil {
		return nil, ErrSigIncorrect
	}
	if !bytes.Equal(sig, signature) {
		return nil, err
	}
	b := make([]byte, sizeOfInt)
	_, err = f.Read(b)
	if err != nil {
		return nil, err
	}
	start := binary.BigEndian.Uint32(b)
	s, err := f.Stat()
	if err != nil {
		return nil, err
	}
	return &WordReader{
		file:  f,
		start: int64(start),
		size:  s.Size() - int64(start),
	}, nil
}

type WordReader struct {
	file  *os.File
	start int64
	size  int64
}

func (w WordReader) Length() int {
	return int(w.size / sizeOfInt)
}

func (w WordReader) Get(index int) ([]byte, error) {
	b := make([]byte, sizeOfInt)
	_, err := w.file.ReadAt(b, w.start+int64(index)*sizeOfInt)
	if err != nil {
		return nil, err
	}
	start := binary.BigEndian.Uint32(b)
	_, err = w.file.ReadAt(b, w.start+int64(index+1)*sizeOfInt)
	if err != nil {
		return nil, err
	}
	word := make([]byte, binary.BigEndian.Uint32(b)-start)
	_, err = w.file.ReadAt(word, int64(start))
	if err != nil {
		return nil, err
	}
	return word, nil
}

func (w WordReader) Close() error {
	return w.file.Close()
}
