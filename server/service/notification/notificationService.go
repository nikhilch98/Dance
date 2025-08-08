package notification

import (
	"context"
	"fmt"
	"nachna/core"
	"nachna/database"
	"nachna/models/mongodb"
	"sync"
	"time"
)

type NotificationServiceImpl struct {
	databaseImpl *database.MongoDBDatabaseImpl
}

var notificationServiceInstance *NotificationServiceImpl
var notificationServiceLock = &sync.Mutex{}

func (NotificationServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *NotificationServiceImpl {
	if notificationServiceInstance == nil {
		notificationServiceLock.Lock()
		defer notificationServiceLock.Unlock()
		if notificationServiceInstance == nil {
			notificationServiceInstance = &NotificationServiceImpl{
				databaseImpl: databaseImpl,
			}
		}
	}
	return notificationServiceInstance
}

// GetUsersFollowingArtist gets users who are following a specific artist
func (n *NotificationServiceImpl) GetUsersFollowingArtist(artistID string) ([]string, *core.NachnaException) {
	ctx := context.Background()

	// Get reactions with type "notify" for the artist
	reactions, err := n.databaseImpl.GetReactionsForEntity(ctx, artistID, "artist", "notify")
	if err != nil {
		return nil, err
	}

	var userIDs []string
	for _, reaction := range reactions {
		if !reaction.IsDeleted {
			userIDs = append(userIDs, reaction.UserID)
		}
	}

	return userIDs, nil
}

// GetAllActiveDeviceTokens gets all active device tokens
func (n *NotificationServiceImpl) GetAllActiveDeviceTokens() ([]*mongodb.DeviceToken, *core.NachnaException) {
	ctx := context.Background()
	return n.databaseImpl.GetAllActiveDeviceTokens(ctx)
}

// GetDeviceTokensForUsers gets device tokens for specific users
func (n *NotificationServiceImpl) GetDeviceTokensForUsers(userIDs []string) ([]*mongodb.DeviceToken, *core.NachnaException) {
	ctx := context.Background()
	return n.databaseImpl.GetDeviceTokensForUsers(ctx, userIDs)
}

// SendTestNotification sends a test notification to specified users
func (n *NotificationServiceImpl) SendTestNotification(title string, body string, userIDs []string) (int, int, *core.NachnaException) {
	// Get device tokens for the users
	deviceTokens, err := n.GetDeviceTokensForUsers(userIDs)
	if err != nil {
		return 0, 0, err
	}

	if len(deviceTokens) == 0 {
		return 0, 0, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "No device tokens found for target users",
		}
	}

	// Filter iOS tokens (for APNs)
	var iosTokens []*mongodb.DeviceToken
	for _, token := range deviceTokens {
		if token.Platform == "ios" {
			iosTokens = append(iosTokens, token)
		}
	}

	successCount := 0
	totalAttempts := len(iosTokens)

	// Send notifications to iOS devices
	for _, tokenData := range iosTokens {
		// In a real implementation, this would use APNs to send notifications
		// For now, we'll simulate the sending and log it
		success := n.simulateNotificationSend(tokenData.DeviceToken, title, body)
		if success {
			successCount++
		}

		// Store notification record
		notification := &mongodb.Notification{
			UserID:    tokenData.UserID,
			Title:     title,
			Body:      body,
			Data:      map[string]interface{}{"type": "admin_test", "timestamp": time.Now().Format(time.RFC3339)},
			Sent:      true,
			Success:   success,
			CreatedAt: time.Now(),
			SentAt:    &[]time.Time{time.Now()}[0],
		}

		if !success {
			errMsg := "Failed to send notification"
			notification.ErrorMsg = &errMsg
		}

		// Save notification to database
		n.databaseImpl.CreateNotification(context.Background(), notification)
	}

	return successCount, totalAttempts, nil
}

// simulateNotificationSend simulates sending a notification (mock implementation)
func (n *NotificationServiceImpl) simulateNotificationSend(deviceToken string, title string, body string) bool {
	// In production, this would integrate with APNs or FCM
	// For now, we'll simulate success for demonstration
	fmt.Printf("📱 Sending notification to device %s...: '%s' - '%s'\n", deviceToken[:10], title, body)

	// Simulate 90% success rate
	return time.Now().UnixNano()%10 != 0
}

// GetArtistName gets artist name by ID
func (n *NotificationServiceImpl) GetArtistName(artistID string) (string, *core.NachnaException) {
	ctx := context.Background()
	artist, err := n.databaseImpl.GetArtistByID(ctx, artistID)
	if err != nil {
		return "Unknown Artist", nil // Don't fail, just return default
	}
	return artist.ArtistName, nil
}
