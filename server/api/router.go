package api

import (
	"nachna/config"
	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"
)

var Router = mux.NewRouter().PathPrefix(config.Config.ApiContextPath).Subrouter()

func init() {

	log.Info("Router is initialised")

}
