package main

import (
	"fmt"
	"nachna/api"
	"nachna/config"
	"nachna/core"
	"nachna/models/request"
	"net/http"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

func backgroundTasks(wg *sync.WaitGroup) {
	// Run the background task in a goroutine and signal completion via WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			err := refreshWorkshopsBackground()
			if err != nil {
				log.Errorf("Error refreshing workshops in background: %v", err)
			}
			log.Info("Refreshed workshops in background")
			select {
			case <-time.After(6 * time.Hour):
				continue
			}
		}
	}()
}

func refreshWorkshopsBackground() *core.NachnaException {
	studioIDs := []string{
		"manifestbytmn",
		"vins.dance.co",
		"dance_n_addiction",
		"dance.inn.bangalore",
	}
	adminService, err := api.GetAdminService()
	if err != nil {
		return err
	}
	for _, studioID := range studioIDs {
		_, err = adminService.RefreshWorkshops(&request.AdminWorkshopRequest{
			StudioId: studioID,
		})
		if err != nil {
			log.Errorf("Failed to refresh workshops for studio %s: %v", studioID, err)
			// Continue to next studio instead of returning immediately
			continue
		}
	}
	return nil
}

func main() {
	wg := new(sync.WaitGroup)
	backgroundTasks(wg)
	serverWg := new(sync.WaitGroup)
	serverWg.Add(1)
	log.Info(fmt.Sprintf("Starting http server on port : %d", config.Config.HttpPort))
	server := &http.Server{Addr: fmt.Sprintf(":%d", config.Config.HttpPort), Handler: api.Router}
	go func() {
		err := server.ListenAndServe()
		if err != nil {
			log.Error("closing http server due to error ", err)
		}
		serverWg.Done()
	}()
	serverWg.Wait()
}
