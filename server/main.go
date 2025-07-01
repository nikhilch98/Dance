package main

import (
	"server/handler"
	"net/http"
	"fmt"
	"time"
	"os"
	"os/signal"
	"context"
	"syscall"
)

func main() {
	// Load environment variables
	router := handler.SetupRouter()
	server := &http.Server{
		Addr:         ":8008",
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	// Start server in a goroutine
	go func() {
		fmt.Println("Server starting on port 8008")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Println("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	fmt.Println("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		fmt.Println("Server forced to shutdown: %v", err)
	}

	fmt.Println("Server exited")
}