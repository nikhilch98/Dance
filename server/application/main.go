package main

import (
	"fmt"
	"nachna/api"
	"nachna/config"
	"net/http"
	"sync"

	log "github.com/sirupsen/logrus"
)

func main() {
	wg := new(sync.WaitGroup)
	wg.Add(1)
	log.Info(fmt.Sprintf("Starting http server on port : %d", config.Config.HttpPort))
	server := &http.Server{Addr: fmt.Sprintf(":%d", config.Config.HttpPort), Handler: api.Router}
	go func() {
		err := server.ListenAndServe()
		if err != nil {
			log.Error("closing http server due to error ", err)
		}
		wg.Done()
	}()
	wg.Wait()
}
