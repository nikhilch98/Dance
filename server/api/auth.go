package api

import (
	"bytes"
	"context"
	"crypto/rand"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/models/response"
	"nachna/service/auth"
	"nachna/utils"
	"net/http"
	"strings"

	_ "image/gif"
	_ "image/png"

	"github.com/nfnt/resize"
)

func GetAuthService() (*auth.AuthServiceImpl, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	authService := auth.AuthServiceImpl{}.GetInstance(databaseImpl)
	return authService, nil
}

func SendOTP(r *http.Request) (any, *core.NachnaException) {
	sendOTPRequest := &request.SendOTPRequest{}
	err := sendOTPRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	authService, err := GetAuthService()
	if err != nil {
		return nil, err
	}

	return authService.SendOTP(sendOTPRequest)
}

func VerifyOTP(r *http.Request) (any, *core.NachnaException) {
	verifyOTPRequest := &request.VerifyOTPRequest{}
	err := verifyOTPRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	authService, err := GetAuthService()
	if err != nil {
		return nil, err
	}

	return authService.VerifyOTP(verifyOTPRequest)
}

func GetProfile(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	authService, err := GetAuthService()
	if err != nil {
		return nil, err
	}

	return authService.GetUserProfile(userID)
}

func UpdateProfile(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	profileUpdateRequest := &request.ProfileUpdateRequest{}
	err := profileUpdateRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	authService, err := GetAuthService()
	if err != nil {
		return nil, err
	}

	return authService.UpdateUserProfile(userID, profileUpdateRequest)
}

func UploadProfilePicture(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Parse multipart form
	err := r.ParseMultipartForm(5 * 1024 * 1024) // 5MB max
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Failed to parse multipart form",
			LogMessage:   err.Error(),
		}
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "No file provided",
			LogMessage:   err.Error(),
		}
	}
	defer file.Close()

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "File must be an image",
		}
	}

	// Read file content
	fileContent, err := io.ReadAll(file)
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to read file",
			LogMessage:   err.Error(),
		}
	}

	// Validate file size (max 5MB)
	if len(fileContent) > 5*1024*1024 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "File size must be less than 5MB",
		}
	}

	// Decode and process image
	img, _, err := image.Decode(bytes.NewReader(fileContent))
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid image format",
			LogMessage:   err.Error(),
		}
	}

	// Resize image to max 800x800 while maintaining aspect ratio
	resizedImg := resize.Thumbnail(800, 800, img, resize.Lanczos3)

	// Convert to JPEG
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, resizedImg, &jpeg.Options{Quality: 85})
	if err != nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to process image",
			LogMessage:   err.Error(),
		}
	}

	processedImageData := buf.Bytes()

	// Generate filename
	randBytes := make([]byte, 8)
	rand.Read(randBytes)
	filename := fmt.Sprintf("profile_%s_%x.jpg", userID, randBytes)

	// Get database instance
	databaseImpl, dbErr := database.MongoDBDatabaseImpl{}.GetInstance()
	if dbErr != nil {
		return nil, dbErr
	}

	ctx := context.Background()

	// Save image to MongoDB
	pictureID, dbErr := databaseImpl.SaveProfilePicture(ctx, userID, processedImageData, "image/jpeg", filename)
	if dbErr != nil {
		return nil, dbErr
	}

	// Create image URL
	imageURL := fmt.Sprintf("/api/profile-picture/%s", userID)

	// Update user profile with picture ID and URL
	dbErr = databaseImpl.UpdateUserProfilePictureInfo(ctx, userID, pictureID, imageURL)
	if dbErr != nil {
		// Clean up uploaded image if user update fails
		databaseImpl.DeleteProfilePicture(ctx, userID)
		return nil, dbErr
	}

	return response.ProfilePictureUploadResponse{
		Message:  "Profile picture uploaded successfully",
		ImageURL: imageURL,
	}, nil
}

func RemoveProfilePicture(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Get database instance
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}

	ctx := context.Background()

	// Remove profile picture from MongoDB
	err = databaseImpl.DeleteProfilePicture(ctx, userID)
	if err != nil {
		// Continue even if deletion fails, just remove references
	}

	// Remove profile picture references from user document
	err = databaseImpl.RemoveUserProfilePictureInfo(ctx, userID)
	if err != nil {
		return nil, err
	}

	return response.GenericResponse{
		Message: "Profile picture removed successfully",
	}, nil
}

func DeleteAccount(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	authService, err := GetAuthService()
	if err != nil {
		return nil, err
	}

	err = authService.DeleteAccount(userID)
	if err != nil {
		return nil, err
	}

	return response.GenericResponse{
		Message: "Account deleted successfully",
	}, nil
}

func GetConfig(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Get query parameters
	deviceToken := r.URL.Query().Get("device_token")
	platform := r.URL.Query().Get("platform")

	// Get database instance
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}

	ctx := context.Background()

	// Get user profile to check admin status
	user, err := databaseImpl.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Get current device token from database
	currentServerToken, _ := databaseImpl.GetDeviceToken(ctx, userID)

	// Initialize response data
	responseData := response.ConfigResponse{
		IsAdmin:         user.IsAdmin,
		DeviceToken:     currentServerToken,
		TokenSyncStatus: "no_sync_needed",
	}

	// If device token and platform are provided, perform sync
	if deviceToken != "" && platform != "" {
		if currentServerToken != deviceToken {
			// Tokens don't match, update server token
			err = databaseImpl.RegisterDeviceToken(ctx, userID, deviceToken, platform)
			if err == nil {
				responseData.DeviceToken = deviceToken
				responseData.TokenSyncStatus = "updated"
			} else {
				responseData.TokenSyncStatus = "update_failed"
			}
		} else {
			// Tokens match, no update needed
			responseData.TokenSyncStatus = "matched"
		}
	}

	return responseData, nil
}

func GetProfilePicture(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from URL path
	userID := r.URL.Path[len("/api/profile-picture/"):]
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "User ID is required",
		}
	}

	// Get database instance
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}

	ctx := context.Background()

	// Get profile picture from MongoDB
	profilePicture, err := databaseImpl.GetProfilePicture(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Return image data as HTTP response
	// Note: This would need to be handled differently in the actual HTTP handler
	// to set proper headers and content type
	return profilePicture, nil
}

func init() {
	// Authentication APIs
	Router.HandleFunc(utils.MakeHandler("/send-otp", SendOTP)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/verify-otp", VerifyOTP)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/profile", GetProfile, "user")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/profile", UpdateProfile, "user")).Methods(http.MethodPut)
	Router.HandleFunc(utils.MakeHandler("/profile-picture", UploadProfilePicture, "user")).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/profile-picture", RemoveProfilePicture, "user")).Methods(http.MethodDelete)
	Router.HandleFunc(utils.MakeHandler("/account", DeleteAccount, "user")).Methods(http.MethodDelete)
	Router.HandleFunc(utils.MakeHandler("/config", GetConfig, "user")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/profile-picture/{user_id}", GetProfilePicture)).Methods(http.MethodGet)
}
