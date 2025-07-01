package handler

import (
	"github.com/gorilla/mux"
)

func SetupRouter() *mux.Router {
	// API routes

	router := mux.NewRouter()

	api := router.PathPrefix("/api").Subrouter()
	
	// Health check
	api.HandleFunc("/health_check", HealthCheckHandler).Methods("GET")

	return router
} 