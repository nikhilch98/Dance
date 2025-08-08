package api

import (
	"fmt"
	"io"
	"nachna/core"
	"nachna/database"
	"nachna/service/workshop"
	"nachna/utils"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

func GetWorkshopService() (*workshop.WorkshopServiceImpl, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	workshopService := workshop.WorkshopServiceImpl{}.GetInstance(databaseImpl)
	return workshopService, nil
}

func GetWorkshops(r *http.Request) (any, *core.NachnaException) {
	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.GetAllWorkshopsCategorized(nil)
}

func GetStudios(r *http.Request) (any, *core.NachnaException) {
	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.GetStudios()
}

func GetArtists(r *http.Request) (any, *core.NachnaException) {
	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	// Check for has_workshops query parameter
	var hasWorkshops *bool
	if hasWorkshopsStr := r.URL.Query().Get("has_workshops"); hasWorkshopsStr != "" {
		if hasWorkshopsVal, parseErr := strconv.ParseBool(hasWorkshopsStr); parseErr == nil {
			hasWorkshops = &hasWorkshopsVal
		}
	}

	return workshopService.GetArtists(hasWorkshops)
}

func GetWorkshopsByArtist(r *http.Request) (any, *core.NachnaException) {
	// Extract artist ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 3 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Artist ID is required",
		}
	}
	artistID := pathParts[len(pathParts)-1]

	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.GetWorkshopsByArtist(artistID)
}

func GetWorkshopsByStudio(r *http.Request) (any, *core.NachnaException) {
	// Extract studio ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 3 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Studio ID is required",
		}
	}
	studioID := pathParts[len(pathParts)-1]

	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.GetAllWorkshopsCategorized(&studioID)
}

func ProxyImage(r *http.Request) (any, *core.NachnaException) {
	imageURL := r.URL.Query().Get("url")
	if imageURL == "" {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "URL parameter is required",
		}
	}

	// Validate URL
	_, err := url.Parse(imageURL)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid URL format",
			LogMessage:   err.Error(),
		}
	}

	// Create HTTP client with user agent
	client := &http.Client{}
	req, err := http.NewRequest("GET", imageURL, nil)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to create request",
			LogMessage:   err.Error(),
		}
	}

	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")

	resp, err := client.Do(req)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to fetch image",
			LogMessage:   err.Error(),
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, &core.NachnaException{
			StatusCode:   resp.StatusCode,
			ErrorMessage: fmt.Sprintf("Failed to fetch image: %s", resp.Status),
		}
	}

	// Read image data
	imageData, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to read image data",
			LogMessage:   err.Error(),
		}
	}

	// Note: In actual implementation, this would return raw image data with proper headers
	// For now, returning a placeholder response
	return map[string]interface{}{
		"content_type": resp.Header.Get("Content-Type"),
		"size":         len(imageData),
		"url":          imageURL,
	}, nil
}

func SearchUsers(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token for authorization
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	query := r.URL.Query().Get("q")
	if len(query) < 2 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Search query must be at least 2 characters",
		}
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 20 // default
	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 && parsedLimit <= 50 {
			limit = parsedLimit
		}
	}

	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.SearchUsers(query, limit)
}

func SearchArtists(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token for authorization
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	query := r.URL.Query().Get("q")
	if len(query) < 2 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Search query must be at least 2 characters",
		}
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 20 // default
	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 && parsedLimit <= 50 {
			limit = parsedLimit
		}
	}

	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.SearchArtists(query, limit)
}

func SearchWorkshops(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token for authorization
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	query := r.URL.Query().Get("q")
	if len(query) < 2 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Search query must be at least 2 characters",
		}
	}

	workshopService, err := GetWorkshopService()
	if err != nil {
		return nil, err
	}

	return workshopService.SearchWorkshops(query)
}

func init() {
	// Workshop discovery APIs
	Router.HandleFunc(utils.MakeHandler("/workshops", GetWorkshops)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/studios", GetStudios)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/artists", GetArtists)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/workshops_by_artist/{artist_id}", GetWorkshopsByArtist)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/workshops_by_studio/{studio_id}", GetWorkshopsByStudio)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/proxy-image/", ProxyImage)).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/profile-picture/{user_id}", GetProfilePicture)).Methods(http.MethodGet)

	// Search APIs
	Router.HandleFunc(utils.MakeHandler("/search/users", SearchUsers, "user")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/search/artists", SearchArtists, "user")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/search/workshops", SearchWorkshops, "user")).Methods(http.MethodGet)
}
