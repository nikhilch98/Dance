package middleware

import (
	"log"
	"net/http"
	"time"
)

// responseWriter is a custom ResponseWriter that captures the status code and response size
type responseWriter struct {
	http.ResponseWriter
	statusCode   int
	responseSize int64
}

// Write captures the response size
func (rw *responseWriter) Write(b []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(b)
	rw.responseSize += int64(size)
	return size, err
}

// WriteHeader captures the status code
func (rw *responseWriter) WriteHeader(statusCode int) {
	rw.statusCode = statusCode
	rw.ResponseWriter.WriteHeader(statusCode)
}

// RequestLogger is a middleware that logs information about each request
func RequestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Create a custom response writer
		rw := &responseWriter{
			ResponseWriter: w,
			statusCode:     http.StatusOK,
		}

		// Get the current timestamp
		startTime := time.Now()

		// Process request
		next.ServeHTTP(rw, r)

		// Calculate duration
		duration := time.Since(startTime)

		// Get status code text
		statusText := http.StatusText(rw.statusCode)

		// Format the log message
		log.Printf("\n╔══════════════════════ REQUEST LOG ══════════════════════\n"+
			"║ Time:      %v\n"+
			"║ Duration:  %v\n"+
			"║ Method:    %s\n"+
			"║ Path:      %s\n"+
			"║ Protocol:  %s\n"+
			"║ Status:    %d %s\n"+
			"║ Size:      %d bytes\n"+
			"║ IP:        %s\n"+
			"║ User Agent: %s\n"+
			"║ API:       %s\n"+
			"╚═════════════════════════════════════════════════════════",
			startTime.Format("2006/01/02 15:04:05.000"),
			duration,
			r.Method,
			r.URL.Path,
			r.Proto,
			rw.statusCode,
			statusText,
			rw.responseSize,
			r.RemoteAddr,
			r.UserAgent(),
			getAPIName(r.URL.Path, r.Method),
		)
	})
}

// getAPIName returns a friendly name for the API endpoint
func getAPIName(path, method string) string {
	switch path {
	case "/api/workshops":
		return "List Workshops"
	case "/api/studios":
		return "List Studios"
	case "/api/artists":
		return "List Artists"
	case "/admin/api/studios":
		if method == "GET" {
			return "Admin: List Studios"
		}
		return "Admin: Create Studio"
	case "/admin/api/artists":
		if method == "GET" {
			return "Admin: List Artists"
		}
		return "Admin: Create Artist"
	case "/admin/api/workshops":
		if method == "GET" {
			return "Admin: List Workshops"
		}
		return "Admin: Create Workshop"
	default:
		// Handle dynamic paths
		if len(path) > 20 {
			return path[:20] + "..."
		}
		return path
	}
}
