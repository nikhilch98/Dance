package api

import (
	"context"
	"encoding/json"
	"fmt"
	"nachna/models/request"
	"nachna/models/response"
	"nachna/service"
	"net/http"
	"time"
)

func init() {
	// Register streaming routes directly (not using MakeHandler since these are SSE endpoints)
	Router.HandleFunc("/streaming/refresh-workshops", RefreshWorkshopsStreaming).Methods(http.MethodPost)
	Router.HandleFunc("/streaming/process-studio", ProcessStudioStreaming).Methods(http.MethodGet)
}

// RefreshWorkshopsStreaming handles streaming workshop refresh with real-time updates
func RefreshWorkshopsStreaming(w http.ResponseWriter, r *http.Request) {
	// Set headers for Server-Sent Events
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control")

	// Create a channel for streaming updates
	updateChan := make(chan *response.StreamingResponse, 100)

	// Parse the request
	adminWorkshopRequest := &request.AdminWorkshopRequest{}
	err := adminWorkshopRequest.FromJSON(r.Body)
	if err != nil {
		sendSSEError(w, "Invalid request body")
		return
	}
	defer r.Body.Close()

	// Create context with timeout
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Minute)
	defer cancel()

	// Start the streaming process in a goroutine
	go func() {
		streamingService := service.GetStreamingWorkshopService()
		err := streamingService.RefreshWorkshopsStreaming(ctx, adminWorkshopRequest, updateChan)
		if err != nil {
			// Send error through channel
			updateChan <- response.NewLogResponse(fmt.Sprintf("Error: %v", err), "error")
		}
	}()

	// Stream updates to client
	for {
		select {
		case <-ctx.Done():
			sendSSEMessage(w, "event: close\ndata: {\"message\":\"Connection closed\"}\n\n")
			return
		case <-r.Context().Done():
			// Client disconnected
			return
		case update, ok := <-updateChan:
			if !ok {
				// Channel closed, send completion message
				sendSSEMessage(w, "event: complete\ndata: {\"message\":\"Process completed\"}\n\n")
				return
			}

			// Convert update to JSON
			jsonData, err := update.ToJSON()
			if err != nil {
				sendSSEError(w, "Error serializing update")
				continue
			}

			// Send the update as SSE
			eventType := string(update.Type)
			sendSSEMessage(w, fmt.Sprintf("event: %s\ndata: %s\n\n", eventType, string(jsonData)))

			// Flush the response writer
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
		}
	}
}

// ProcessStudioStreaming handles streaming studio processing with real-time updates
func ProcessStudioStreaming(w http.ResponseWriter, r *http.Request) {
	// Set headers for Server-Sent Events
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Cache-Control")

	// Get studio ID from query parameters
	studioID := r.URL.Query().Get("studio_id")
	if studioID == "" {
		sendSSEError(w, "studio_id parameter is required")
		return
	}

	// Create a channel for streaming updates
	updateChan := make(chan *response.StreamingResponse, 100)

	// Create context with timeout
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Minute)
	defer cancel()

	// Start the streaming process in a goroutine
	go func() {
		streamingService := service.GetStreamingWorkshopService()
		err := streamingService.ProcessStudioWithStreaming(ctx, studioID, updateChan)
		if err != nil {
			// Send error through channel
			updateChan <- response.NewLogResponse(fmt.Sprintf("Error: %v", err), "error")
		}
	}()

	// Stream updates to client
	for {
		select {
		case <-ctx.Done():
			sendSSEMessage(w, "event: close\ndata: {\"message\":\"Connection closed\"}\n\n")
			return
		case <-r.Context().Done():
			// Client disconnected
			return
		case update, ok := <-updateChan:
			if !ok {
				// Channel closed, send completion message
				sendSSEMessage(w, "event: complete\ndata: {\"message\":\"Process completed\"}\n\n")
				return
			}

			// Convert update to JSON
			jsonData, err := update.ToJSON()
			if err != nil {
				sendSSEError(w, "Error serializing update")
				continue
			}

			// Send the update as SSE
			eventType := string(update.Type)
			sendSSEMessage(w, fmt.Sprintf("event: %s\ndata: %s\n\n", eventType, string(jsonData)))

			// Flush the response writer
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
		}
	}
}

// sendSSEMessage sends a Server-Sent Event message
func sendSSEMessage(w http.ResponseWriter, message string) {
	fmt.Fprint(w, message)
}

// sendSSEError sends an error as a Server-Sent Event
func sendSSEError(w http.ResponseWriter, errorMessage string) {
	errorData := map[string]string{"error": errorMessage}
	jsonData, _ := json.Marshal(errorData)
	sendSSEMessage(w, fmt.Sprintf("event: error\ndata: %s\n\n", string(jsonData)))
}
