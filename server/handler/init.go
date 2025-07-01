package handler

import (
	"github.com/gorilla/mux"
	"github.com/gorilla/handlers"
	"net/http"
	"log"
)

func SetupRouter() http.Handler {
	// Create main router
	router := mux.NewRouter()
	
	// API routes
	api := router.PathPrefix("/api").Subrouter()
	
	// Health check
	api.HandleFunc("/health_check", HealthCheckHandler).Methods("GET")
	
	// Add logging middleware
	router.Use(loggingMiddleware)
	
	// Add CORS middleware and return the wrapped handler
	corsHandler := handlers.CORS(
		handlers.AllowedOrigins([]string{"*"}),
		handlers.AllowedMethods([]string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}),
		handlers.AllowedHeaders([]string{"Content-Type", "Authorization"}),
	)
	
	return corsHandler(router)
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.Method, r.RequestURI, r.RemoteAddr)
		next.ServeHTTP(w, r)
	})
} 