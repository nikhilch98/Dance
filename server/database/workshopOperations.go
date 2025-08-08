package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"
	"nachna/models/response"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Workshop-related operations

// GetAllWorkshops retrieves all workshops
func (m *MongoDBDatabaseImpl) GetAllWorkshops(ctx context.Context) ([]*mongodb.Workshop, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, bson.M{})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve workshops",
		}
	}
	defer cursor.Close(ctx)

	var workshops []*mongodb.Workshop
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode workshop",
			}
		}
		workshops = append(workshops, &workshop)
	}

	return workshops, nil
}

// GetWorkshopsByStudio retrieves workshops for a specific studio
func (m *MongoDBDatabaseImpl) GetWorkshopsByStudio(ctx context.Context, studioID string) ([]*mongodb.Workshop, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, bson.M{"studio_id": studioID})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve workshops",
		}
	}
	defer cursor.Close(ctx)

	var workshops []*mongodb.Workshop
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode workshop",
			}
		}
		workshops = append(workshops, &workshop)
	}

	return workshops, nil
}

// GetWorkshopsByArtist retrieves workshops for a specific artist
func (m *MongoDBDatabaseImpl) GetWorkshopsByArtist(ctx context.Context, artistID string) ([]*mongodb.Workshop, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{"artist_id_list": bson.M{"$in": []string{artistID}}}
	cursor, err := m.database.Collection("workshops_v2").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve workshops",
		}
	}
	defer cursor.Close(ctx)

	var workshops []*mongodb.Workshop
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode workshop",
			}
		}
		workshops = append(workshops, &workshop)
	}

	return workshops, nil
}

// GetAllStudios retrieves all studios
func (m *MongoDBDatabaseImpl) GetAllStudios(ctx context.Context) ([]*mongodb.Studio, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	cursor, err := m.database.Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve studios",
		}
	}
	defer cursor.Close(ctx)

	var studios []*mongodb.Studio
	for cursor.Next(ctx) {
		var studio mongodb.Studio
		if err := cursor.Decode(&studio); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode studio",
			}
		}
		studios = append(studios, &studio)
	}

	return studios, nil
}

// GetAllArtistsFromDB retrieves all artists with optional workshop filter
func (m *MongoDBDatabaseImpl) GetAllArtistsFromDB(ctx context.Context, hasWorkshops *bool) ([]*mongodb.Artist, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{}
	cursor, err := m.database.Collection("artists_v2").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve artists",
		}
	}
	defer cursor.Close(ctx)

	var artists []*mongodb.Artist
	for cursor.Next(ctx) {
		var artist mongodb.Artist
		if err := cursor.Decode(&artist); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode artist",
			}
		}
		artists = append(artists, &artist)
	}

	// If hasWorkshops filter is specified, filter artists with workshops
	if hasWorkshops != nil && *hasWorkshops {
		artistsWithWorkshops := []*mongodb.Artist{}
		for _, artist := range artists {
			workshops, err := m.GetWorkshopsByArtist(ctx, artist.ArtistID)
			if err == nil && len(workshops) > 0 {
				artistsWithWorkshops = append(artistsWithWorkshops, artist)
			}
		}
		return artistsWithWorkshops, nil
	}

	return artists, nil
}

// CategorizeWorkshops categorizes workshops into this week and post this week
func (m *MongoDBDatabaseImpl) CategorizeWorkshops(workshops []*mongodb.Workshop) response.CategorizedWorkshopResponse {
	now := time.Now()
	startOfWeek := now.AddDate(0, 0, -int(now.Weekday()))
	endOfWeek := startOfWeek.AddDate(0, 0, 7)

	var thisWeek []response.WorkshopListItem
	var postThisWeek []response.WorkshopListItem

	for _, workshop := range workshops {
		// Get the earliest time detail to determine workshop timing
		var workshopTime time.Time
		if len(workshop.TimeDetails) > 0 {
			td := workshop.TimeDetails[0]
			if td.Year != nil && td.Month != nil && td.Day != nil {
				workshopTime = time.Date(int(*td.Year), time.Month(*td.Month), int(*td.Day), 0, 0, 0, 0, time.UTC)
			}
		}

		// Convert workshop to response format
		workshopItem := response.FormatWorkshopListItem(workshop, nil, nil)

		if !workshopTime.IsZero() {
			if workshopTime.After(startOfWeek) && workshopTime.Before(endOfWeek) {
				thisWeek = append(thisWeek, workshopItem)
			} else if workshopTime.After(endOfWeek) {
				postThisWeek = append(postThisWeek, workshopItem)
			}
		} else {
			// If no time details, put in post this week
			postThisWeek = append(postThisWeek, workshopItem)
		}
	}

	return response.CategorizedWorkshopResponse{
		ThisWeek:     thisWeek,
		PostThisWeek: postThisWeek,
	}
}

// SearchWorkshops searches workshops by song or artist name
func (m *MongoDBDatabaseImpl) SearchWorkshops(ctx context.Context, searchQuery string) ([]*mongodb.Workshop, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Create search filter
	filter := bson.M{
		"$or": []bson.M{
			{"song": bson.M{"$regex": searchQuery, "$options": "i"}},
			{"by": bson.M{"$regex": searchQuery, "$options": "i"}},
		},
	}

	// Sort by updated_at descending
	opts := options.Find().SetSort(bson.D{{Key: "updated_at", Value: -1}})

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, filter, opts)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to search workshops",
		}
	}
	defer cursor.Close(ctx)

	var workshops []*mongodb.Workshop
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode workshop",
			}
		}
		workshops = append(workshops, &workshop)
	}

	return workshops, nil
}

// SearchArtists searches artists by name
func (m *MongoDBDatabaseImpl) SearchArtists(ctx context.Context, searchQuery string, limit int) ([]*mongodb.Artist, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"artist_name": bson.M{"$regex": searchQuery, "$options": "i"},
	}

	opts := options.Find().SetLimit(int64(limit))
	cursor, err := m.database.Collection("artists_v2").Find(ctx, filter, opts)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to search artists",
		}
	}
	defer cursor.Close(ctx)

	var artists []*mongodb.Artist
	for cursor.Next(ctx) {
		var artist mongodb.Artist
		if err := cursor.Decode(&artist); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode artist",
			}
		}
		artists = append(artists, &artist)
	}

	return artists, nil
}

// SearchUsers searches users by name
func (m *MongoDBDatabaseImpl) SearchUsers(ctx context.Context, searchQuery string, limit int) ([]*mongodb.User, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"name":       bson.M{"$regex": searchQuery, "$options": "i"},
		"is_deleted": false,
	}

	opts := options.Find().SetLimit(int64(limit))
	cursor, err := m.database.Collection("users").Find(ctx, filter, opts)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to search users",
		}
	}
	defer cursor.Close(ctx)

	var users []*mongodb.User
	for cursor.Next(ctx) {
		var user mongodb.User
		if err := cursor.Decode(&user); err != nil {
			return nil, &core.NachnaException{
				LogMessage:   err.Error(),
				StatusCode:   500,
				ErrorMessage: "Failed to decode user",
			}
		}
		users = append(users, &user)
	}

	return users, nil
}

// GetStudioByID retrieves a studio by its ID (alias for existing method)
func (m *MongoDBDatabaseImpl) GetStudioByID(ctx context.Context, studioID string) (*mongodb.Studio, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}
	var studio mongodb.Studio
	err := m.database.Collection("studios").FindOne(ctx, bson.M{"studio_id": studioID}).Decode(&studio)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   404,
			ErrorMessage: "Studio not found",
		}
	}
	return &studio, nil
}
