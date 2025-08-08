package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"

	"go.mongodb.org/mongo-driver/bson"
)

// Notification-related operations

// CreateNotification creates a new notification record
func (m *MongoDBDatabaseImpl) CreateNotification(ctx context.Context, notification *mongodb.Notification) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	result, err := m.database.Collection("notifications").InsertOne(ctx, notification)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to create notification",
		}
	}

	// Set the generated ID
	notification.ID = result.InsertedID
	return nil
}

// GetAllActiveDeviceTokens retrieves all active device tokens
func (m *MongoDBDatabaseImpl) GetAllActiveDeviceTokens(ctx context.Context) ([]*mongodb.DeviceToken, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	cursor, err := m.database.Collection("device_tokens").Find(ctx, bson.M{"is_active": true})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve device tokens",
		}
	}
	defer cursor.Close(ctx)

	var tokens []*mongodb.DeviceToken
	for cursor.Next(ctx) {
		var token mongodb.DeviceToken
		if err := cursor.Decode(&token); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode device token",
			}
		}
		tokens = append(tokens, &token)
	}

	return tokens, nil
}

// GetDeviceTokensForUsers retrieves device tokens for specific users
func (m *MongoDBDatabaseImpl) GetDeviceTokensForUsers(ctx context.Context, userIDs []string) ([]*mongodb.DeviceToken, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"user_id":   bson.M{"$in": userIDs},
		"is_active": true,
	}

	cursor, err := m.database.Collection("device_tokens").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve device tokens",
		}
	}
	defer cursor.Close(ctx)

	var tokens []*mongodb.DeviceToken
	for cursor.Next(ctx) {
		var token mongodb.DeviceToken
		if err := cursor.Decode(&token); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode device token",
			}
		}
		tokens = append(tokens, &token)
	}

	return tokens, nil
}

// Reaction-related operations

// GetReactionsForEntity retrieves reactions for a specific entity
func (m *MongoDBDatabaseImpl) GetReactionsForEntity(ctx context.Context, entityID string, entityType string, reactionType string) ([]*mongodb.Reaction, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"entity_id":   entityID,
		"entity_type": entityType,
		"reaction":    reactionType,
		"is_deleted":  false,
	}

	cursor, err := m.database.Collection("reactions").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve reactions",
		}
	}
	defer cursor.Close(ctx)

	var reactions []*mongodb.Reaction
	for cursor.Next(ctx) {
		var reaction mongodb.Reaction
		if err := cursor.Decode(&reaction); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode reaction",
			}
		}
		reactions = append(reactions, &reaction)
	}

	return reactions, nil
}

// GetArtistByID retrieves an artist by their ID
func (m *MongoDBDatabaseImpl) GetArtistByID(ctx context.Context, artistID string) (*mongodb.Artist, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	var artist mongodb.Artist
	err := m.database.Collection("artists_v2").FindOne(ctx, bson.M{"artist_id": artistID}).Decode(&artist)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   404,
			ErrorMessage: "Artist not found",
		}
	}

	return &artist, nil
}
