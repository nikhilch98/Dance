package studio

import (
	"fmt"
	"nachna/core"
	"sync"
)

type AdminStudioService interface {

	// External Methods
	GetInstance(danceInnStudioImpl BaseStudio) AdminStudioService
	RefreshWorkshopsGivenStudioId(studioId string) (any, *core.NachnaException)

	//Internal Methods
	fetchStudioProcessorGivenStudioId(studioId string) (BaseStudio, *core.NachnaException)
}

var adminStudioServicelock = &sync.Mutex{}

type AdminStudioServiceImpl struct {
	danceInnStudioImpl BaseStudio
}

var adminStudioServiceImpl *AdminStudioServiceImpl

// External Methods

func (AdminStudioServiceImpl) GetInstance(danceInnStudioImpl BaseStudio) AdminStudioService {
	if adminStudioServiceImpl == nil {
		adminStudioServicelock.Lock()
		defer adminStudioServicelock.Unlock()
		if adminStudioServiceImpl == nil {
			adminStudioServiceImpl = &AdminStudioServiceImpl{
				danceInnStudioImpl: danceInnStudioImpl,
			}
		}
	}
	return adminStudioServiceImpl
}

func (a *AdminStudioServiceImpl) RefreshWorkshopsGivenStudioId(studioId string) (any, *core.NachnaException) {
	baseStudio, err := a.fetchStudioProcessorGivenStudioId(studioId)
	if err != nil {
		return nil, err
	}
	workshops, err := baseStudio.FetchExistingWorkshops()
	if err != nil {
		return nil, err
	}
	fmt.Println("Fetched %s workshops from studio %s", len(workshops), studioId)
	return nil, nil
}

//Internal Methods
func (a *AdminStudioServiceImpl) fetchStudioProcessorGivenStudioId(studioId string) (BaseStudio, *core.NachnaException) {
	if studioId == "dance.inn.bangalore" {
		return a.danceInnStudioImpl, nil
	}
	return nil, &core.NachnaException{
		StatusCode:   400,
		ErrorMessage: "Studio ID is not yet supported for admin functions",
	}
}
