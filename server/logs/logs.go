package logs

import (
	"github.com/sirupsen/logrus"
	"time"
)

type Fields logrus.Fields

func init() {

	logrus.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339Nano,
	})

}

func LogInfo(fields Fields, message string) {

	logrus.WithFields(logrus.Fields(fields)).Info(message)

}
