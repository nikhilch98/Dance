package main

import (
	"fmt"
	"nachna/api"
	"nachna/config"
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/service/order"
	"net/http"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

func backgroundTasks(wg *sync.WaitGroup) {
	// QR Code generation background task
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			err := processQRGeneration()
			if err != nil {
				log.Errorf("Error processing QR generation in background: %v", err)
			}
			log.Info("Processed QR generation in background")
			time.Sleep(10 * time.Minute) // Run every 10 minutes
		}
	}()

	// Uncomment below for workshop refresh background task
	// wg.Add(1)
	// go func() {
	// 	defer wg.Done()
	// 	for {
	// 		err := refreshWorkshopsBackground()
	// 		if err != nil {
	// 			log.Errorf("Error refreshing workshops in background: %v", err)
	// 		}
	// 		log.Info("Refreshed workshops in background")
	// 		select {
	// 		case <-time.After(6 * time.Hour):
	// 			continue
	// 		}
	// 	}
	// }()
}

func refreshWorkshopsBackground() *core.NachnaException {
	studioIDs := []string{
		"manifestbytmn",
		"vins.dance.co",
		"dance_n_addiction",
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

func processQRGeneration() *core.NachnaException {
	// Get database instance
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return err
	}

	// Get order service instance
	orderService := order.OrderServiceImpl{}.GetInstance(databaseImpl)

	// Process orders without QR codes
	err = orderService.ProcessOrdersWithoutQR()
	if err != nil {
		return err
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
