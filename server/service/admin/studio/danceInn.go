package studio

import (
	"context"
	"fmt"
	"nachna/core"
	"nachna/database"
	coreModels "nachna/models/core"
	"nachna/service/ai"
	"nachna/utils"
	"strings"
	"sync"
	"time"

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

func (i *DanceInnStudioImpl) FetchExistingWorkshops() ([]coreModels.Workshop, []string, []string, []string, *core.NachnaException) {
	links, err := i.scrapeLinks()
	if err != nil {
		return nil, nil, nil, nil, err
	}
	workshops := []coreModels.Workshop{}
	ignoredLinks := []string{}
	missingArtists := []string{}
	oldLinks := []string{}
	for _, link := range links {
		// Process screenshot
		screenshotPath := BuildScreenshotPath(i.studioId, link)
		screenshotErr := utils.GetScreenshotGivenUrl(link, screenshotPath)
		if screenshotErr != nil {
			return nil, nil, nil, nil, screenshotErr
		}
		// Fetch artists list from database
		database, err := database.MongoDBDatabaseImpl{}.GetInstance()
		if err != nil {
			return nil, nil, nil, nil, err
		}
		artists, err := database.GetAllArtists(context.Background())
		if err != nil {
			return nil, nil, nil, nil, err
		}
		artistsData := []map[string]string{}
		for _, artist := range artists {
			artistsData = append(artistsData, map[string]string{
				"artist_id":   artist.ArtistID,
				"artist_name": artist.ArtistName,
			})
		}
		// Analyze with ai
		data, err := ai.OpenAIAnalyzer{}.GetInstance().Analyze(screenshotPath, artistsData)
		if err != nil {
			return nil, nil, nil, nil, err
		}
		if data == nil || !data.IsValid {
			ignoredLinks = append(ignoredLinks, link)
			continue
		}
		uuid := ""
		if i.studioId == "dance_n_addiction" || i.studioId == "manifestbytmn" {
			parts := strings.Split(link, "/")
			if len(parts) >= 3 {
				uuid = fmt.Sprintf("%s/%s", i.studioId, parts[len(parts)-3])
			}
		} else {
			parts := strings.Split(link, "/")
			if len(parts) >= 1 {
				uuid = fmt.Sprintf("%s/%s", i.studioId, parts[len(parts)-1])
			}
		}
		timeDetails := []coreModels.TimeDetail{}

		for _, event := range data.EventDetails {
			for _, timeDetail := range event.TimeDetails {
				timeDetails = append(timeDetails, coreModels.TimeDetail{
					Day:       timeDetail.Day,
					Month:     timeDetail.Month,
					Year:      timeDetail.Year,
					StartTime: timeDetail.StartTime,
					EndTime:   timeDetail.EndTime,
				})
			}
			var choreoInstaLink *string
			if event.Song != nil && event.ArtistIDList != nil {
				choreoInstaLink, err = database.GetChoreoLinkGivenArtistIdListAndSong(context.Background(), utils.StringPtrSliceToStringSlice(event.ArtistIDList), *event.Song)
				if err != nil {
					return nil, nil, nil, nil, err
				}
			}
			workshop := coreModels.Workshop{
				StudioId:        i.studioId,
				PaymentLink:     &link,
				PaymentLinkType: "url",
				Uuid:            uuid,
				EventType:       data.EventType,
				TimeDetails:     timeDetails,
				By:              event.By,
				Song:            event.Song,
				PricingInfo:     event.PricingInfo,
				ArtistIdList:    utils.StringPtrSliceToStringSlice(event.ArtistIDList),
				UpdatedAt:       time.Now().Unix(),
				ChoreoInstaLink: choreoInstaLink,
			}

			isPastEvent := false
			if data.EventType == "workshop" && len(timeDetails) > 0 {
				firstTimeDetail := timeDetails[0]
				if firstTimeDetail.Year != nil && firstTimeDetail.Month != nil && firstTimeDetail.Day != nil {
					year := int(*firstTimeDetail.Year)
					month := int(*firstTimeDetail.Month)
					day := int(*firstTimeDetail.Day)
					eventDate := time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC)
					if eventDate.Before(time.Now().Truncate(24 * time.Hour)) { // 24 hours ago in IST timezone
						isPastEvent = true
					}
				}
			}
			if isPastEvent {
				oldLinks = append(oldLinks, link)
				ignoredLinks = append(ignoredLinks, link)
			} else {
				workshops = append(workshops, workshop)
				if len(event.ArtistIDList) == 0 {
					missingArtists = append(missingArtists, link)
				}
			}
		}
	}
	return workshops, ignoredLinks, oldLinks, missingArtists, nil
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
