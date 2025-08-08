package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"
	"nachna/models/response"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// Reaction-related operations

// CreateOrUpdateReaction creates or updates a user reaction
func (m *MongoDBDatabaseImpl) CreateOrUpdateReaction(ctx context.Context, userID string, entityID string, entityType string, reaction string) (*mongodb.Reaction, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Check if reaction already exists
	filter := bson.M{
		"user_id":     userID,
		"entity_id":   entityID,
		"entity_type": entityType,
		"reaction":    reaction,
	}

	var existingReaction mongodb.Reaction
	err := m.database.Collection("reactions").FindOne(ctx, filter).Decode(&existingReaction)

	now := time.Now()

	if err != nil {
		// Create new reaction
		newReaction := &mongodb.Reaction{
			UserID:     userID,
			EntityID:   entityID,
			EntityType: entityType,
			Reaction:   reaction,
			IsDeleted:  false,
			CreatedAt:  now,
			UpdatedAt:  now,
		}

		result, insertErr := m.database.Collection("reactions").InsertOne(ctx, newReaction)
		if insertErr != nil {
			return nil, &core.NachnaException{
				LogMessage:   insertErr.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to create reaction",
			}
		}

		newReaction.ID = result.InsertedID
		return newReaction, nil
	} else {
		// Update existing reaction (undelete if it was deleted)
		update := bson.M{
			"$set": bson.M{
				"is_deleted": false,
				"updated_at": now,
			},
		}

		_, updateErr := m.database.Collection("reactions").UpdateOne(ctx, bson.M{"_id": existingReaction.ID}, update)
		if updateErr != nil {
			return nil, &core.NachnaException{
				LogMessage:   updateErr.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to update reaction",
			}
		}

		existingReaction.IsDeleted = false
		existingReaction.UpdatedAt = now
		return &existingReaction, nil
	}
}

// SoftDeleteReaction soft deletes a reaction by ID
func (m *MongoDBDatabaseImpl) SoftDeleteReaction(ctx context.Context, reactionID string, userID string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	objectID, err := primitive.ObjectIDFromHex(reactionID)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid reaction ID format",
			LogMessage:   err.Error(),
		}
	}

	filter := bson.M{
		"_id":     objectID,
		"user_id": userID, // Ensure user can only delete their own reactions
	}

	update := bson.M{
		"$set": bson.M{
			"is_deleted": true,
			"updated_at": time.Now(),
		},
	}

	result, err := m.database.Collection("reactions").UpdateOne(ctx, filter, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to delete reaction",
		}
	}

	if result.MatchedCount == 0 {
		return &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Reaction not found or already deleted",
		}
	}

	return nil
}

// SoftDeleteReactionByEntity soft deletes a reaction by entity and reaction type
func (m *MongoDBDatabaseImpl) SoftDeleteReactionByEntity(ctx context.Context, userID string, entityID string, entityType string, reactionType string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"user_id":     userID,
		"entity_id":   entityID,
		"entity_type": entityType,
		"reaction":    reactionType,
		"is_deleted":  false,
	}

	update := bson.M{
		"$set": bson.M{
			"is_deleted": true,
			"updated_at": time.Now(),
		},
	}

	result, err := m.database.Collection("reactions").UpdateOne(ctx, filter, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to delete reaction",
		}
	}

	if result.MatchedCount == 0 {
		return &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Reaction not found or already deleted",
		}
	}

	return nil
}

// GetUserReactions gets all reactions for a user
func (m *MongoDBDatabaseImpl) GetUserReactions(ctx context.Context, userID string) (*response.UserReactionsResponse, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Get all non-deleted reactions for the user
	filter := bson.M{
		"user_id":    userID,
		"is_deleted": false,
	}

	cursor, err := m.database.Collection("reactions").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve user reactions",
		}
	}
	defer cursor.Close(ctx)

	var likedArtists []string
	var followedArtists []string
	var likedWorkshops []string
	var likedStudios []string

	for cursor.Next(ctx) {
		var reaction mongodb.Reaction
		if err := cursor.Decode(&reaction); err != nil {
			continue
		}

		switch reaction.EntityType {
		case "artist":
			if reaction.Reaction == "like" {
				likedArtists = append(likedArtists, reaction.EntityID)
			} else if reaction.Reaction == "notify" {
				followedArtists = append(followedArtists, reaction.EntityID)
			}
		case "workshop":
			if reaction.Reaction == "like" {
				likedWorkshops = append(likedWorkshops, reaction.EntityID)
			}
		case "studio":
			if reaction.Reaction == "like" {
				likedStudios = append(likedStudios, reaction.EntityID)
			}
		}
	}

	return &response.UserReactionsResponse{
		LikedArtists:    likedArtists,
		FollowedArtists: followedArtists,
		LikedWorkshops:  likedWorkshops,
		LikedStudios:    likedStudios,
	}, nil
}

// GetReactionStats gets reaction statistics for an entity
func (m *MongoDBDatabaseImpl) GetReactionStats(ctx context.Context, entityID string, entityType string) (*response.ReactionStatsResponse, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Count likes
	likeFilter := bson.M{
		"entity_id":   entityID,
		"entity_type": entityType,
		"reaction":    "like",
		"is_deleted":  false,
	}

	likeCount, err := m.database.Collection("reactions").CountDocuments(ctx, likeFilter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to count likes",
		}
	}

	// Count follows (notify reactions)
	followFilter := bson.M{
		"entity_id":   entityID,
		"entity_type": entityType,
		"reaction":    "notify",
		"is_deleted":  false,
	}

	followCount, err := m.database.Collection("reactions").CountDocuments(ctx, followFilter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to count follows",
		}
	}

	return &response.ReactionStatsResponse{
		EntityID:    entityID,
		EntityType:  entityType,
		LikeCount:   likeCount,
		FollowCount: followCount,
	}, nil
}

// GetTotalReactionCount gets total count of reactions by type
func (m *MongoDBDatabaseImpl) GetTotalReactionCount(ctx context.Context, reactionType string, entityType string) (int64, *core.NachnaException) {
	if m.database == nil {
		return 0, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"reaction":    reactionType,
		"entity_type": entityType,
		"is_deleted":  false,
	}

	count, err := m.database.Collection("reactions").CountDocuments(ctx, filter)
	if err != nil {
		return 0, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to count reactions",
		}
	}

	return count, nil
}

// GetUsersWhoReacted gets users who reacted to an entity with a specific reaction type
func (m *MongoDBDatabaseImpl) GetUsersWhoReacted(ctx context.Context, entityID string, entityType string, reactionType string) ([]string, *core.NachnaException) {
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

	var userIDs []string
	for cursor.Next(ctx) {
		var reaction mongodb.Reaction
		if err := cursor.Decode(&reaction); err != nil {
			continue
		}
		userIDs = append(userIDs, reaction.UserID)
	}

	return userIDs, nil
}
