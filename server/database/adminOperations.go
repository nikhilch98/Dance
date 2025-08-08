package database

import (
	"context"
	"nachna/core"
	"nachna/models/mongodb"
	"nachna/models/response"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Admin-related database operations

// GetMissingArtistSessions retrieves workshops with missing artist assignments
func (m *MongoDBDatabaseImpl) GetMissingArtistSessions(ctx context.Context) ([]response.MissingArtistSession, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Build studio map
	studioMap := make(map[string]string)
	studiosCursor, err := m.database.Collection("studios").Find(ctx, bson.M{})
	if err == nil {
		defer studiosCursor.Close(ctx)
		for studiosCursor.Next(ctx) {
			var studio mongodb.Studio
			if studiosCursor.Decode(&studio) == nil {
				studioMap[studio.StudioID] = studio.StudioName
			}
		}
	}

	// Find workshops with missing or empty artist_id_list
	filter := bson.M{
		"event_type": bson.M{"$nin": []string{"regulars"}},
		"$or": []bson.M{
			{"artist_id_list": bson.M{"$exists": false}},
			{"artist_id_list": nil},
			{"artist_id_list": []string{}},
			{"artist_id_list": bson.M{"$in": []interface{}{nil, "", "TBA", "tba", "N/A", "n/a"}}},
		},
	}

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve missing artist sessions",
		}
	}
	defer cursor.Close(ctx)

	var sessions []response.MissingArtistSession
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			continue
		}

		for _, timeDetail := range workshop.TimeDetails {
			if timeDetail.Year == nil || timeDetail.Month == nil || timeDetail.Day == nil {
				continue
			}

			date := time.Date(int(*timeDetail.Year), time.Month(*timeDetail.Month), int(*timeDetail.Day), 0, 0, 0, 0, time.UTC)
			timestampEpoch := date.Unix()

			timeStr := ""
			if timeDetail.StartTime != nil {
				timeStr = *timeDetail.StartTime
				if timeDetail.EndTime != nil {
					timeStr += " - " + *timeDetail.EndTime
				}
			}

			studioName := studioMap[workshop.StudioID]
			if studioName == "" {
				studioName = "Unknown Studio"
			}

			song := ""
			if workshop.Song != nil {
				song = *workshop.Song
			}

			originalBy := ""
			if workshop.By != nil {
				originalBy = *workshop.By
			}

			session := response.MissingArtistSession{
				WorkshopUUID:    workshop.ID.Hex(),
				Date:            date.Format("2006-01-02"),
				Time:            timeStr,
				Song:            song,
				StudioName:      studioName,
				PaymentLink:     workshop.PaymentLink,
				PaymentLinkType: string(workshop.PaymentLinkType),
				OriginalByField: originalBy,
				TimestampEpoch:  timestampEpoch,
				EventType:       string(workshop.EventType),
			}
			sessions = append(sessions, session)
		}
	}

	return sessions, nil
}

// GetMissingSongSessions retrieves workshops with missing song assignments
func (m *MongoDBDatabaseImpl) GetMissingSongSessions(ctx context.Context) ([]response.MissingArtistSession, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Build studio map
	studioMap := make(map[string]string)
	studiosCursor, err := m.database.Collection("studios").Find(ctx, bson.M{})
	if err == nil {
		defer studiosCursor.Close(ctx)
		for studiosCursor.Next(ctx) {
			var studio mongodb.Studio
			if studiosCursor.Decode(&studio) == nil {
				studioMap[studio.StudioID] = studio.StudioName
			}
		}
	}

	// Find workshops with missing or empty song field
	filter := bson.M{
		"event_type": bson.M{"$nin": []string{"regulars"}},
		"$or": []bson.M{
			{"song": bson.M{"$exists": false}},
			{"song": nil},
			{"song": ""},
			{"song": bson.M{"$in": []string{"TBA", "tba", "N/A", "n/a", "To be announced"}}},
		},
	}

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve missing song sessions",
		}
	}
	defer cursor.Close(ctx)

	var sessions []response.MissingArtistSession
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			continue
		}

		for _, timeDetail := range workshop.TimeDetails {
			if timeDetail.Year == nil || timeDetail.Month == nil || timeDetail.Day == nil {
				continue
			}

			date := time.Date(int(*timeDetail.Year), time.Month(*timeDetail.Month), int(*timeDetail.Day), 0, 0, 0, 0, time.UTC)
			timestampEpoch := date.Unix()

			timeStr := ""
			if timeDetail.StartTime != nil {
				timeStr = *timeDetail.StartTime
				if timeDetail.EndTime != nil {
					timeStr += " - " + *timeDetail.EndTime
				}
			}

			studioName := studioMap[workshop.StudioID]
			if studioName == "" {
				studioName = "Unknown Studio"
			}

			song := ""
			if workshop.Song != nil {
				song = *workshop.Song
			}

			originalBy := ""
			if workshop.By != nil {
				originalBy = *workshop.By
			}

			session := response.MissingArtistSession{
				WorkshopUUID:    workshop.ID.Hex(),
				Date:            date.Format("2006-01-02"),
				Time:            timeStr,
				Song:            song,
				StudioName:      studioName,
				PaymentLink:     workshop.PaymentLink,
				PaymentLinkType: string(workshop.PaymentLinkType),
				OriginalByField: originalBy,
				TimestampEpoch:  timestampEpoch,
				EventType:       string(workshop.EventType),
			}
			sessions = append(sessions, session)
		}
	}

	return sessions, nil
}

// AssignArtistToWorkshop assigns artists to a workshop
func (m *MongoDBDatabaseImpl) AssignArtistToWorkshop(ctx context.Context, workshopUUID string, artistIDList []string, artistNameList []string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	objectID, err := primitive.ObjectIDFromHex(workshopUUID)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid workshop UUID format",
			LogMessage:   err.Error(),
		}
	}

	// Join artist names with ' X ' separator
	combinedArtistNames := ""
	if len(artistNameList) > 0 {
		combinedArtistNames = artistNameList[0]
		for i := 1; i < len(artistNameList); i++ {
			combinedArtistNames += " X " + artistNameList[i]
		}
	}

	update := bson.M{
		"$set": bson.M{
			"artist_id_list": artistIDList,
			"by":             combinedArtistNames,
		},
	}

	result, err := m.database.Collection("workshops_v2").UpdateOne(ctx, bson.M{"_id": objectID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to assign artist to workshop",
		}
	}

	if result.MatchedCount == 0 {
		return &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Workshop not found",
		}
	}

	return nil
}

// AssignSongToWorkshop assigns a song to a workshop
func (m *MongoDBDatabaseImpl) AssignSongToWorkshop(ctx context.Context, workshopUUID string, song string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	objectID, err := primitive.ObjectIDFromHex(workshopUUID)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid workshop UUID format",
			LogMessage:   err.Error(),
		}
	}

	songValue := song
	if song != "" {
		songValue = strings.ToLower(song)
	}

	update := bson.M{
		"$set": bson.M{
			"song": songValue,
		},
	}

	result, err := m.database.Collection("workshops_v2").UpdateOne(ctx, bson.M{"_id": objectID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to assign song to workshop",
		}
	}

	if result.MatchedCount == 0 {
		return &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Workshop not found",
		}
	}

	return nil
}

// GetAppInsights retrieves application insights and statistics
func (m *MongoDBDatabaseImpl) GetAppInsights(ctx context.Context) (*response.AppInsightsData, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	insights := &response.AppInsightsData{
		LastUpdated: time.Now().Format(time.RFC3339),
	}

	// Get total users
	userCount, err := m.database.Collection("users").CountDocuments(ctx, bson.M{"is_deleted": false})
	if err == nil {
		insights.TotalUsers = userCount
	}

	// Get total likes (reactions with type "like")
	likeCount, err := m.database.Collection("reactions").CountDocuments(ctx, bson.M{
		"reaction":   "like",
		"is_deleted": false,
	})
	if err == nil {
		insights.TotalLikes = likeCount
	}

	// Get total follows (reactions with type "notify")
	followCount, err := m.database.Collection("reactions").CountDocuments(ctx, bson.M{
		"reaction":   "notify",
		"is_deleted": false,
	})
	if err == nil {
		insights.TotalFollows = followCount
	}

	// Get total workshops
	workshopCount, err := m.database.Collection("workshops_v2").CountDocuments(ctx, bson.M{})
	if err == nil {
		insights.TotalWorkshops = workshopCount
	}

	// Get total notifications sent
	notificationCount, err := m.database.Collection("notifications").CountDocuments(ctx, bson.M{"sent": true})
	if err == nil {
		insights.TotalNotificationsSent = notificationCount
	}

	return insights, nil
}

// GetWorkshopsMissingInstagramLinks retrieves workshops missing Instagram links
func (m *MongoDBDatabaseImpl) GetWorkshopsMissingInstagramLinks(ctx context.Context) ([]response.WorkshopMissingInstagramLink, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	// Build artist map
	artistMap := make(map[string]*mongodb.Artist)
	artistsCursor, err := m.database.Collection("artists_v2").Find(ctx, bson.M{})
	if err == nil {
		defer artistsCursor.Close(ctx)
		for artistsCursor.Next(ctx) {
			var artist mongodb.Artist
			if artistsCursor.Decode(&artist) == nil {
				artistMap[artist.ArtistID] = &artist
			}
		}
	}

	// Find workshops missing Instagram links
	filter := bson.M{
		"$or": []bson.M{
			{"choreo_insta_link": nil},
			{"choreo_insta_link": ""},
			{"choreo_insta_link": bson.M{"$exists": false}},
		},
	}

	cursor, err := m.database.Collection("workshops_v2").Find(ctx, filter)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve workshops missing Instagram links",
		}
	}
	defer cursor.Close(ctx)

	var workshops []response.WorkshopMissingInstagramLink
	for cursor.Next(ctx) {
		var workshop mongodb.Workshop
		if err := cursor.Decode(&workshop); err != nil {
			continue
		}

		// Get artist Instagram links
		var artistInstagramLinks []string
		if len(workshop.ArtistIDList) > 0 {
			for _, artistID := range workshop.ArtistIDList {
				if artistID != "" && artistID != "TBA" && artistID != "tba" && artistID != "N/A" && artistID != "n/a" {
					if artist, exists := artistMap[artistID]; exists && artist.InstagramLink != "" {
						artistInstagramLinks = append(artistInstagramLinks, artist.InstagramLink)
					}
				}
			}
		}

		workshopName := ""
		if workshop.Song != nil {
			workshopName = *workshop.Song
		}

		by := ""
		if workshop.By != nil {
			by = *workshop.By
		}

		workshopItem := response.WorkshopMissingInstagramLink{
			WorkshopID:           workshop.ID.Hex(),
			WorkshopName:         workshopName,
			Song:                 workshopName,
			By:                   by,
			ArtistIDList:         workshop.ArtistIDList,
			ArtistInstagramLinks: artistInstagramLinks,
		}
		workshops = append(workshops, workshopItem)
	}

	return workshops, nil
}

// UpdateWorkshopInstagramLink updates Instagram link for a workshop
func (m *MongoDBDatabaseImpl) UpdateWorkshopInstagramLink(ctx context.Context, workshopID string, choreoInstaLink string) *core.NachnaException {
	if m.database == nil {
		return &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	objectID, err := primitive.ObjectIDFromHex(workshopID)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid workshop ID format",
			LogMessage:   err.Error(),
		}
	}

	// Get workshop details first
	var workshop mongodb.Workshop
	err = m.database.Collection("workshops_v2").FindOne(ctx, bson.M{"_id": objectID}).Decode(&workshop)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   404,
			ErrorMessage: "Workshop not found",
			LogMessage:   err.Error(),
		}
	}

	// Update workshop Instagram link
	update := bson.M{
		"$set": bson.M{
			"choreo_insta_link": choreoInstaLink,
		},
	}

	_, err = m.database.Collection("workshops_v2").UpdateOne(ctx, bson.M{"_id": objectID}, update)
	if err != nil {
		return &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to update workshop Instagram link",
		}
	}

	// Update choreo_links collection
	song := ""
	if workshop.Song != nil {
		song = strings.ToLower(*workshop.Song)
	}

	choreoLinkUpdate := bson.M{
		"$set": bson.M{
			"choreo_insta_link": choreoInstaLink,
			"artist_id_list":    workshop.ArtistIDList,
			"song":              song,
		},
	}

	_, err = m.database.Collection("choreo_links").UpdateOne(
		ctx,
		bson.M{"choreo_insta_link": choreoInstaLink},
		choreoLinkUpdate,
		options.Update().SetUpsert(true),
	)
	if err != nil {
		// Log error but don't fail the main operation
		// return error for debugging if needed
	}

	return nil
}

// GetArtistChoreoLinks retrieves choreo links for a specific artist
func (m *MongoDBDatabaseImpl) GetArtistChoreoLinks(ctx context.Context, artistID string) ([]response.ArtistChoreoLink, *core.NachnaException) {
	if m.database == nil {
		return nil, &core.NachnaException{
			LogMessage:   "not connected",
			StatusCode:   500,
			ErrorMessage: "Failed to connect to MongoDB",
		}
	}

	filter := bson.M{
		"artist_id_list": bson.M{"$in": []string{artistID}},
	}

	projection := bson.M{
		"_id":               0,
		"choreo_insta_link": 1,
		"song":              1,
		"artist_id_list":    1,
	}

	cursor, err := m.database.Collection("choreo_links").Find(ctx, filter, options.Find().SetProjection(projection))
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to retrieve artist choreo links",
		}
	}
	defer cursor.Close(ctx)

	uniqueLinks := make(map[string]response.ArtistChoreoLink)
	for cursor.Next(ctx) {
		var linkData mongodb.ChoreoLink
		if err := cursor.Decode(&linkData); err != nil {
			continue
		}

		url := linkData.ChoreoInstaLink
		if url != "" {
			songTitle := linkData.Song
			if songTitle != "" {
				songTitle = strings.Title(strings.ToLower(songTitle))
			} else {
				songTitle = "Unknown Song"
			}

			if _, exists := uniqueLinks[url]; !exists {
				uniqueLinks[url] = response.ArtistChoreoLink{
					URL:         url,
					Song:        songTitle,
					DisplayText: songTitle + " - " + url,
				}
			}
		}
	}

	var result []response.ArtistChoreoLink
	for _, link := range uniqueLinks {
		result = append(result, link)
	}

	return result, nil
}
