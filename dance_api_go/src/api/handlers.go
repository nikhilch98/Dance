package api

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"

	"dance_api_go/src/config"
	"dance_api_go/src/types"
)

// respondWithJSON is a helper function to send JSON responses
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

// respondWithError is a helper function to send error responses
func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, types.Response{
		Success: false,
		Error:   message,
	})
}

// GetWorkshops handles the GET /api/workshops endpoint
func GetWorkshops(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	var workshops []types.Workshop
	cursor, err := config.DB.Collection("workshops_v2").Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &workshops); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Error parsing workshops")
		return
	}

	respondWithJSON(w, http.StatusOK, workshops)
}

// GetStudios handles the GET /api/studios endpoint
func GetStudios(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	var studios []types.Studio
	cursor, err := config.DB.Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &studios); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Error parsing studios")
		return
	}

	respondWithJSON(w, http.StatusOK, studios)
}

// GetArtists handles the GET /api/artists endpoint
func GetArtists(w http.ResponseWriter, r *http.Request) {
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
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &artists); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Error parsing artists")
		return
	}

	respondWithJSON(w, http.StatusOK, artists)
}

// Admin handlers

// AdminListStudios handles the GET /admin/api/studios endpoint
func AdminListStudios(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	var studios []map[string]interface{}
	cursor, err := config.DB.Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}
	defer cursor.Close(ctx)

	if err := cursor.All(ctx, &studios); err != nil {
		respondWithError(w, http.StatusInternalServerError, "Error parsing studios")
		return
	}

	respondWithJSON(w, http.StatusOK, studios)
}

// AdminCreateStudio handles the POST /admin/api/studios endpoint
func AdminCreateStudio(w http.ResponseWriter, r *http.Request) {
	var studio map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&studio); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	_, err := config.DB.Collection("studios").InsertOne(context.Background(), studio)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}

	respondWithJSON(w, http.StatusOK, types.Response{Success: true})
}

// AdminUpdateStudio handles the PUT /admin/api/studios/{studioId} endpoint
func AdminUpdateStudio(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	studioID := vars["studioId"]

	var studio map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&studio); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	_, err := config.DB.Collection("studios").UpdateOne(
		context.Background(),
		bson.M{"studio_id": studioID},
		bson.M{"$set": studio},
	)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}

	respondWithJSON(w, http.StatusOK, types.Response{Success: true})
}

// AdminDeleteStudio handles the DELETE /admin/api/studios/{studioId} endpoint
func AdminDeleteStudio(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	studioID := vars["studioId"]

	_, err := config.DB.Collection("studios").DeleteOne(
		context.Background(),
		bson.M{"studio_id": studioID},
	)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, "Database error")
		return
	}

	respondWithJSON(w, http.StatusOK, types.Response{Success: true})
}

// Placeholder handlers
func GetWorkshopsByArtist(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func GetWorkshopsByStudio(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminListArtists(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminCreateArtist(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminUpdateArtist(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminDeleteArtist(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminListWorkshops(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminCreateWorkshop(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminUpdateWorkshop(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}

func AdminDeleteWorkshop(w http.ResponseWriter, r *http.Request) {
	respondWithJSON(w, http.StatusOK, types.Response{Success: true, Data: "Not implemented"})
}
