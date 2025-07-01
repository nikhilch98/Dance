package handler

import (
	"encoding/json"
	"net/http"
	"time"
)

type HealthResponse struct {
	Success   bool   `json:"success"`
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
	Version   string `json:"version"`
	Service   string `json:"service"`
}

func HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Success:   true,
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   "1.0.0",
		Service:   "nachna-server",
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache")
	w.WriteHeader(http.StatusOK)
	
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
}