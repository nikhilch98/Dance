package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"
	"nachna/models/request"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// User-related operations

// CreateUser creates a new user in the database
func (m *MongoDBDatabaseImpl) CreateUser(ctx context.Context, user *mongodb.User) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	result, err := m.database.Collection("users").InsertOne(ctx, user)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to create user",
		}
	}

	// Set the generated ID
	user.ID = result.InsertedID
	return nil
}

// GetUserByID retrieves a user by their ID
func (m *MongoDBDatabaseImpl) GetUserByID(ctx context.Context, userID string) (*mongodb.User, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var user mongodb.User
	err := m.database.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, &core.NachnaException{
				LogMessage:   "user not found",
				StatusCode:   404,
				ErrorMessage: "User not found",
			}
		}
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve user",
		}
	}
	return &user, nil
}

// GetUserByMobileNumber retrieves a user by their mobile number
func (m *MongoDBDatabaseImpl) GetUserByMobileNumber(ctx context.Context, mobileNumber string) (*mongodb.User, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var user mongodb.User
	err := m.database.Collection("users").FindOne(ctx, bson.M{"mobile_number": mobileNumber, "is_deleted": false}).Decode(&user)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, &core.NachnaException{
				LogMessage:   "user not found",
				StatusCode:   404,
				ErrorMessage: "User not found",
			}
		}
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve user",
		}
	}
	return &user, nil
}

// UpdateUserProfile updates user profile information
func (m *MongoDBDatabaseImpl) UpdateUserProfile(ctx context.Context, userID string, req *request.ProfileUpdateRequest) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Prepare update data
	updateData := bson.M{
		"updated_at": time.Now(),
	}

	if req.Name != nil {
		updateData["name"] = *req.Name
	}
	if req.DateOfBirth != nil {
		updateData["date_of_birth"] = *req.DateOfBirth
	}
	if req.Gender != nil {
		updateData["gender"] = *req.Gender
	}

	update := bson.M{"$set": updateData}

	_, err := m.database.Collection("users").UpdateOne(ctx, bson.M{"_id": userID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to update user profile",
		}
	}
	return nil
}

// DeleteUserAccount soft deletes a user account
func (m *MongoDBDatabaseImpl) DeleteUserAccount(ctx context.Context, userID string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	update := bson.M{
		"$set": bson.M{
			"is_deleted": true,
			"updated_at": time.Now(),
		},
	}

	_, err := m.database.Collection("users").UpdateOne(ctx, bson.M{"_id": userID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to delete user account",
		}
	}
	return nil
}

// Device token operations

// RegisterDeviceToken registers or updates a device token for a user
func (m *MongoDBDatabaseImpl) RegisterDeviceToken(ctx context.Context, userID string, deviceToken string, platform string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	now := time.Now()
	deviceTokenDoc := &mongodb.DeviceToken{
		UserID:      userID,
		DeviceToken: deviceToken,
		Platform:    platform,
		IsActive:    true,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	_, err := m.database.Collection("device_tokens").ReplaceOne(
		ctx,
		bson.M{"user_id": userID},
		deviceTokenDoc,
		options.Replace().SetUpsert(true),
	)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to register device token",
		}
	}
	return nil
}

// GetDeviceToken gets device token for a user
func (m *MongoDBDatabaseImpl) GetDeviceToken(ctx context.Context, userID string) (string, *core.NachnaException) {
	if m.database == nil {
		return "", &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var deviceToken mongodb.DeviceToken
	err := m.database.Collection("device_tokens").FindOne(ctx, bson.M{"user_id": userID, "is_active": true}).Decode(&deviceToken)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return "", nil // No token found, return empty string
		}
		return "", &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve device token",
		}
	}
	return deviceToken.DeviceToken, nil
}

// Profile picture operations

// SaveProfilePicture saves a profile picture to MongoDB
func (m *MongoDBDatabaseImpl) SaveProfilePicture(ctx context.Context, userID string, imageData []byte, contentType string, filename string) (string, *core.NachnaException) {
	if m.database == nil {
		return "", &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	profilePicture := &mongodb.ProfilePicture{
		UserID:      userID,
		ImageData:   imageData,
		ContentType: contentType,
		Filename:    filename,
		Size:        int64(len(imageData)),
		CreatedAt:   time.Now(),
	}

	result, err := m.database.Collection("profile_pictures").ReplaceOne(
		ctx,
		bson.M{"user_id": userID},
		profilePicture,
		options.Replace().SetUpsert(true),
	)
	if err != nil {
		return "", &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to save profile picture",
		}
	}

	// Return the ID as string
	if result.UpsertedID != nil {
		return result.UpsertedID.(string), nil
	}

	// If it was an update, find the document to get its ID
	var pic mongodb.ProfilePicture
	err = m.database.Collection("profile_pictures").FindOne(ctx, bson.M{"user_id": userID}).Decode(&pic)
	if err != nil {
		return "", &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve profile picture ID",
		}
	}

	return pic.ID.(string), nil
}

// GetProfilePicture retrieves a profile picture from MongoDB
func (m *MongoDBDatabaseImpl) GetProfilePicture(ctx context.Context, userID string) (*mongodb.ProfilePicture, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var profilePicture mongodb.ProfilePicture
	err := m.database.Collection("profile_pictures").FindOne(ctx, bson.M{"user_id": userID}).Decode(&profilePicture)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, &core.NachnaException{
				LogMessage:   "profile picture not found",
				StatusCode:   404,
				ErrorMessage: "Profile picture not found",
			}
		}
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve profile picture",
		}
	}
	return &profilePicture, nil
}

// DeleteProfilePicture removes a profile picture from MongoDB
func (m *MongoDBDatabaseImpl) DeleteProfilePicture(ctx context.Context, userID string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	_, err := m.database.Collection("profile_pictures").DeleteOne(ctx, bson.M{"user_id": userID})
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to delete profile picture",
		}
	}
	return nil
}

// UpdateUserProfilePictureInfo updates user profile picture references
func (m *MongoDBDatabaseImpl) UpdateUserProfilePictureInfo(ctx context.Context, userID string, pictureID string, imageURL string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	update := bson.M{
		"$set": bson.M{
			"profile_picture_id":  pictureID,
			"profile_picture_url": imageURL,
			"updated_at":          time.Now(),
		},
	}

	_, err := m.database.Collection("users").UpdateOne(ctx, bson.M{"_id": userID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to update user profile picture info",
		}
	}
	return nil
}

// RemoveUserProfilePictureInfo removes profile picture references from user
func (m *MongoDBDatabaseImpl) RemoveUserProfilePictureInfo(ctx context.Context, userID string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	update := bson.M{
		"$unset": bson.M{
			"profile_picture_id":  "",
			"profile_picture_url": "",
		},
		"$set": bson.M{
			"updated_at": time.Now(),
		},
	}

	_, err := m.database.Collection("users").UpdateOne(ctx, bson.M{"_id": userID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to remove user profile picture info",
		}
	}
	return nil
}
