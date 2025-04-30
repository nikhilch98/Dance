package database

import (
	"context"
	"log"
	"sort"
	"sync"
	"time"

	"github.com/nikhilchatragadda/dance/models"
	"github.com/nikhilchatragadda/dance/utils"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// Cache for studios data with 1 hour expiration
var (
	studiosCache     []models.Studio
	studiosCacheMux  sync.RWMutex
	studiosCacheTime time.Time
	studiosCacheTTL  = 1 * time.Hour
)

// GetWorkshops fetches all workshops from the database
func GetWorkshops() ([]models.Workshop, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	workshops := []models.Workshop{}

	// Build a mapping from studio_id to studio_name
	studioMap := make(map[string]string)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	studioCursor, err := client.Database("discovery").Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer studioCursor.Close(ctx)

	var studios []bson.M
	if err = studioCursor.All(ctx, &studios); err != nil {
		return nil, err
	}

	for _, studio := range studios {
		studioID, _ := studio["studio_id"].(string)
		studioName, _ := studio["studio_name"].(string)
		studioMap[studioID] = studioName
	}

	// Get workshops
	cursor, err := client.Database("discovery").Collection("workshops_v2").Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var workshopDocs []bson.M
	if err = cursor.All(ctx, &workshopDocs); err != nil {
		return nil, err
	}

	for _, workshop := range workshopDocs {
		var formattedDetails []models.WorkshopDetail

		if details, ok := workshop["workshop_details"].(bson.A); ok {
			for _, detail := range details {
				if detailMap, ok := detail.(bson.M); ok {
					timeDetails, _ := detailMap["time_details"].(bson.M)

					// Convert timeDetails to a map[string]interface{} for the utility functions
					timeDetailsMap := make(map[string]interface{})
					for k, v := range timeDetails {
						timeDetailsMap[k] = v
					}

					// Get timestamp epoch for sorting
					timestampEpoch := utils.GetTimestampEpoch(timeDetailsMap)

					// Get formatted date and time
					date := utils.FormatDateWithoutDay(timeDetailsMap)
					time := utils.FormatTime(timeDetailsMap)

					// Create a base workshop detail with required fields
					formattedDetail := models.WorkshopDetail{
						TimeDetails: models.TimeDetails{
							Day:       extractIntField(timeDetails, "day"),
							Month:     extractIntField(timeDetails, "month"),
							Year:      extractIntField(timeDetails, "year"),
							StartTime: extractStringField(timeDetails, "start_time"),
						},
						TimestampEpoch: timestampEpoch,
						Date:           date,
						Time:           time,
					}

					// Handle optional fields
					if endTime, ok := timeDetails["end_time"].(string); ok && endTime != "" {
						formattedDetail.TimeDetails.EndTime = endTime
					}

					if by, ok := detailMap["by"].(string); ok && by != "" {
						formattedDetail.By = by
					}

					if song, ok := detailMap["song"].(string); ok && song != "" {
						formattedDetail.Song = song
					}

					if pricingInfo, ok := detailMap["pricing_info"].(string); ok && pricingInfo != "" {
						formattedDetail.PricingInfo = pricingInfo
					}

					if artistID, ok := detailMap["artist_id"].(string); ok && artistID != "" {
						formattedDetail.ArtistID = artistID
					}

					formattedDetails = append(formattedDetails, formattedDetail)
				}
			}
		}

		// Create workshop object
		workshopObj := models.Workshop{
			UUID:            extractStringField(workshop, "uuid"),
			PaymentLink:     extractStringField(workshop, "payment_link"),
			StudioID:        extractStringField(workshop, "studio_id"),
			StudioName:      studioMap[extractStringField(workshop, "studio_id")],
			UpdatedAt:       extractFloat64Field(workshop, "updated_at"),
			WorkshopDetails: formattedDetails,
		}

		// Add the ID
		if id, ok := workshop["_id"].(string); ok {
			workshopObj.ID = id
		}

		workshops = append(workshops, workshopObj)
	}

	// Sort workshops by the timestamp of the first detail
	sort.Slice(workshops, func(i, j int) bool {
		if len(workshops[i].WorkshopDetails) == 0 || len(workshops[j].WorkshopDetails) == 0 {
			return false
		}
		return workshops[i].WorkshopDetails[0].TimestampEpoch < workshops[j].WorkshopDetails[0].TimestampEpoch
	})

	return workshops, nil
}

// Helper functions for field extraction with proper type handling

// extractStringField safely extracts a string field from a BSON document
func extractStringField(doc bson.M, fieldName string) string {
	if val, ok := doc[fieldName]; ok {
		if strVal, ok := val.(string); ok {
			return strVal
		}
	}
	return ""
}

// extractIntField safely extracts an integer field from a BSON document
func extractIntField(doc bson.M, fieldName string) int {
	if val, ok := doc[fieldName]; ok {
		switch v := val.(type) {
		case int:
			return v
		case int32:
			return int(v)
		case int64:
			return int(v)
		case float64:
			return int(v)
		}
	}
	return 0
}

// extractFloat64Field safely extracts a float64 field from a BSON document
func extractFloat64Field(doc bson.M, fieldName string) float64 {
	if val, ok := doc[fieldName]; ok {
		switch v := val.(type) {
		case float64:
			return v
		case int:
			return float64(v)
		case int32:
			return float64(v)
		case int64:
			return float64(v)
		}
	}
	return 0.0
}

// GetStudios fetches all active studios from the database with caching
func GetStudios() ([]models.Studio, error) {
	totalStart := time.Now()
	defer func() {
		log.Printf("[PERF_DB] GetStudios - Total time: %v", time.Since(totalStart))
	}()

	// Check cache first
	studiosCacheMux.RLock()
	cacheExpired := time.Since(studiosCacheTime) > studiosCacheTTL
	if !cacheExpired && len(studiosCache) > 0 {
		studios := studiosCache
		studiosCacheMux.RUnlock()
		log.Printf("[PERF_DB] GetStudios - Served from cache (%d studios)", len(studios))
		return studios, nil
	}
	studiosCacheMux.RUnlock()

	// Cache miss or expired, fetch from database
	clientStart := time.Now()
	client, err := utils.GetMongoClient()
	log.Printf("[PERF_DB] GetStudios - Client connection: %v", time.Since(clientStart))

	if err != nil {
		return nil, err
	}

	// Use shorter timeout for database operations
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	queryStart := time.Now()
	cursor, err := client.Database("discovery").Collection("studios").Find(ctx, bson.M{})
	log.Printf("[PERF_DB] GetStudios - Execute query: %v", time.Since(queryStart))

	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var studios []models.Studio
	processStart := time.Now()
	studioCount := 0

	for cursor.Next(ctx) {
		var studioDoc bson.M
		if err := cursor.Decode(&studioDoc); err != nil {
			log.Printf("[PERF_DB] GetStudios - Failed to decode studio document: %v", err)
			continue
		}

		studio := models.Studio{
			ID:            studioDoc["studio_id"].(string),
			Name:          studioDoc["studio_name"].(string),
			InstagramLink: studioDoc["instagram_link"].(string),
		}

		if imageURL, ok := studioDoc["image_url"].(string); ok {
			studio.ImageURL = imageURL
		}

		studios = append(studios, studio)
		studioCount++

		if studioCount%5 == 0 { // Log every 5 studios to avoid excessive logging
			log.Printf("[PERF_DB] GetStudios - Processed %d studios in %v",
				studioCount, time.Since(processStart))
		}
	}

	log.Printf("[PERF_DB] GetStudios - Processed total %d studios in %v",
		len(studios), time.Since(processStart))

	// Update cache
	if len(studios) > 0 {
		studiosCacheMux.Lock()
		studiosCache = studios
		studiosCacheTime = time.Now()
		studiosCacheMux.Unlock()
		log.Printf("[PERF_DB] GetStudios - Updated cache with %d studios", len(studios))
	}

	return studios, nil
}

// GetArtists fetches all active artists from the database
func GetArtists() ([]models.Artist, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Pipeline to find artists with active workshops
	pipeline := mongo.Pipeline{
		bson.D{
			{Key: "$lookup", Value: bson.M{
				"from":         "workshops_v2",
				"localField":   "artist_id",
				"foreignField": "workshop_details.artist_id",
				"as":           "matchingWorkshops",
			}},
		},
		bson.D{
			{Key: "$match", Value: bson.M{
				"matchingWorkshops": bson.M{"$ne": []interface{}{}},
			}},
		},
		bson.D{
			{Key: "$project", Value: bson.M{
				"_id":            0,
				"artist_id":      1,
				"artist_name":    1,
				"image_url":      1,
				"instagram_link": 1,
			}},
		},
	}

	cursor, err := client.Database("discovery").Collection("artists_v2").Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var artists []models.Artist
	for cursor.Next(ctx) {
		var artistDoc bson.M
		if err := cursor.Decode(&artistDoc); err != nil {
			continue
		}

		artist := models.Artist{
			ID:            artistDoc["artist_id"].(string),
			Name:          artistDoc["artist_name"].(string),
			InstagramLink: artistDoc["instagram_link"].(string),
		}

		if imageURL, ok := artistDoc["image_url"].(string); ok {
			artist.ImageURL = imageURL
		}

		artists = append(artists, artist)
	}

	return artists, nil
}

// GetWorkshopsByArtist fetches workshops for a specific artist
func GetWorkshopsByArtist(artistID string) ([]models.WorkshopSession, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Find workshops that have this artist
	cursor, err := client.Database("discovery").Collection("workshops_v2").Find(
		ctx,
		bson.M{"workshop_details.artist_id": artistID},
	)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	workshops := []models.WorkshopSession{}
	for cursor.Next(ctx) {
		var entry bson.M
		if err := cursor.Decode(&entry); err != nil {
			continue
		}

		if details, ok := entry["workshop_details"].(bson.A); ok {
			for _, detail := range details {
				detailMap, ok := detail.(bson.M)
				if !ok {
					continue
				}

				// Skip if not for this artist
				detailArtistID, ok := detailMap["artist_id"].(string)
				if !ok || detailArtistID != artistID {
					continue
				}

				// Extract time details
				timeDetails, ok := detailMap["time_details"].(bson.M)
				if !ok {
					continue
				}

				// Convert to map for utility functions
				timeDetailsMap := make(map[string]interface{})
				for k, v := range timeDetails {
					timeDetailsMap[k] = v
				}

				// Create workshop session with essential fields
				session := models.WorkshopSession{
					Date:           utils.FormatDate(timeDetailsMap),
					Time:           utils.FormatTime(timeDetailsMap),
					StudioID:       extractStringField(entry, "studio_id"),
					ArtistID:       detailArtistID,
					PaymentLink:    extractStringField(entry, "payment_link"),
					TimestampEpoch: utils.GetTimestampEpoch(timeDetailsMap),
				}

				// Handle optional fields
				if by, ok := detailMap["by"].(string); ok && by != "" {
					session.Artist = by
				}

				if song, ok := detailMap["song"].(string); ok && song != "" {
					session.Song = song
				}

				if pricing, ok := detailMap["pricing_info"].(string); ok && pricing != "" {
					session.PricingInfo = pricing
				}

				workshops = append(workshops, session)
			}
		}
	}

	// Sort by timestamp
	sort.Slice(workshops, func(i, j int) bool {
		return workshops[i].TimestampEpoch < workshops[j].TimestampEpoch
	})

	return workshops, nil
}

// GetWorkshopsByStudio fetches workshops for a specific studio grouped by this week and future
func GetWorkshopsByStudio(studioID string) (models.CategorizedWorkshopResponse, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return models.CategorizedWorkshopResponse{}, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	tempThisWeek := []models.WorkshopSession{}
	tempPostThisWeek := []models.WorkshopSession{}

	// Calculate current week boundaries (Monday to Sunday)
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
	weekday := int(today.Weekday())
	if weekday == 0 { // Sunday is 0, but we want Monday as 0
		weekday = 6
	} else {
		weekday--
	}
	startOfWeek := today.AddDate(0, 0, -weekday)
	endOfWeek := startOfWeek.AddDate(0, 0, 6)

	// Find workshops for this studio
	cursor, err := client.Database("discovery").Collection("workshops_v2").Find(
		ctx,
		bson.M{"studio_id": studioID},
	)
	if err != nil {
		return models.CategorizedWorkshopResponse{}, err
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var workshop bson.M
		if err := cursor.Decode(&workshop); err != nil {
			continue
		}

		if details, ok := workshop["workshop_details"].(bson.A); ok {
			for _, detail := range details {
				detailMap, ok := detail.(bson.M)
				if !ok {
					continue
				}

				// Extract time details
				timeDetails, ok := detailMap["time_details"].(bson.M)
				if !ok {
					continue
				}

				// Convert to map for utility functions
				timeDetailsMap := make(map[string]interface{})
				for k, v := range timeDetails {
					timeDetailsMap[k] = v
				}

				// Create workshop session with essential fields
				session := models.WorkshopSession{
					Date:           utils.FormatDate(timeDetailsMap),
					Time:           utils.FormatTime(timeDetailsMap),
					StudioID:       studioID,
					PaymentLink:    extractStringField(workshop, "payment_link"),
					TimestampEpoch: utils.GetTimestampEpoch(timeDetailsMap),
					TimeDetails:    timeDetailsMap, // Keep original details for weekday calculation
				}

				// Handle optional fields
				if by, ok := detailMap["by"].(string); ok && by != "" {
					session.Artist = by
				}

				if artistID, ok := detailMap["artist_id"].(string); ok && artistID != "" {
					session.ArtistID = artistID
				}

				if song, ok := detailMap["song"].(string); ok && song != "" {
					session.Song = song
				}

				if pricing, ok := detailMap["pricing_info"].(string); ok && pricing != "" {
					session.PricingInfo = pricing
				}

				// Get the date for this session
				year := extractIntField(timeDetails, "year")
				month := extractIntField(timeDetails, "month")
				day := extractIntField(timeDetails, "day")
				sessionDate := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.Local)

				// Categorize by week
				if !sessionDate.Before(startOfWeek) && !sessionDate.After(endOfWeek) {
					tempThisWeek = append(tempThisWeek, session)
				} else if sessionDate.After(endOfWeek) {
					tempPostThisWeek = append(tempPostThisWeek, session)
				}
			}
		}
	}

	// Process this_week workshops into daily structure
	thisWeekByDay := make(map[string][]models.WorkshopSession)
	for _, session := range tempThisWeek {
		weekday := utils.FormatDateWithDay(session.TimeDetails)[1]
		thisWeekByDay[weekday] = append(thisWeekByDay[weekday], session)
	}

	finalThisWeek := []models.DaySchedule{}
	daysOrder := []string{
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
		"Sunday",
	}

	for _, day := range daysOrder {
		if workshops, exists := thisWeekByDay[day]; exists && len(workshops) > 0 {
			// Sort within day by timestamp_epoch
			sort.Slice(workshops, func(i, j int) bool {
				return workshops[i].TimestampEpoch < workshops[j].TimestampEpoch
			})

			// Clean the workshops (remove TimeDetails)
			cleanedWorkshops := make([]models.WorkshopSession, len(workshops))
			for i, workshop := range workshops {
				// Create a copy without TimeDetails
				cleanedWorkshop := workshop
				cleanedWorkshop.TimeDetails = nil
				cleanedWorkshops[i] = cleanedWorkshop
			}

			finalThisWeek = append(finalThisWeek, models.DaySchedule{
				Day:       day,
				Workshops: cleanedWorkshops,
			})
		}
	}

	// Sort post_this_week chronologically
	sort.Slice(tempPostThisWeek, func(i, j int) bool {
		return tempPostThisWeek[i].TimestampEpoch < tempPostThisWeek[j].TimestampEpoch
	})

	// Clean the post_this_week workshops
	finalPostThisWeek := make([]models.WorkshopSession, len(tempPostThisWeek))
	for i, workshop := range tempPostThisWeek {
		// Create a copy without TimeDetails
		cleanedWorkshop := workshop
		cleanedWorkshop.TimeDetails = nil
		finalPostThisWeek[i] = cleanedWorkshop
	}

	return models.CategorizedWorkshopResponse{
		ThisWeek:     finalThisWeek,
		PostThisWeek: finalPostThisWeek,
	}, nil
}

// Admin functions - for studio CRUD operations

// ListStudios returns all studios
func ListStudios() ([]map[string]interface{}, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cursor, err := client.Database("discovery").Collection("studios").Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var studios []map[string]interface{}
	if err = cursor.All(ctx, &studios); err != nil {
		return nil, err
	}

	return studios, nil
}

// CreateStudio creates a new studio record
func CreateStudio(studio map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("studios").InsertOne(ctx, studio)
	if err != nil {
		return err
	}

	// Invalidate cache on create
	InvalidateStudiosCache()
	return nil
}

// UpdateStudio updates an existing studio record
func UpdateStudio(studioID string, studio map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("studios").UpdateOne(
		ctx,
		bson.M{"studio_id": studioID},
		bson.M{"$set": studio},
	)
	if err != nil {
		return err
	}

	// Invalidate cache on update
	InvalidateStudiosCache()
	return nil
}

// DeleteStudio deletes a studio record
func DeleteStudio(studioID string) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("studios").DeleteOne(
		ctx,
		bson.M{"studio_id": studioID},
	)
	if err != nil {
		return err
	}

	// Invalidate cache on delete
	InvalidateStudiosCache()
	return nil
}

// Admin functions - for artist CRUD operations

// ListArtists returns all artists
func ListArtists() ([]map[string]interface{}, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cursor, err := client.Database("discovery").Collection("artists_v2").Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var artists []map[string]interface{}
	if err = cursor.All(ctx, &artists); err != nil {
		return nil, err
	}

	return artists, nil
}

// CreateArtist creates a new artist
func CreateArtist(artist map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("artists_v2").InsertOne(ctx, artist)
	return err
}

// UpdateArtist updates an existing artist
func UpdateArtist(artistID string, artist map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("artists_v2").UpdateOne(
		ctx,
		bson.M{"artist_id": artistID},
		bson.M{"$set": artist},
	)
	return err
}

// DeleteArtist deletes an artist
func DeleteArtist(artistID string) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("artists_v2").DeleteOne(
		ctx,
		bson.M{"artist_id": artistID},
	)
	return err
}

// Admin functions - for workshop CRUD operations

// ListWorkshops returns all workshops
func ListWorkshops() ([]map[string]interface{}, error) {
	client, err := utils.GetMongoClient()
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cursor, err := client.Database("discovery").Collection("workshops_v2").Find(ctx, bson.M{})
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var workshops []map[string]interface{}
	if err = cursor.All(ctx, &workshops); err != nil {
		return nil, err
	}

	return workshops, nil
}

// CreateWorkshop creates a new workshop
func CreateWorkshop(workshop map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("workshops_v2").InsertOne(ctx, workshop)
	return err
}

// UpdateWorkshop updates an existing workshop
func UpdateWorkshop(uuid string, workshop map[string]interface{}) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("workshops_v2").UpdateOne(
		ctx,
		bson.M{"uuid": uuid},
		bson.M{"$set": workshop},
	)
	return err
}

// DeleteWorkshop deletes a workshop
func DeleteWorkshop(uuid string) error {
	client, err := utils.GetMongoClient()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err = client.Database("discovery").Collection("workshops_v2").DeleteOne(
		ctx,
		bson.M{"uuid": uuid},
	)
	return err
}

// InvalidateStudiosCache clears the studios cache after a studio is created, updated, or deleted
func InvalidateStudiosCache() {
	studiosCacheMux.Lock()
	defer studiosCacheMux.Unlock()

	studiosCache = nil
	studiosCacheTime = time.Time{}
	log.Printf("Studios cache invalidated")
}
