package handler

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"dance_api_go/src/types"
	"dance_api_go/src/utils"
)

type HandlerFunc func() types.GenericResponse
type HandlerWithRequestFunc func(*http.Request) types.GenericResponse

func GenericHandler(fn interface{}) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()
		requestId := utils.Uuid()

		// Log request
		fmt.Printf("Request : %s | Timestamp : %d | ID: %s\n",
			r.URL.Path, startTime.UnixMicro(), requestId)

		// Execute handler based on its type
		var response types.GenericResponse
		switch h := fn.(type) {
		case HandlerFunc:
			response = h()
		case HandlerWithRequestFunc:
			response = h(r)
		default:
			log.Printf("Invalid handler type")
			response = types.GenericResponse{
				StatusCode: http.StatusInternalServerError,
				Success:    false,
				Error:      "Internal server error",
			}
		}

		// Log response
		responseTime := time.Now()
		green := "\033[32m"
		reset := "\033[0m"
		responseMessage := fmt.Sprintf("%sResponse : %s | Timestamp : %d | Latency : %dms | ID: %s%s",
			green, r.URL.Path, responseTime.UnixMicro(),
			time.Since(startTime).Microseconds(), requestId, reset)
		fmt.Println(responseMessage)

		// Set response headers
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(response.StatusCode)

		// Write response
		if _, err := w.Write(response.Serialize()); err != nil {
			log.Printf("Error writing response: %v", err)
		}
	}
}
