package studio

import (
	"context"
	"fmt"
	"nachna/config"
	"nachna/core"
	"nachna/database"
	coreModels "nachna/models/core"
	"nachna/models/mongodb"
	"sync"
)

type AdminStudioService interface {

	// External Methods
	GetInstance(webBasedStudioImpl BaseStudio, databaseImpl database.Database) AdminStudioService
	RefreshWorkshopsGivenStudioId(studioId string) (any, *core.NachnaException)
	RefreshStudios() (any, *core.NachnaException)
	//Internal Methods
	fetchStudioProcessorGivenStudioId(studioId string) (BaseStudio, *core.NachnaException, map[string]string)
}

var adminStudioServicelock = &sync.Mutex{}

type AdminStudioServiceImpl struct {
	webBasedStudioImpl BaseStudio
	databaseImpl       database.Database
}

var adminStudioServiceImpl *AdminStudioServiceImpl

// External Methods

func (AdminStudioServiceImpl) GetInstance(webBasedStudioImpl BaseStudio, databaseImpl database.Database) AdminStudioService {
	if adminStudioServiceImpl == nil {
		adminStudioServicelock.Lock()
		defer adminStudioServicelock.Unlock()
		if adminStudioServiceImpl == nil {
			adminStudioServiceImpl = &AdminStudioServiceImpl{
				webBasedStudioImpl: webBasedStudioImpl,
				databaseImpl:       databaseImpl,
			}
		}
	}
	return adminStudioServiceImpl
}

func (a *AdminStudioServiceImpl) RefreshWorkshopsGivenStudioId(studioId string) (any, *core.NachnaException) {
	baseStudio, err, config := a.fetchStudioProcessorGivenStudioId(studioId)
	if err != nil {
		return nil, err
	}

	fmt.Printf("Fetching workshops from studio %s\n", studioId)
	workshops, ignoredLinks, oldLinks, missingArtists, err := baseStudio.FetchExistingWorkshops(studioId, config["startUrl"], config["regexMatchLink"])
	if err != nil {
		return nil, err
	}
	fmt.Printf("Fetched %d workshops from studio %s\n", len(workshops), studioId)
	fmt.Printf("Ignored %d links from studio %s\n", len(ignoredLinks), studioId)
	fmt.Printf("Old %d links from studio %s\n", len(oldLinks), studioId)
	fmt.Printf("Missing %d artists from studio %s\n", len(missingArtists), studioId)

	workshopsMongo := make([]mongodb.Workshop, len(workshops))
	for i, workshop := range workshops {
		workshopsMongo[i] = mongodb.Workshop{
			PaymentLink:     workshop.PaymentLink,
			PaymentLinkType: coreModels.PaymentLinkTypeEnum(workshop.PaymentLinkType),
			StudioID:        workshop.StudioId,
			UUID:            workshop.Uuid,
			EventType:       coreModels.EventTypeEnum(workshop.EventType),
			TimeDetails:     workshop.TimeDetails,
			By:              workshop.By,
			Song:            workshop.Song,
			PricingInfo:     workshop.PricingInfo,
			ArtistIDList:    workshop.ArtistIdList,
			UpdatedAt:       workshop.UpdatedAt,
			ChoreoInstaLink: workshop.ChoreoInstaLink,
		}
	}

	err = a.databaseImpl.RemoveWorkshopsGivenStudioId(context.Background(), studioId)
	if err != nil {
		return nil, err
	}

	fmt.Printf("Inserting %d workshops into database\n", len(workshopsMongo))

	err = a.databaseImpl.InsertWorkshops(context.Background(), workshopsMongo)
	if err != nil {
		return nil, err
	}
	return nil, nil
}

func (a *AdminStudioServiceImpl) RefreshStudios() (any, *core.NachnaException) {
	return nil, nil
}

// Internal Methods
func (a *AdminStudioServiceImpl) fetchStudioProcessorGivenStudioId(studioId string) (BaseStudio, *core.NachnaException, map[string]string) {
	for _, studio := range config.Config.WebBasedStudios {
		if studio.Name == studioId {
			return a.webBasedStudioImpl, nil, map[string]string{
				"startUrl":       studio.Url,
				"regexMatchLink": studio.BaseUrl,
			}
		}
	}
	return nil, &core.NachnaException{
		StatusCode:   400,
		ErrorMessage: "Studio ID is not yet supported for admin functions",
	}, nil
}
