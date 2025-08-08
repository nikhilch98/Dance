package workshop

import (
	"context"
	"nachna/core"
	"nachna/database"
	"nachna/models/mongodb"
	"nachna/models/response"
	"sync"
)

type WorkshopServiceImpl struct {
	databaseImpl *database.MongoDBDatabaseImpl
}

var workshopServiceInstance *WorkshopServiceImpl
var workshopServiceLock = &sync.Mutex{}

func (WorkshopServiceImpl) GetInstance(databaseImpl *database.MongoDBDatabaseImpl) *WorkshopServiceImpl {
	if workshopServiceInstance == nil {
		workshopServiceLock.Lock()
		defer workshopServiceLock.Unlock()
		if workshopServiceInstance == nil {
			workshopServiceInstance = &WorkshopServiceImpl{
				databaseImpl: databaseImpl,
			}
		}
	}
	return workshopServiceInstance
}

// GetAllWorkshopsCategorized gets all workshops categorized by this week and post this week
func (w *WorkshopServiceImpl) GetAllWorkshopsCategorized(studioID *string) (*response.CategorizedWorkshopResponse, *core.NachnaException) {
	ctx := context.Background()

	var workshops []*mongodb.Workshop
	var err *core.NachnaException

	if studioID != nil {
		workshops, err = w.databaseImpl.GetWorkshopsByStudio(ctx, *studioID)
	} else {
		workshops, err = w.databaseImpl.GetAllWorkshops(ctx)
	}

	if err != nil {
		return nil, err
	}

	categorized := w.databaseImpl.CategorizeWorkshops(workshops)
	return &categorized, nil
}

// GetStudios gets all studios with active workshops
func (w *WorkshopServiceImpl) GetStudios() ([]response.Studio, *core.NachnaException) {
	ctx := context.Background()

	studios, err := w.databaseImpl.GetAllStudios(ctx)
	if err != nil {
		return nil, err
	}

	var studioResponses []response.Studio
	for _, studio := range studios {
		studioResponses = append(studioResponses, response.FormatStudio(studio))
	}

	return studioResponses, nil
}

// GetArtists gets all artists with optional workshop filter
func (w *WorkshopServiceImpl) GetArtists(hasWorkshops *bool) ([]response.Artist, *core.NachnaException) {
	ctx := context.Background()

	artists, err := w.databaseImpl.GetAllArtistsFromDB(ctx, hasWorkshops)
	if err != nil {
		return nil, err
	}

	var artistResponses []response.Artist
	for _, artist := range artists {
		artistResponses = append(artistResponses, response.FormatArtist(artist))
	}

	return artistResponses, nil
}

// GetWorkshopsByArtist gets workshops for a specific artist
func (w *WorkshopServiceImpl) GetWorkshopsByArtist(artistID string) ([]response.WorkshopSession, *core.NachnaException) {
	ctx := context.Background()

	workshops, err := w.databaseImpl.GetWorkshopsByArtist(ctx, artistID)
	if err != nil {
		return nil, err
	}

	var workshopResponses []response.WorkshopSession
	for _, workshop := range workshops {
		// Convert time details
		timeDetails := make([]response.TimeDetail, len(workshop.TimeDetails))
		for i, td := range workshop.TimeDetails {
			timeDetails[i] = response.TimeDetail{
				Day:       td.Day,
				Month:     td.Month,
				Year:      td.Year,
				StartTime: td.StartTime,
				EndTime:   td.EndTime,
			}
		}

		workshopSession := response.WorkshopSession{
			WorkshopID:      workshop.ID.Hex(),
			StudioID:        workshop.StudioID,
			PaymentLink:     workshop.PaymentLink,
			PaymentLinkType: string(workshop.PaymentLinkType),
			UUID:            workshop.UUID,
			EventType:       string(workshop.EventType),
			TimeDetails:     timeDetails,
			By:              workshop.By,
			Song:            workshop.Song,
			PricingInfo:     workshop.PricingInfo,
			ArtistIDList:    workshop.ArtistIDList,
			UpdatedAt:       workshop.UpdatedAt,
			ChoreoInstaLink: workshop.ChoreoInstaLink,
		}

		workshopResponses = append(workshopResponses, workshopSession)
	}

	return workshopResponses, nil
}

// SearchWorkshops searches workshops by song name or artist name
func (w *WorkshopServiceImpl) SearchWorkshops(searchQuery string) ([]response.WorkshopListItem, *core.NachnaException) {
	ctx := context.Background()

	workshops, err := w.databaseImpl.SearchWorkshops(ctx, searchQuery)
	if err != nil {
		return nil, err
	}

	var workshopResponses []response.WorkshopListItem
	for _, workshop := range workshops {
		workshopItem := response.FormatWorkshopListItem(workshop, nil, nil)
		workshopResponses = append(workshopResponses, workshopItem)
	}

	return workshopResponses, nil
}

// SearchArtists searches artists by name
func (w *WorkshopServiceImpl) SearchArtists(searchQuery string, limit int) ([]response.Artist, *core.NachnaException) {
	ctx := context.Background()

	artists, err := w.databaseImpl.SearchArtists(ctx, searchQuery, limit)
	if err != nil {
		return nil, err
	}

	var artistResponses []response.Artist
	for _, artist := range artists {
		artistResponses = append(artistResponses, response.FormatArtist(artist))
	}

	return artistResponses, nil
}

// SearchUsers searches users by name
func (w *WorkshopServiceImpl) SearchUsers(searchQuery string, limit int) ([]response.UserProfile, *core.NachnaException) {
	ctx := context.Background()

	users, err := w.databaseImpl.SearchUsers(ctx, searchQuery, limit)
	if err != nil {
		return nil, err
	}

	var userResponses []response.UserProfile
	for _, user := range users {
		userResponses = append(userResponses, response.FormatUserProfile(user))
	}

	return userResponses, nil
}
