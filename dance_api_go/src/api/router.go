package api

import (
	"net/http"

	"github.com/gorilla/mux"
	"github.com/rs/cors"

	"dance_api_go/src/api/handler"
	"dance_api_go/src/middleware"
)

// SetupRouter initializes and configures the router
func SetupRouter() http.Handler {
	r := mux.NewRouter()

	// Add logging middleware
	r.Use(middleware.RequestLogger)

	// Middleware
	c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	})

	// Health Check
	r.HandleFunc("/health", handler.GenericHandler(handler.HealthCheckHandler)).Methods("GET")

	// API Routes
	api := r.PathPrefix("/api").Subrouter()

	// Workshops endpoints
	api.HandleFunc("/workshops", handler.GenericHandler(handler.GetWorkshopsHandler)).Methods("GET")
	api.HandleFunc("/workshops_by_artist/{artistId}", handler.GenericHandler(handler.GetWorkshopsByArtistHandler)).Methods("GET")
	api.HandleFunc("/workshops_by_studio/{studioId}", handler.GenericHandler(handler.GetWorkshopsByStudioHandler)).Methods("GET")

	// Studios endpoints
	api.HandleFunc("/studios", handler.GenericHandler(handler.GetStudiosHandler)).Methods("GET")

	// Artists endpoints
	api.HandleFunc("/artists", handler.GenericHandler(handler.GetArtistsHandler)).Methods("GET")

	// Admin routes
	admin := r.PathPrefix("/admin/api").Subrouter()
	admin.HandleFunc("/studios", handler.GenericHandler(handler.AdminListStudiosHandler)).Methods("GET")
	admin.HandleFunc("/studios", handler.GenericHandler(handler.AdminCreateStudioHandler)).Methods("POST")
	admin.HandleFunc("/studios/{studioId}", handler.GenericHandler(handler.AdminUpdateStudioHandler)).Methods("PUT")
	admin.HandleFunc("/studios/{studioId}", handler.GenericHandler(handler.AdminDeleteStudioHandler)).Methods("DELETE")

	admin.HandleFunc("/artists", handler.GenericHandler(handler.AdminListArtistsHandler)).Methods("GET")
	admin.HandleFunc("/artists", handler.GenericHandler(handler.AdminCreateArtistHandler)).Methods("POST")
	admin.HandleFunc("/artists/{artistId}", handler.GenericHandler(handler.AdminUpdateArtistHandler)).Methods("PUT")
	admin.HandleFunc("/artists/{artistId}", handler.GenericHandler(handler.AdminDeleteArtistHandler)).Methods("DELETE")

	admin.HandleFunc("/workshops", handler.GenericHandler(handler.AdminListWorkshopsHandler)).Methods("GET")
	admin.HandleFunc("/workshops", handler.GenericHandler(handler.AdminCreateWorkshopHandler)).Methods("POST")
	admin.HandleFunc("/workshops/{uuid}", handler.GenericHandler(handler.AdminUpdateWorkshopHandler)).Methods("PUT")
	admin.HandleFunc("/workshops/{uuid}", handler.GenericHandler(handler.AdminDeleteWorkshopHandler)).Methods("DELETE")

	// Static files
	fs := http.FileServer(http.Dir("static"))
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", fs))

	return c.Handler(r)
}
