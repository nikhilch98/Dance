package api

import (
	"encoding/json"
	"html/template"
	"nachna/core"
	"nachna/database"
	"nachna/models/response"
	"nachna/utils"
	"net/http"
	"path/filepath"
	"strings"
)

// Templates
var templates *template.Template

func init() {
	// Load templates
	templateDir := filepath.Join("templates", "website")
	templates = template.Must(template.ParseGlob(filepath.Join(templateDir, "*.html")))
}

// HandleError helper function for web handlers
func HandleError(w http.ResponseWriter, err *core.NachnaException) {
	response := response.CustomErrorMessage{Message: err.ErrorMessage}
	res, _ := json.Marshal(response)
	utils.GenerateResponse(w, err.StatusCode, res)
}

// HomePageHandler serves the main landing page
func HomePageHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "Nachna - Discover Dance Workshops",
		"Description": "Find and book dance workshops in Mumbai. Connect with top choreographers and dance studios.",
		"Keywords":    "dance workshops, Mumbai dance, choreography, dance classes",
	}

	err := templates.ExecuteTemplate(w, "index.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// MarketingPageHandler serves the marketing page
func MarketingPageHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "Nachna Marketing - Partner with Us",
		"Description": "Partner with Nachna to promote your dance workshops and reach more students.",
		"Keywords":    "dance marketing, workshop promotion, dance partnerships",
	}

	err := templates.ExecuteTemplate(w, "marketing.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// PrivacyPolicyHandler serves the privacy policy page
func PrivacyPolicyHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "Privacy Policy - Nachna",
		"Description": "Nachna's privacy policy and data protection information.",
	}

	err := templates.ExecuteTemplate(w, "privacy-policy.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// TermsOfServiceHandler serves the terms of service page
func TermsOfServiceHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "Terms of Service - Nachna",
		"Description": "Nachna's terms of service and user agreement.",
	}

	err := templates.ExecuteTemplate(w, "terms-of-service.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// SupportPageHandler serves the support page
func SupportPageHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "Support - Nachna",
		"Description": "Get help and support for using the Nachna platform.",
		"Keywords":    "dance support, help, customer service",
	}

	err := templates.ExecuteTemplate(w, "support.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// AIAnalyzerHandler serves the AI analyzer page
func AIAnalyzerHandler(w http.ResponseWriter, r *http.Request) {
	data := map[string]interface{}{
		"Title":       "AI Workshop Analyzer - Nachna",
		"Description": "AI-powered workshop content analysis and insights.",
		"Keywords":    "AI analysis, workshop insights, dance analytics",
	}

	err := templates.ExecuteTemplate(w, "ai_analyzer.html", data)
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   err.Error(),
		})
		return
	}
}

// ArtistRedirectHandler handles deep links to artist profiles
func ArtistRedirectHandler(w http.ResponseWriter, r *http.Request) {
	// Extract artist ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 3 {
		HandleError(w, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Artist ID is required",
		})
		return
	}

	artistID := pathParts[len(pathParts)-1]

	// Get artist details
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Database connection failed",
		})
		return
	}

	artist, dbErr := databaseImpl.GetArtistByID(r.Context(), artistID)
	if dbErr != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Artist not found",
		})
		return
	}

	// Prepare data for template
	data := map[string]interface{}{
		"Title":       artist.ArtistName + " - Nachna",
		"Description": "View " + artist.ArtistName + "'s dance workshops and profile on Nachna.",
		"Keywords":    "dance artist, " + artist.ArtistName + ", workshops, choreography",
		"Artist":      artist,
		"artist_name": artist.ArtistName, // For template compatibility
		"DeepLink":    "nachna://artist/" + artistID,
	}

	templateErr := templates.ExecuteTemplate(w, "artist_redirect.html", data)
	if templateErr != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   templateErr.Error(),
		})
		return
	}
}

// StudioRedirectHandler handles deep links to studio profiles
func StudioRedirectHandler(w http.ResponseWriter, r *http.Request) {
	// Extract studio ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 3 {
		HandleError(w, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Studio ID is required",
		})
		return
	}

	studioID := pathParts[len(pathParts)-1]

	// Get studio details
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Database connection failed",
		})
		return
	}

	studio, dbErr := databaseImpl.GetStudioByID(r.Context(), studioID)
	if dbErr != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Studio not found",
		})
		return
	}

	// Prepare data for template
	data := map[string]interface{}{
		"Title":       studio.StudioName + " - Nachna",
		"Description": "View workshops and classes at " + studio.StudioName + " on Nachna.",
		"Keywords":    "dance studio, " + studio.StudioName + ", workshops, classes",
		"Studio":      studio,
		"DeepLink":    "nachna://studio/" + studioID,
	}

	templateErr := templates.ExecuteTemplate(w, "studio_redirect.html", data)
	if templateErr != nil {
		HandleError(w, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Template error",
			LogMessage:   templateErr.Error(),
		})
		return
	}
}

func init() {
	// Web page routes
	Router.HandleFunc("/", HomePageHandler).Methods(http.MethodGet)
	Router.HandleFunc("/marketing", MarketingPageHandler).Methods(http.MethodGet)
	Router.HandleFunc("/privacy-policy", PrivacyPolicyHandler).Methods(http.MethodGet)
	Router.HandleFunc("/terms-of-service", TermsOfServiceHandler).Methods(http.MethodGet)
	Router.HandleFunc("/support", SupportPageHandler).Methods(http.MethodGet)
	Router.HandleFunc("/ai", AIAnalyzerHandler).Methods(http.MethodGet)

	// Deep link routes
	Router.HandleFunc("/artist/{artist_id}", ArtistRedirectHandler).Methods(http.MethodGet)
	Router.HandleFunc("/studio/{studio_id}", StudioRedirectHandler).Methods(http.MethodGet)
}
