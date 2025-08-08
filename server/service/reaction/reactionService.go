package reaction

import (
	"context"
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/models/response"
	"sync"
)

type ReactionServiceImpl struct {
	databaseImpl *database.MongoDBDatabaseImpl
}

var reactionServiceInstance *ReactionServiceImpl
var reactionServiceLock = &sync.Mutex{}

func (ReactionServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *ReactionServiceImpl {
	if reactionServiceInstance == nil {
		reactionServiceLock.Lock()
		defer reactionServiceLock.Unlock()
		if reactionServiceInstance == nil {
			reactionServiceInstance = &ReactionServiceImpl{
				databaseImpl: databaseImpl,
			}
		}
	}
	return reactionServiceInstance
}

// CreateOrUpdateReaction creates or updates a user reaction
func (r *ReactionServiceImpl) CreateOrUpdateReaction(userID string, req *request.ReactionRequest) (*response.ReactionResponse, *core.NachnaException) {
	ctx := context.Background()

	reaction, err := r.databaseImpl.CreateOrUpdateReaction(ctx, userID, req.EntityID, req.EntityType, req.Reaction)
	if err != nil {
		return nil, err
	}

	return &response.ReactionResponse{
		ID:         reaction.ID.(string),
		UserID:     reaction.UserID,
		EntityID:   reaction.EntityID,
		EntityType: reaction.EntityType,
		Reaction:   reaction.Reaction,
		CreatedAt:  reaction.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:  reaction.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
		IsDeleted:  reaction.IsDeleted,
	}, nil
}

// SoftDeleteReaction soft deletes a user reaction by ID
func (r *ReactionServiceImpl) SoftDeleteReaction(reactionID string, userID string) *core.NachnaException {
	ctx := context.Background()
	return r.databaseImpl.SoftDeleteReaction(ctx, reactionID, userID)
}

// SoftDeleteReactionByEntity soft deletes a user reaction by entity and reaction type
func (r *ReactionServiceImpl) SoftDeleteReactionByEntity(userID string, entityID string, entityType string, reactionType string) *core.NachnaException {
	ctx := context.Background()
	return r.databaseImpl.SoftDeleteReactionByEntity(ctx, userID, entityID, entityType, reactionType)
}

// GetUserReactions gets all reactions for a user
func (r *ReactionServiceImpl) GetUserReactions(userID string) (*response.UserReactionsResponse, *core.NachnaException) {
	ctx := context.Background()
	return r.databaseImpl.GetUserReactions(ctx, userID)
}

// GetReactionStats gets reaction statistics for an entity
func (r *ReactionServiceImpl) GetReactionStats(entityID string, entityType string) (*response.ReactionStatsResponse, *core.NachnaException) {
	ctx := context.Background()
	return r.databaseImpl.GetReactionStats(ctx, entityID, entityType)
}

// CheckRateLimit checks if user can perform reaction (simple rate limiting)
func (r *ReactionServiceImpl) CheckRateLimit(userID string, action string) bool {
	// Simple rate limiting implementation
	// In production, this would use Redis or similar for proper rate limiting
	// For now, return true (allow all actions)
	return true
}

// GetNotifiedUsersOfArtist gets users who are following an artist (for notifications)
func (r *ReactionServiceImpl) GetNotifiedUsersOfArtist(artistID string) ([]string, *core.NachnaException) {
	ctx := context.Background()
	return r.databaseImpl.GetUsersWhoReacted(ctx, artistID, "artist", "notify")
}

// GetTotalReactionCount gets total count of reactions by type and entity type
func (r *ReactionServiceImpl) GetTotalReactionCount(reactionType string, entityType string) (int64, *core.NachnaException) {
	ctx := context.Background()
	return r.databaseImpl.GetTotalReactionCount(ctx, reactionType, entityType)
}
