package api

import (
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/service/reaction"
	"nachna/utils"
	"net/http"
	"strings"
)

func GetReactionService() (*reaction.ReactionServiceImpl, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	reactionService := reaction.ReactionServiceImpl{}.GetInstance(databaseImpl)
	return reactionService, nil
}

func CreateReaction(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	reactionRequest := &request.ReactionRequest{}
	err := reactionRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	reactionService, err := GetReactionService()
	if err != nil {
		return nil, err
	}

	// Check rate limit
	if !reactionService.CheckRateLimit(userID, "create_reaction") {
		return nil, &core.NachnaException{
			StatusCode:   429,
			ErrorMessage: "Too many requests. Please try again later.",
		}
	}

	return reactionService.CreateOrUpdateReaction(userID, reactionRequest)
}

func RemoveReaction(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	reactionDeleteRequest := &request.ReactionDeleteRequest{}
	err := reactionDeleteRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	reactionService, err := GetReactionService()
	if err != nil {
		return nil, err
	}

	// Check rate limit
	if !reactionService.CheckRateLimit(userID, "remove_reaction") {
		return nil, &core.NachnaException{
			StatusCode:   429,
			ErrorMessage: "Too many requests. Please try again later.",
		}
	}

	err = reactionService.SoftDeleteReaction(reactionDeleteRequest.ReactionID, userID)
	if err != nil {
		return nil, err
	}

	return map[string]string{"message": "Reaction removed successfully"}, nil
}

func RemoveReactionByEntity(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Get query parameters
	entityID := r.URL.Query().Get("entity_id")
	entityType := r.URL.Query().Get("entity_type")
	reactionType := r.URL.Query().Get("reaction_type")

	if entityID == "" || entityType == "" || reactionType == "" {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "entity_id, entity_type, and reaction_type are required",
		}
	}

	reactionService, err := GetReactionService()
	if err != nil {
		return nil, err
	}

	// Check rate limit
	if !reactionService.CheckRateLimit(userID, "remove_reaction") {
		return nil, &core.NachnaException{
			StatusCode:   429,
			ErrorMessage: "Too many requests. Please try again later.",
		}
	}

	err = reactionService.SoftDeleteReactionByEntity(userID, entityID, entityType, reactionType)
	if err != nil {
		return nil, err
	}

	return map[string]string{"message": "Reaction removed successfully"}, nil
}

func GetUserReactions(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	reactionService, err := GetReactionService()
	if err != nil {
		return nil, err
	}

	// Check rate limit
	if !reactionService.CheckRateLimit(userID, "get_user_reactions") {
		return nil, &core.NachnaException{
			StatusCode:   429,
			ErrorMessage: "Too many requests. Please try again later.",
		}
	}

	return reactionService.GetUserReactions(userID)
}

func GetReactionStats(r *http.Request) (any, *core.NachnaException) {
	// Extract user ID from auth token for authentication
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		return nil, &core.NachnaException{
			StatusCode:   401,
			ErrorMessage: "User authentication required",
		}
	}

	// Extract entity type and ID from URL path
	pathParts := strings.Split(r.URL.Path, "/")
	if len(pathParts) < 5 {
		return nil, &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid URL format",
		}
	}

	entityType := pathParts[len(pathParts)-2]
	entityID := pathParts[len(pathParts)-1]

	reactionService, err := GetReactionService()
	if err != nil {
		return nil, err
	}

	return reactionService.GetReactionStats(entityID, entityType)
}

func init() {
	// Reaction APIs
	Router.HandleFunc(utils.MakeHandler("/reactions", CreateReaction, "user")).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/reactions", RemoveReaction, "user")).Methods(http.MethodDelete)
	Router.HandleFunc(utils.MakeHandler("/reactions/by-entity", RemoveReactionByEntity, "user")).Methods(http.MethodDelete)
	Router.HandleFunc(utils.MakeHandler("/user/reactions", GetUserReactions, "user")).Methods(http.MethodGet)
	Router.HandleFunc(utils.MakeHandler("/reactions/stats/{entity_type}/{entity_id}", GetReactionStats, "user")).Methods(http.MethodGet)
}
