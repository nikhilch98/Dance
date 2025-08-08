package api

import (
	"nachna/core"
	"nachna/models/request"
	"nachna/utils"
	"net/http"
	"strings"
)

// Use the existing GetAdminService function from adminWorkshop.go

// Helper function to verify admin user
func verifyAdminUser(userID string) *core.NachnaException {
	authService, err := GetAuthService()
	if err != nil {
		return err
	}

	return authService.VerifyAdminUser(userID)
}

func AdminListArtists(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.ListArtists()
}

func AdminGetMissingArtistSessions(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.GetMissingArtistSessions()
}

func AdminGetMissingSongSessions(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.GetMissingSongSessions()
}

func AdminAssignArtistToSession(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	// Extract workshop UUID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 5 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Workshop UUID is required",
		}
	}
	workshopUUID := pathParts[len(pathParts)-2] // workshops/{uuid}/assign_artist

	assignArtistRequest := &request.AssignArtistRequest{}
	err := assignArtistRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	adminService, adminErr := GetAdminService()
	if adminErr != nil {
		return nil, adminErr
	}

	err = adminService.AssignArtistToSession(workshopUUID, assignArtistRequest)
	if err != nil {
		return nil, err
	}

	// Join artist names for response
	combinedArtistNames := strings.Join(assignArtistRequest.ArtistNameList, " X ")

	return map[string]interface{}{
		"success": true,
		"message": "Artists " + combinedArtistNames + " assigned to workshop " + workshopUUID + ".",
	}, nil
}

func AdminAssignSongToSession(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	// Extract workshop UUID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 5 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Workshop UUID is required",
		}
	}
	workshopUUID := pathParts[len(pathParts)-2] // workshops/{uuid}/assign_song

	assignSongRequest := &request.AssignSongRequest{}
	err := assignSongRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	adminService, adminErr := GetAdminService()
	if adminErr != nil {
		return nil, adminErr
	}

	err = adminService.AssignSongToSession(workshopUUID, assignSongRequest)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"success": true,
		"message": "Song '" + assignSongRequest.Song + "' assigned to workshop " + workshopUUID + ".",
	}, nil
}

func AdminSendTestNotification(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	testNotificationRequest := &request.TestNotificationRequest{}
	err := testNotificationRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	adminService, adminErr := GetAdminService()
	if adminErr != nil {
		return nil, adminErr
	}

	return adminService.SendTestNotification(testNotificationRequest)
}

func AdminGetAppInsights(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.GetAppInsights()
}

func AdminGetWorkshopsMissingInstagramLinks(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.GetWorkshopsMissingInstagramLinks()
}

func AdminUpdateWorkshopInstagramLink(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	// Extract workshop ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 5 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Workshop ID is required",
		}
	}
	workshopID := pathParts[len(pathParts)-2] // workshops/{id}/instagram-link

	updateInstagramLinkRequest := &request.UpdateInstagramLinkRequest{}
	err := updateInstagramLinkRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	adminService, adminErr := GetAdminService()
	if adminErr != nil {
		return nil, adminErr
	}

	err = adminService.UpdateWorkshopInstagramLink(workshopID, updateInstagramLinkRequest)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"success":           true,
		"message":           "Instagram link updated successfully for workshop " + workshopID + ".",
		"workshop_id":       workshopID,
		"choreo_insta_link": updateInstagramLinkRequest.ChoreoInstaLink,
	}, nil
}

func AdminGetArtistChoreoLinks(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Verify admin access
	if err := verifyAdminUser(userID); err != nil {
		return nil, err
	}

	// Extract artist ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 5 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Artist ID is required",
		}
	}
	artistID := pathParts[len(pathParts)-2] // artists/{id}/choreo-links

	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}

	return adminService.GetArtistChoreoLinks(artistID)
}

func init() {
	// Admin APIs
	Router.HandleFunc(utils.MakeHandler("/admin/api/artists", AdminListArtists, "admin")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/admin/api/missing_artist_sessions", AdminGetMissingArtistSessions, "admin")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/admin/api/missing_song_sessions", AdminGetMissingSongSessions, "admin")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/admin/api/workshops/{workshop_uuid}/assign_artist", AdminAssignArtistToSession, "admin")).Methods(http.MethodPut)
	Router.HandleFunc(utils.MakeHandler("/admin/api/workshops/{workshop_uuid}/assign_song", AdminAssignSongToSession, "admin")).Methods(http.MethodPut)
	Router.HandleFunc(utils.MakeHandler("/admin/api/send-test-notification", AdminSendTestNotification, "admin")).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/admin/api/app-insights", AdminGetAppInsights, "admin")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/admin/api/workshops/missing-instagram-links", AdminGetWorkshopsMissingInstagramLinks, "admin")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/admin/api/workshops/{workshop_id}/instagram-link", AdminUpdateWorkshopInstagramLink, "admin")).Methods(http.MethodPut)
	Router.HandleFunc(utils.MakeHandler("/admin/api/artists/{artist_id}/choreo-links", AdminGetArtistChoreoLinks, "admin")).Methods(http.MethodGet)
}
