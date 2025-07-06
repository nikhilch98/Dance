package studio

import (
	"fmt"
	"sync"
	"nachna/core"
	"nachna/utils"
	coreModels "nachna/models/core"
	"github.com/PuerkitoBio/goquery"
)

var lock = &sync.Mutex{}

type DanceInnStudioImpl struct {
	StartUrl       string
	studioId       string
	regexMatchLink string
	maxDepth       int64
	maxWorkers     int64
}

func (i *DanceInnStudioImpl) scrapeLinks() ([]string, *core.NachnaException) {
	resp, err := utils.FetchURL(i.StartUrl)
	if err != nil {
		return nil, err
	}
	if resp == nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("Empty Response fetched from url - %s", i.StartUrl),
		}
	}
	defer resp.Body.Close()

	doc, docErr := goquery.NewDocumentFromReader(resp.Body)
	if docErr != nil {
		return []string{}, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("Error in parsing html: %s", docErr),
		}
	}

	var links []string
	doc.Find("a[href]").Each(func(i int, sel *goquery.Selection) {
		href, exists := sel.Attr("href")
		if exists {
			links = append(links, href)
		}
	})

	links = utils.GetStringSetWithRegexFilters(links, i.regexMatchLink)
	return links, nil
}

func (i *DanceInnStudioImpl) FetchExistingWorkshops() ([]coreModels.Workshop, *core.NachnaException) {
	links, err := i.scrapeLinks()
	if err != nil {
		return nil, err
	}
	fmt.Println("Links: ", links)
	return []coreModels.Workshop{}, nil
}

var danceInnStudioImpl *DanceInnStudioImpl

func (DanceInnStudioImpl) GetInstance(startUrl string, studioId string, regexMatchLink string, maxDepth int64, maxWorkers int64) BaseStudio {
	if danceInnStudioImpl == nil {
		lock.Lock()
		defer lock.Unlock()
		if danceInnStudioImpl == nil {
			danceInnStudioImpl = &DanceInnStudioImpl{
				StartUrl:       startUrl,
				studioId:       studioId,
				regexMatchLink: regexMatchLink,
				maxDepth:       maxDepth,
				maxWorkers:     maxWorkers,
			}
		}
	}
	return danceInnStudioImpl
}
