package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"

	"dance_api_go/src/config"
	"dance_api_go/src/types"
)

// AdminListStudiosHandler handles the GET /admin/api/studios endpoint
func AdminListStudiosHandler() types.GenericResponse {
	ctx := context.Background()

	var studios []map[string]interface{}
	cursor, err := config.DB.Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &studios); err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Error parsing studios",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       studios,
	}
}

// AdminCreateStudioHandler handles the POST /admin/api/studios endpoint
func AdminCreateStudioHandler(r *http.Request) types.GenericResponse {
	var studio map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&studio); err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusBadRequest,
			Success:    false,
			Error:      "Invalid request body",
		}
	}

	_, err := config.DB.Collection("studios").InsertOne(context.Background(), studio)
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
	}
}

// AdminUpdateStudioHandler handles the PUT /admin/api/studios/{studioId} endpoint
func AdminUpdateStudioHandler(r *http.Request) types.GenericResponse {
	vars := mux.Vars(r)
	studioID := vars["studioId"]

	var studio map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&studio); err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusBadRequest,
			Success:    false,
			Error:      "Invalid request body",
		}
	}

	_, err := config.DB.Collection("studios").UpdateOne(
		context.Background(),
		bson.M{"studio_id": studioID},
		bson.M{"$set": studio},
	)
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
	}
}

// AdminDeleteStudioHandler handles the DELETE /admin/api/studios/{studioId} endpoint
func AdminDeleteStudioHandler(r *http.Request) types.GenericResponse {
	vars := mux.Vars(r)
	studioID := vars["studioId"]

	_, err := config.DB.Collection("studios").DeleteOne(
		context.Background(),
		bson.M{"studio_id": studioID},
	)
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
	}
}

// Placeholder handlers for other admin endpoints
func AdminListArtistsHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminCreateArtistHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminUpdateArtistHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminDeleteArtistHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminListWorkshopsHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminCreateWorkshopHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminUpdateWorkshopHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

func AdminDeleteWorkshopHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}
