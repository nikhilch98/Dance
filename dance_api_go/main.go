package main

import (
	"log"
	"net/http"
	"os"

	"dance_api_go/src/api"
	"dance_api_go/src/config"
)

func main() {
	// Initialize logger
	if err := config.InitLogger(); err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}

	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Printf("Warning: Failed to load config: %v", err)
	}

	// Initialize database connection
	if err := config.InitDB(); err != nil {
		log.Printf("Warning: Failed to connect to MongoDB: %v", err)
	}

	// Setup router
	handler := api.SetupRouter()

	// Get port from environment or config
	port := os.Getenv("PORT")
	if port == "" {
		port = cfg.Port
	}

	// Start server
	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}
