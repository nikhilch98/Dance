package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"path/filepath"
	"strings"
	"time"

	"github.com/fasthttp/router"
	"github.com/nikhilchatragadda/dance/config"
	"github.com/nikhilchatragadda/dance/database"
	"github.com/nikhilchatragadda/dance/models"
	"github.com/nikhilchatragadda/dance/utils"
	"github.com/valyala/fasthttp"
)

const (
	defaultPort         = 8002
	defaultWorkers      = 4
	defaultReadTimeout  = 10 * time.Second
	defaultWriteTimeout = 10 * time.Second
)

// APIConfig holds API configuration and version management
type APIConfig struct {
	SupportedVersions []string
	DefaultVersion    string
	CorsOrigins       []string
}

// Server represents the HTTP server
type Server struct {
	Router    *router.Router
	Config    *config.Config
	APIConfig *APIConfig
}

// NewServer creates a new HTTP server
func NewServer() *Server {
	return &Server{
		Router: router.New(),
		Config: config.ParseArgs(),
		APIConfig: &APIConfig{
			SupportedVersions: []string{"v2"},
			DefaultVersion:    "v2",
			CorsOrigins:       []string{"*"}, // Allow all origins for development
		},
	}
}

// validateVersion validates the API version parameter
func (s *Server) validateVersion(ctx *fasthttp.RequestCtx) (string, error) {
	version := string(ctx.QueryArgs().Peek("version"))
	if version == "" {
		version = s.APIConfig.DefaultVersion
	}

	for _, v := range s.APIConfig.SupportedVersions {
		if v == version {
			return version, nil
		}
	}

	return "", fmt.Errorf("unsupported API version. Supported versions: %v", s.APIConfig.SupportedVersions)
}

// loggingMiddleware logs HTTP requests with method, path, response time, and cache status
func loggingMiddleware(next fasthttp.RequestHandler) fasthttp.RequestHandler {
	return func(ctx *fasthttp.RequestCtx) {
		// Record start time
		start := time.Now()

		// Create a flag to check if response comes from cache
		var fromCache bool

		// Store original response before we call next
		originalHeaders := make(map[string]string)
		ctx.Response.Header.VisitAll(func(key, value []byte) {
			originalHeaders[string(key)] = string(value)
		})

		// Process request
		next(ctx)

		// Check if response was served from cache after processing
		fromCache = string(ctx.Response.Header.Peek("Response-From-Cache")) == "true"

		// Calculate duration
		duration := time.Since(start)

		// Format the log message
		method := string(ctx.Method())
		path := string(ctx.Path())
		statusCode := ctx.Response.StatusCode()
		contentType := string(ctx.Response.Header.ContentType())
		cacheStatus := "MISS"
		if fromCache {
			cacheStatus = "HIT"
		}

		// For images/assets, log in a more compact format
		if strings.HasPrefix(path, "/static/") || strings.HasPrefix(path, "/proxy-image/") {
			contentSize := len(ctx.Response.Body())
			log.Printf("[ASSET] %s - %d - %s - %v - %.2fKB - %s",
				path, statusCode, contentType, duration, float64(contentSize)/1024, cacheStatus)
		} else {
			// Standard API request logging
			log.Printf("[API] %s %s %s - %d - %v - Cache: %s",
				method, path, ctx.QueryArgs().String(), statusCode, duration, cacheStatus)
		}

		// Remove cache header
		ctx.Response.Header.Del("Response-From-Cache")
	}
}

// cacheMiddleware caches API responses
func cacheMiddleware(handler fasthttp.RequestHandler, expireSeconds int) fasthttp.RequestHandler {
	return func(ctx *fasthttp.RequestCtx) {
		// Create a cache key based on the request
		cacheKey := string(ctx.URI().FullURI())
		// Print the cache key and the url
		// log.Printf("Cache key: %s, URL: %s", cacheKey, ctx.URI().FullURI())

		// Check if we have a cached response
		if cachedData, found := utils.GetCachedResponse(cacheKey); found {
			if cachedJSON, ok := cachedData.([]byte); ok {
				ctx.SetContentType("application/json")
				ctx.SetBody(cachedJSON)
				// Set header to indicate response is from cache
				ctx.Response.Header.Set("Response-From-Cache", "true")
				return
			}
		}

		// Call the original handler (no need to capture original body)
		ctx.Response.SetBody(nil)
		handler(ctx)

		// Cache the response
		responseBody := ctx.Response.Body()
		utils.CacheResponseMiddleware("", responseBody, expireSeconds)
	}
}

// CORS middleware handles Cross-Origin Resource Sharing
func corsMiddleware(next fasthttp.RequestHandler) fasthttp.RequestHandler {
	return func(ctx *fasthttp.RequestCtx) {
		ctx.Response.Header.Set("Access-Control-Allow-Origin", "*")
		ctx.Response.Header.Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		ctx.Response.Header.Set("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization")
		ctx.Response.Header.Set("Access-Control-Allow-Credentials", "true")

		// Handle preflight requests
		if string(ctx.Method()) == "OPTIONS" {
			ctx.SetStatusCode(fasthttp.StatusNoContent)
			return
		}

		next(ctx)
	}
}

// Route handlers

// handleHome serves the home page
func (s *Server) handleHome(ctx *fasthttp.RequestCtx) {
	templatePath := filepath.Join("templates", "website", "index.html")
	content, err := ioutil.ReadFile(templatePath)
	if err != nil {
		ctx.Error("Template not found", fasthttp.StatusNotFound)
		return
	}

	ctx.SetContentType("text/html")
	ctx.SetBody(content)
}

// handleGetWorkshops gets all workshops
func (s *Server) handleGetWorkshops(ctx *fasthttp.RequestCtx) {
	// We only need to check if the version is valid, not use it
	_, err := s.validateVersion(ctx)
	if err != nil {
		ctx.Error(err.Error(), fasthttp.StatusBadRequest)
		return
	}

	workshops, err := database.GetWorkshops()
	if err != nil {
		log.Printf("Database error: %v", err)
		ctx.SetStatusCode(fasthttp.StatusOK)
		ctx.SetContentType("application/json")
		ctx.SetBody([]byte("[]"))
		return
	}

	jsonData, err := json.Marshal(workshops)
	if err != nil {
		ctx.Error("Failed to marshal workshops", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleGetStudios gets all studios with active workshops
func (s *Server) handleGetStudios(ctx *fasthttp.RequestCtx) {
	totalStart := time.Now()
	defer func() {
		log.Printf("[PERF] Studios API - Total time: %v", time.Since(totalStart))
	}()

	// We only need to check if the version is valid, not use it
	versionStart := time.Now()
	_, err := s.validateVersion(ctx)
	log.Printf("[PERF] Studios API - Version validation: %v", time.Since(versionStart))
	if err != nil {
		ctx.Error(err.Error(), fasthttp.StatusBadRequest)
		return
	}

	dbStart := time.Now()
	studios, err := database.GetStudios()
	dbTime := time.Since(dbStart)
	log.Printf("[PERF] Studios API - Database query: %v", dbTime)

	if err != nil {
		log.Printf("Database error: %v", err)
		ctx.SetStatusCode(fasthttp.StatusOK)
		ctx.SetContentType("application/json")
		ctx.SetBody([]byte("[]"))
		return
	}

	marshalStart := time.Now()
	jsonData, err := json.Marshal(studios)
	log.Printf("[PERF] Studios API - JSON marshal (%d studios, %d bytes): %v",
		len(studios), len(jsonData), time.Since(marshalStart))

	if err != nil {
		ctx.Error("Failed to marshal studios", fasthttp.StatusInternalServerError)
		return
	}

	responseStart := time.Now()
	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
	log.Printf("[PERF] Studios API - Set response: %v", time.Since(responseStart))
}

// handleGetArtists gets all artists with active workshops
func (s *Server) handleGetArtists(ctx *fasthttp.RequestCtx) {
	// We only need to check if the version is valid, not use it
	_, err := s.validateVersion(ctx)
	if err != nil {
		ctx.Error(err.Error(), fasthttp.StatusBadRequest)
		return
	}

	artists, err := database.GetArtists()
	if err != nil {
		log.Printf("Database error: %v", err)
		ctx.SetStatusCode(fasthttp.StatusOK)
		ctx.SetContentType("application/json")
		ctx.SetBody([]byte("[]"))
		return
	}

	jsonData, err := json.Marshal(artists)
	if err != nil {
		ctx.Error("Failed to marshal artists", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleGetWorkshopsByArtist gets workshops for a specific artist
func (s *Server) handleGetWorkshopsByArtist(ctx *fasthttp.RequestCtx) {
	artistID := ctx.UserValue("artist_id").(string)

	// We only need to check if the version is valid, not use it
	_, err := s.validateVersion(ctx)
	if err != nil {
		ctx.Error(err.Error(), fasthttp.StatusBadRequest)
		return
	}

	workshops, err := database.GetWorkshopsByArtist(artistID)
	if err != nil {
		log.Printf("Database error: %v", err)
		ctx.SetStatusCode(fasthttp.StatusOK)
		ctx.SetContentType("application/json")
		ctx.SetBody([]byte("[]"))
		return
	}

	jsonData, err := json.Marshal(workshops)
	if err != nil {
		ctx.Error("Failed to marshal workshops", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleGetWorkshopsByStudio gets workshops for a specific studio
func (s *Server) handleGetWorkshopsByStudio(ctx *fasthttp.RequestCtx) {
	studioID := ctx.UserValue("studio_id").(string)

	// We only need to check if the version is valid, not use it
	_, err := s.validateVersion(ctx)
	if err != nil {
		ctx.Error(err.Error(), fasthttp.StatusBadRequest)
		return
	}

	workshopsData, err := database.GetWorkshopsByStudio(studioID)
	if err != nil {
		log.Printf("Error fetching workshops for studio %s: %v", studioID, err)
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		ctx.SetContentType("application/json")
		jsonError, _ := json.Marshal(map[string]string{"detail": "Internal server error"})
		ctx.SetBody(jsonError)
		return
	}

	// Check if empty
	if len(workshopsData.ThisWeek) == 0 && len(workshopsData.PostThisWeek) == 0 {
		emptyResponse, _ := json.Marshal(models.CategorizedWorkshopResponse{
			ThisWeek:     []models.DaySchedule{},
			PostThisWeek: []models.WorkshopSession{},
		})
		ctx.SetContentType("application/json")
		ctx.SetBody(emptyResponse)
		return
	}

	jsonData, err := json.Marshal(workshopsData)
	if err != nil {
		ctx.Error("Failed to marshal workshops", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleProxyImage proxies for fetching images to bypass CORS restrictions
func (s *Server) handleProxyImage(ctx *fasthttp.RequestCtx) {
	url := string(ctx.QueryArgs().Peek("url"))
	if url == "" {
		ctx.Error("URL parameter is required", fasthttp.StatusBadRequest)
		return
	}

	// Prepare request headers
	req := fasthttp.AcquireRequest()
	defer fasthttp.ReleaseRequest(req)

	req.SetRequestURI(url)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")

	// Send request
	resp := fasthttp.AcquireResponse()
	defer fasthttp.ReleaseResponse(resp)

	client := &fasthttp.Client{}
	if err := client.Do(req, resp); err != nil {
		ctx.Error(fmt.Sprintf("Error fetching image: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	if resp.StatusCode() != fasthttp.StatusOK {
		ctx.Error(fmt.Sprintf("Error fetching image: status code %d", resp.StatusCode()), fasthttp.StatusInternalServerError)
		return
	}

	// Set content type from response
	contentType := resp.Header.ContentType()
	ctx.Response.Header.SetContentType(string(contentType))
	ctx.SetBody(resp.Body())
}

// handleGetCache retrieves cached data for a specific cache key
func (s *Server) handleGetCache(ctx *fasthttp.RequestCtx) {
	// Extract cache key from query parameter
	cacheKey := string(ctx.QueryArgs().Peek("key"))
	if cacheKey == "" {
		ctx.Error("Cache key parameter 'key' is required", fasthttp.StatusBadRequest)
		return
	}

	// Check if key exists in cache
	if cachedData, found := utils.GetCachedResponse(cacheKey); found {
		if cachedJSON, ok := cachedData.([]byte); ok {
			// Return cache metadata and content
			responseData := map[string]interface{}{
				"cache_key":    cacheKey,
				"found":        true,
				"content_type": "application/json",
				"size":         len(cachedJSON),
				"content":      string(cachedJSON),
			}

			// Marshal response
			jsonData, err := json.Marshal(responseData)
			if err != nil {
				ctx.Error("Failed to marshal cache data", fasthttp.StatusInternalServerError)
				return
			}

			ctx.SetContentType("application/json")
			ctx.SetBody(jsonData)
			return
		}
	}

	// Return not found response
	responseData := map[string]interface{}{
		"cache_key": cacheKey,
		"found":     false,
	}

	jsonData, _ := json.Marshal(responseData)
	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// Admin API handlers

// handleAdminListStudios lists all studios
func (s *Server) handleAdminListStudios(ctx *fasthttp.RequestCtx) {
	studios, err := database.ListStudios()
	if err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	jsonData, err := json.Marshal(studios)
	if err != nil {
		ctx.Error("Failed to marshal studios", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleAdminCreateStudio creates a new studio
func (s *Server) handleAdminCreateStudio(ctx *fasthttp.RequestCtx) {
	var studio map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &studio); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.CreateStudio(studio); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminUpdateStudio updates an existing studio
func (s *Server) handleAdminUpdateStudio(ctx *fasthttp.RequestCtx) {
	studioID := ctx.UserValue("studio_id").(string)

	var studio map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &studio); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.UpdateStudio(studioID, studio); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminDeleteStudio deletes a studio
func (s *Server) handleAdminDeleteStudio(ctx *fasthttp.RequestCtx) {
	studioID := ctx.UserValue("studio_id").(string)

	if err := database.DeleteStudio(studioID); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminListArtists lists all artists
func (s *Server) handleAdminListArtists(ctx *fasthttp.RequestCtx) {
	artists, err := database.ListArtists()
	if err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	jsonData, err := json.Marshal(artists)
	if err != nil {
		ctx.Error("Failed to marshal artists", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleAdminCreateArtist creates a new artist
func (s *Server) handleAdminCreateArtist(ctx *fasthttp.RequestCtx) {
	var artist map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &artist); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.CreateArtist(artist); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminUpdateArtist updates an existing artist
func (s *Server) handleAdminUpdateArtist(ctx *fasthttp.RequestCtx) {
	artistID := ctx.UserValue("artist_id").(string)

	var artist map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &artist); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.UpdateArtist(artistID, artist); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminDeleteArtist deletes an artist
func (s *Server) handleAdminDeleteArtist(ctx *fasthttp.RequestCtx) {
	artistID := ctx.UserValue("artist_id").(string)

	if err := database.DeleteArtist(artistID); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminListWorkshops lists all workshops
func (s *Server) handleAdminListWorkshops(ctx *fasthttp.RequestCtx) {
	workshops, err := database.ListWorkshops()
	if err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	jsonData, err := json.Marshal(workshops)
	if err != nil {
		ctx.Error("Failed to marshal workshops", fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody(jsonData)
}

// handleAdminCreateWorkshop creates a new workshop
func (s *Server) handleAdminCreateWorkshop(ctx *fasthttp.RequestCtx) {
	var workshop map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &workshop); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.CreateWorkshop(workshop); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminUpdateWorkshop updates an existing workshop
func (s *Server) handleAdminUpdateWorkshop(ctx *fasthttp.RequestCtx) {
	uuid := ctx.UserValue("uuid").(string)

	var workshop map[string]interface{}
	if err := json.Unmarshal(ctx.PostBody(), &workshop); err != nil {
		ctx.Error("Invalid JSON", fasthttp.StatusBadRequest)
		return
	}

	if err := database.UpdateWorkshop(uuid, workshop); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminDeleteWorkshop deletes a workshop
func (s *Server) handleAdminDeleteWorkshop(ctx *fasthttp.RequestCtx) {
	uuid := ctx.UserValue("uuid").(string)

	if err := database.DeleteWorkshop(uuid); err != nil {
		ctx.Error(fmt.Sprintf("Database error: %v", err), fasthttp.StatusInternalServerError)
		return
	}

	ctx.SetContentType("application/json")
	ctx.SetBody([]byte(`{"success": true}`))
}

// handleAdminPanel serves the admin panel
func (s *Server) handleAdminPanel(ctx *fasthttp.RequestCtx) {
	templatePath := filepath.Join("templates", "website", "admin_panel.html")
	content, err := ioutil.ReadFile(templatePath)
	if err != nil {
		ctx.Error("Template not found", fasthttp.StatusNotFound)
		return
	}

	ctx.SetContentType("text/html")
	ctx.SetBody(content)
}

// serveStatic serves static files
func serveStatic(ctx *fasthttp.RequestCtx) {
	path := string(ctx.Path())
	if !strings.HasPrefix(path, "/static/") {
		ctx.Error("Invalid static path", fasthttp.StatusBadRequest)
		return
	}

	// Remove "/static/" prefix
	filePath := path[8:]
	filePath = filepath.Join("static", filePath)

	// Prevent directory traversal
	if !strings.HasPrefix(filePath, "static") {
		ctx.Error("Invalid static path", fasthttp.StatusBadRequest)
		return
	}

	// Special handling for placeholder images that don't exist
	if strings.HasSuffix(filePath, "artists/placeholder.jpg") {
		// Use the existing artists.png as a fallback
		filePath = filepath.Join("static", "assets", "artists", "artists.png")
	} else if strings.HasSuffix(filePath, "studios/placeholder.jpg") {
		// Use a default image for studios placeholder too
		filePath = filepath.Join("static", "assets", "studios", "studios.png")
	}

	content, err := ioutil.ReadFile(filePath)
	if err != nil {
		ctx.Error("File not found", fasthttp.StatusNotFound)
		return
	}

	// Set Content-Type based on file extension
	extension := filepath.Ext(filePath)
	switch extension {
	case ".css":
		ctx.SetContentType("text/css")
	case ".js":
		ctx.SetContentType("application/javascript")
	case ".jpg", ".jpeg":
		ctx.SetContentType("image/jpeg")
	case ".png":
		ctx.SetContentType("image/png")
	case ".gif":
		ctx.SetContentType("image/gif")
	case ".svg":
		ctx.SetContentType("image/svg+xml")
	default:
		ctx.SetContentType("application/octet-stream")
	}

	ctx.SetBody(content)
}

// SetupRoutes sets up all routes for the server
func (s *Server) SetupRoutes() {
	// Web routes
	s.Router.GET("/", s.handleHome)
	s.Router.GET("/static/{filepath:*}", serveStatic)

	// API routes with caching
	s.Router.GET("/api/workshops", cacheMiddleware(s.handleGetWorkshops, 3600))                               // 1 hour cache
	s.Router.GET("/api/studios", cacheMiddleware(s.handleGetStudios, 14400))                                  // 4 hours cache
	s.Router.GET("/api/artists", cacheMiddleware(s.handleGetArtists, 3600))                                   // 1 hour cache
	s.Router.GET("/api/workshops_by_artist/{artist_id}", cacheMiddleware(s.handleGetWorkshopsByArtist, 3600)) // 1 hour cache
	s.Router.GET("/api/workshops_by_studio/{studio_id}", cacheMiddleware(s.handleGetWorkshopsByStudio, 3600)) // 1 hour cache
	s.Router.GET("/proxy-image/", cacheMiddleware(s.handleProxyImage, 86400))                                 // 24 hours cache

	// Cache inspection API
	s.Router.GET("/api/cache", s.handleGetCache)

	// Admin API routes
	s.Router.GET("/admin/api/studios", s.handleAdminListStudios)
	s.Router.POST("/admin/api/studios", s.handleAdminCreateStudio)
	s.Router.PUT("/admin/api/studios/{studio_id}", s.handleAdminUpdateStudio)
	s.Router.DELETE("/admin/api/studios/{studio_id}", s.handleAdminDeleteStudio)

	s.Router.GET("/admin/api/artists", s.handleAdminListArtists)
	s.Router.POST("/admin/api/artists", s.handleAdminCreateArtist)
	s.Router.PUT("/admin/api/artists/{artist_id}", s.handleAdminUpdateArtist)
	s.Router.DELETE("/admin/api/artists/{artist_id}", s.handleAdminDeleteArtist)

	s.Router.GET("/admin/api/workshops", s.handleAdminListWorkshops)
	s.Router.POST("/admin/api/workshops", s.handleAdminCreateWorkshop)
	s.Router.PUT("/admin/api/workshops/{uuid}", s.handleAdminUpdateWorkshop)
	s.Router.DELETE("/admin/api/workshops/{uuid}", s.handleAdminDeleteWorkshop)

	s.Router.GET("/admin", s.handleAdminPanel)
}

func main() {
	server := NewServer()
	server.SetupRoutes()

	// Apply middlewares - order matters
	// First logging, then CORS
	handler := loggingMiddleware(corsMiddleware(server.Router.Handler))

	// Start cache invalidation watcher
	utils.StartCacheInvalidationWatcher()

	// Start the server
	log.Printf("Starting server on port %d", defaultPort)
	if err := fasthttp.ListenAndServe(fmt.Sprintf(":%d", defaultPort), handler); err != nil {
		log.Fatalf("Error in ListenAndServe: %v", err)
	}
}
