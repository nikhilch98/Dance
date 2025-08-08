package admin

import (
	"context"
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/models/response"
	"nachna/service/admin/studio"
	"nachna/service/notification"

	"sync"
)

var lock = &sync.Mutex{}

type AdminServiceImpl struct {
	adminStudioService  *studio.AdminStudioServiceImpl
	databaseImpl        *database.MongoDBDatabaseImpl
	notificationService *notification.NotificationServiceImpl
}

var adminServiceImpl *AdminServiceImpl

func (AdminServiceImpl) GetInstance(adminStudioServiceImpl *studio.AdminStudioServiceImpl, databaseImpl *database.MongoDBDatabaseImpl, notificationService *notification.NotificationServiceImpl) *AdminServiceImpl {
	if adminServiceImpl == nil {
		lock.Lock()
		defer lock.Unlock()
		if adminServiceImpl == nil {
			adminServiceImpl = &AdminServiceImpl{
				adminStudioService:  adminStudioServiceImpl,
				databaseImpl:        databaseImpl,
				notificationService: notificationService,
			}
		}
	}
	return adminServiceImpl
}

func (a *AdminServiceImpl) RefreshWorkshops(request *request.AdminWorkshopRequest) (any, *core.NachnaException) {
	return a.adminStudioService.RefreshWorkshopsGivenStudioId(request.StudioId)
}

func (a *AdminServiceImpl) RefreshStudios(request *request.AdminStudioRequest) (any, *core.NachnaException) {
	return a.adminStudioService.RefreshStudios()
}

// Python API methods

// ListArtists lists all artists for admin
func (a *AdminServiceImpl) ListArtists() ([]response.Artist, *core.NachnaException) {
	artists, err := a.databaseImpl.GetAllArtistsFromDB(context.TODO(), nil)
	if err != nil {
		return nil, err
	}

	var artistResponses []response.Artist
	for _, artist := range artists {
		artistResponses = append(artistResponses, response.FormatArtist(artist))
	}

	return artistResponses, nil
}

// GetMissingArtistSessions gets workshops with missing artist assignments
func (a *AdminServiceImpl) GetMissingArtistSessions() ([]response.MissingArtistSession, *core.NachnaException) {
	return a.databaseImpl.GetMissingArtistSessions(context.TODO())
}

// GetMissingSongSessions gets workshops with missing song assignments
func (a *AdminServiceImpl) GetMissingSongSessions() ([]response.MissingArtistSession, *core.NachnaException) {
	return a.databaseImpl.GetMissingSongSessions(context.TODO())
}

// AssignArtistToSession assigns artists to a workshop session
func (a *AdminServiceImpl) AssignArtistToSession(workshopUUID string, req *request.AssignArtistRequest) *core.NachnaException {
	return a.databaseImpl.AssignArtistToWorkshop(context.TODO(), workshopUUID, req.ArtistIDList, req.ArtistNameList)
}

// AssignSongToSession assigns a song to a workshop session
func (a *AdminServiceImpl) AssignSongToSession(workshopUUID string, req *request.AssignSongRequest) *core.NachnaException {
	return a.databaseImpl.AssignSongToWorkshop(context.TODO(), workshopUUID, req.Song)
}

// SendTestNotification sends a test notification to users
func (a *AdminServiceImpl) SendTestNotification(req *request.TestNotificationRequest) (*response.TestNotificationResponse, *core.NachnaException) {
	title := "Test Notification"
	if req.Title != nil {
		title = *req.Title
	}

	body := "This is a test notification from Nachna admin."
	if req.Body != nil {
		body = *req.Body
	}

	var notifiedUserIDs []string

	if req.ArtistID != nil {
		// Send to users following the specific artist
		userIDs, err := a.notificationService.GetUsersFollowingArtist(*req.ArtistID)
		if err != nil {
			return nil, err
		}

		if len(userIDs) == 0 {
			return &response.TestNotificationResponse{
				Success: false,
				Message: "No users found following artist with notifications enabled.",
				Details: response.TestNotificationDetails{},
			}, nil
		}

		notifiedUserIDs = userIDs

		// Get artist name
		artistName, _ := a.notificationService.GetArtistName(*req.ArtistID)
		if req.Title == nil {
			title = "Test from " + artistName
		}
		if req.Body == nil {
			body = "This is a test notification for followers of " + artistName + "."
		}
	} else {
		// Send to all users with device tokens
		allTokens, err := a.notificationService.GetAllActiveDeviceTokens()
		if err != nil {
			return nil, err
		}

		if len(allTokens) == 0 {
			return &response.TestNotificationResponse{
				Success: false,
				Message: "No users with active device tokens found.",
				Details: response.TestNotificationDetails{},
			}, nil
		}

		for _, token := range allTokens {
			if token.UserID != "" {
				notifiedUserIDs = append(notifiedUserIDs, token.UserID)
			}
		}

		if req.Title == nil {
			title = "Admin Test Notification"
		}
		if req.Body == nil {
			body = "This is a test notification from Nachna admin."
		}
	}

	// Get device tokens for the users
	deviceTokens, err := a.notificationService.GetDeviceTokensForUsers(notifiedUserIDs)
	if err != nil {
		return nil, err
	}

	if len(deviceTokens) == 0 {
		return &response.TestNotificationResponse{
			Success: false,
			Message: "No device tokens found for the target users.",
			Details: response.TestNotificationDetails{},
		}, nil
	}

	// Filter iOS tokens
	iosTokenCount := 0
	for _, token := range deviceTokens {
		if token.Platform == "ios" {
			iosTokenCount++
		}
	}

	// Send notifications
	successCount, totalAttempts, err := a.notificationService.SendTestNotification(title, body, notifiedUserIDs)
	if err != nil {
		return nil, err
	}

	return &response.TestNotificationResponse{
		Success: true,
		Message: "Test notification sent successfully.",
		Details: response.TestNotificationDetails{
			TotalUsers:      len(notifiedUserIDs),
			TotalTokens:     len(deviceTokens),
			IOSTokens:       iosTokenCount,
			SuccessfulSends: successCount,
			TotalAttempts:   totalAttempts,
		},
	}, nil
}

// GetAppInsights gets application insights and statistics
func (a *AdminServiceImpl) GetAppInsights() (*response.AppInsightsResponse, *core.NachnaException) {
	insights, err := a.databaseImpl.GetAppInsights(context.TODO())
	if err != nil {
		return nil, err
	}

	return &response.AppInsightsResponse{
		Success: true,
		Data:    *insights,
	}, nil
}

// GetWorkshopsMissingInstagramLinks gets workshops that are missing Instagram links
func (a *AdminServiceImpl) GetWorkshopsMissingInstagramLinks() ([]response.WorkshopMissingInstagramLink, *core.NachnaException) {
	return a.databaseImpl.GetWorkshopsMissingInstagramLinks(context.TODO())
}

// UpdateWorkshopInstagramLink updates the Instagram link for a specific workshop
func (a *AdminServiceImpl) UpdateWorkshopInstagramLink(workshopID string, req *request.UpdateInstagramLinkRequest) *core.NachnaException {
	return a.databaseImpl.UpdateWorkshopInstagramLink(context.TODO(), workshopID, req.ChoreoInstaLink)
}

// GetArtistChoreoLinks gets all existing choreo links for a specific artist
func (a *AdminServiceImpl) GetArtistChoreoLinks(artistID string) (*response.ArtistChoreoLinksResponse, *core.NachnaException) {
	links, err := a.databaseImpl.GetArtistChoreoLinks(context.TODO(), artistID)
	if err != nil {
		return nil, err
	}

	return &response.ArtistChoreoLinksResponse{
		Success: true,
		Data:    links,
		Count:   len(links),
	}, nil
}
