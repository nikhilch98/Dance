package auth

import (
	"context"
	"crypto/rand"
	"fmt"
	"nachna/core"
	"nachna/database"
	"nachna/models/mongodb"
	"nachna/models/request"
	"nachna/models/response"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type AuthServiceImpl struct {
	databaseImpl *database.MongoDBDatabaseImpl
	jwtSecret    []byte
}

var authServiceInstance *AuthServiceImpl
var authServiceLock = &sync.Mutex{}

func (AuthServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *AuthServiceImpl {
	if authServiceInstance == nil {
		authServiceLock.Lock()
		defer authServiceLock.Unlock()
		if authServiceInstance == nil {
			// Generate a secure JWT secret
			secret := make([]byte, 32)
			rand.Read(secret)

			authServiceInstance = &AuthServiceImpl{
				databaseImpl: databaseImpl,
				jwtSecret:    secret,
			}
		}
	}
	return authServiceInstance
}

// CreateAccessToken creates a JWT token for the user
func (a *AuthServiceImpl) CreateAccessToken(userID string, expirationDays int) (string, *core.NachnaException) {
	claims := jwt.MapClaims{
		"sub": userID,
		"iat": time.Now().Unix(),
		"exp": time.Now().AddDate(0, 0, expirationDays).Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(a.jwtSecret)
	if err != nil {
		return "", &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: "Failed to create access token",
			LogMessage:   err.Error(),
		}
	}

	return tokenString, nil
}

// VerifyToken verifies JWT token and returns user ID
func (a *AuthServiceImpl) VerifyToken(tokenString string) (string, *core.NachnaException) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return a.jwtSecret, nil
	})

	if err != nil {
		return "", &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "Invalid token",
			LogMessage:   err.Error(),
		}
	}

	if !token.Valid {
		return "", &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "Token is not valid",
		}
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "Invalid token claims",
		}
	}

	userID, ok := claims["sub"].(string)
	if !ok {
		return "", &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "Invalid user ID in token",
		}
	}

	return userID, nil
}

// SendOTP sends OTP to mobile number (mock implementation)
func (a *AuthServiceImpl) SendOTP(req *request.SendOTPRequest) (*response.SendOTPResponse, *core.NachnaException) {
	// For test number, return success immediately
	if req.MobileNumber == "9999999999" {
		return &response.SendOTPResponse{
			Success:      true,
			Message:      "OTP is being sent to your mobile number",
			MobileNumber: req.MobileNumber,
		}, nil
	}

	// Validate mobile number format
	if len(req.MobileNumber) != 10 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid mobile number format",
		}
	}

	// In production, integrate with Twilio or other SMS service
	// For now, return success (OTP would be sent in background)

	return &response.SendOTPResponse{
		Success:      true,
		Message:      "OTP is being sent to your mobile number",
		MobileNumber: req.MobileNumber,
	}, nil
}

// VerifyOTP verifies OTP and logs in/registers user
func (a *AuthServiceImpl) VerifyOTP(req *request.VerifyOTPRequest) (*response.AuthResponse, *core.NachnaException) {
	// For test credentials, skip OTP verification
	if req.MobileNumber != "9999999999" && req.OTP != "583647" {
		// In production, verify OTP with Twilio or other service
		// For now, accept any OTP for non-test numbers
	}

	// Create or get user
	user, err := a.CreateOrGetUser(req.MobileNumber)
	if err != nil {
		return nil, err
	}

	// Create access token (30 days)
	accessToken, err := a.CreateAccessToken(user.ID.(string), 30)
	if err != nil {
		return nil, err
	}

	userProfile := response.FormatUserProfile(user)

	return &response.AuthResponse{
		AccessToken: accessToken,
		TokenType:   "bearer",
		User:        userProfile,
	}, nil
}

// CreateOrGetUser creates a new user or returns existing user
func (a *AuthServiceImpl) CreateOrGetUser(mobileNumber string) (*mongodb.User, *core.NachnaException) {
	ctx := context.Background()

	// Try to get existing user
	user, err := a.databaseImpl.GetUserByMobileNumber(ctx, mobileNumber)
	if err == nil {
		return user, nil
	}

	// User doesn't exist, create new user
	now := time.Now()
	newUser := &mongodb.User{
		MobileNumber: mobileNumber,
		IsAdmin:      false,
		CreatedAt:    now,
		UpdatedAt:    now,
		IsDeleted:    false,
	}

	err = a.databaseImpl.CreateUser(ctx, newUser)
	if err != nil {
		return nil, err
	}

	// Return the created user
	return a.databaseImpl.GetUserByMobileNumber(ctx, mobileNumber)
}

// GetUserProfile gets user profile by ID
func (a *AuthServiceImpl) GetUserProfile(userID string) (*response.UserProfile, *core.NachnaException) {
	ctx := context.Background()

	user, err := a.databaseImpl.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	userProfile := response.FormatUserProfile(user)
	return &userProfile, nil
}

// UpdateUserProfile updates user profile
func (a *AuthServiceImpl) UpdateUserProfile(userID string, req *request.ProfileUpdateRequest) (*response.UserProfile, *core.NachnaException) {
	ctx := context.Background()

	// Get current user to verify it exists
	_, err := a.databaseImpl.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Update user profile
	err = a.databaseImpl.UpdateUserProfile(ctx, userID, req)
	if err != nil {
		return nil, err
	}

	// Return updated profile
	updatedUser, err := a.databaseImpl.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	userProfile := response.FormatUserProfile(updatedUser)
	return &userProfile, nil
}

// DeleteAccount deletes user account
func (a *AuthServiceImpl) DeleteAccount(userID string) *core.NachnaException {
	ctx := context.Background()
	return a.databaseImpl.DeleteUserAccount(ctx, userID)
}

// VerifyAdminUser verifies if user is admin
func (a *AuthServiceImpl) VerifyAdminUser(userID string) *core.NachnaException {
	ctx := context.Background()

	user, err := a.databaseImpl.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}

	if !user.IsAdmin {
		return &core.NachnaException{
			StatusCode:   403,
			ErrorMessage: "Admin access required",
		}
	}

	return nil
}
