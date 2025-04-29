package config

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"
)

// multiWriter writes to multiple writers
type multiWriter struct {
	writers []io.Writer
}

func (t *multiWriter) Write(p []byte) (n int, err error) {
	for _, w := range t.writers {
		n, err = w.Write(p)
		if err != nil {
			return
		}
	}
	return len(p), nil
}

// InitLogger sets up the logger configuration
func InitLogger() error {
	// Create logs directory if it doesn't exist
	err := os.MkdirAll("logs", 0755)
	if err != nil {
		return fmt.Errorf("failed to create logs directory: %v", err)
	}

	// Create or append to the log file with current date
	currentTime := time.Now()
	logFileName := filepath.Join("logs", fmt.Sprintf("%s.log", currentTime.Format("2006-01-02")))

	logFile, err := os.OpenFile(logFileName, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open log file: %v", err)
	}

	// Create a writer that writes to both stdout and the log file
	writer := &multiWriter{
		writers: []io.Writer{
			os.Stdout,
			logFile,
		},
	}

	// Set custom log format with timestamp
	log.SetFlags(0) // Remove default timestamp
	log.SetOutput(writer)

	// Log startup message
	log.Printf("Logging initialized. Writing to console and %s", logFileName)
	return nil
}
