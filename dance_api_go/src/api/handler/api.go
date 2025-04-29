package handler

import (
	"context"
	"net/http"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"

	"dance_api_go/src/config"
	"dance_api_go/src/types"
)

// GetWorkshopsHandler handles the GET /api/workshops endpoint
func GetWorkshopsHandler() types.GenericResponse {
	ctx := context.Background()

	var workshops []types.Workshop
	cursor, err := config.DB.Collection("workshops_v2").Find(ctx, bson.M{})
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &workshops); err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Error parsing workshops",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       workshops,
	}
}

// GetStudiosHandler handles the GET /api/studios endpoint
func GetStudiosHandler() types.GenericResponse {
	ctx := context.Background()

	var studios []types.Studio
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

// GetArtistsHandler handles the GET /api/artists endpoint
func GetArtistsHandler() types.GenericResponse {
	ctx := context.Background()

	pipeline := mongo.Pipeline{
		{{Key: "$lookup", Value: bson.D{
			{Key: "from", Value: "workshops_v2"},
			{Key: "let", Value: bson.D{{Key: "artistId", Value: "$artist_id"}}},
			{Key: "pipeline", Value: bson.A{
				bson.D{{Key: "$match", Value: bson.D{{Key: "$expr", Value: bson.D{{Key: "$in", Value: bson.A{"$$artistId", "$workshop_details.artist_id"}}}}}}},
			}},
			{Key: "as", Value: "matchingWorkshops"},
		}}},
		{{Key: "$match", Value: bson.D{{Key: "matchingWorkshops", Value: bson.D{{Key: "$ne", Value: bson.A{}}}}}}},
		{{Key: "$project", Value: bson.D{
			{Key: "_id", Value: 0},
			{Key: "artist_id", Value: 1},
			{Key: "artist_name", Value: 1},
			{Key: "image_url", Value: 1},
			{Key: "instagram_link", Value: 1},
		}}},
	}

	var artists []types.Artist
	cursor, err := config.DB.Collection("artists_v2").Aggregate(ctx, pipeline)
	if err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Database error",
		}
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &artists); err != nil {
		return types.GenericResponse{
			StatusCode: http.StatusInternalServerError,
			Success:    false,
			Error:      "Error parsing artists",
		}
	}

	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       artists,
	}
}

// GetWorkshopsByArtistHandler handles the GET /api/workshops_by_artist/{artistId} endpoint
func GetWorkshopsByArtistHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}

// GetWorkshopsByStudioHandler handles the GET /api/workshops_by_studio/{studioId} endpoint
func GetWorkshopsByStudioHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data:       "Not implemented",
	}
}
