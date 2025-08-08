package response

import "nachna/models/mongodb"

type SendOTPResponse struct {
	Success      bool   `json:"success"`
	Message      string `json:"message"`
	MobileNumber string `json:"mobile_number"`
}

type AuthResponse struct {
	AccessToken string      `json:"access_token"`
	TokenType   string      `json:"token_type"`
	User        UserProfile `json:"user"`
}

type UserProfile struct {
	ID                string  `json:"id"`
	MobileNumber      string  `json:"mobile_number"`
	Name              *string `json:"name,omitempty"`
	DateOfBirth       *string `json:"date_of_birth,omitempty"`
	Gender            *string `json:"gender,omitempty"`
	ProfilePictureURL *string `json:"profile_picture_url,omitempty"`
	IsAdmin           bool    `json:"is_admin"`
	CreatedAt         string  `json:"created_at"`
	UpdatedAt         string  `json:"updated_at"`
}

type ConfigResponse struct {
	IsAdmin         bool   `json:"is_admin"`
	DeviceToken     string `json:"device_token"`
	TokenSyncStatus string `json:"token_sync_status"`
}

type ProfilePictureUploadResponse struct {
	Message  string `json:"message"`
	ImageURL string `json:"image_url"`
}

type GenericResponse struct {
	Message string `json:"message"`
}

// Helper function to format user profile
func FormatUserProfile(user *mongodb.User) UserProfile {
	userID := ""
	if user.ID != nil {
		userID = user.ID.(string) // Type assertion needed
	}

	return UserProfile{
		ID:                userID,
		MobileNumber:      user.MobileNumber,
		Name:              user.Name,
		DateOfBirth:       user.DateOfBirth,
		Gender:            user.Gender,
		ProfilePictureURL: user.ProfilePictureURL,
		IsAdmin:           user.IsAdmin,
		CreatedAt:         user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:         user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}
