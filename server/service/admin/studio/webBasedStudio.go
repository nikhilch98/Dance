package studio

import (
	"context"
	"fmt"
	"nachna/core"
	"nachna/database"
	coreModels "nachna/models/core"
	"nachna/service/ai"
	"nachna/utils"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/PuerkitoBio/goquery"
)

var lock = &sync.Mutex{}

type WebBasedStudioImpl struct {
}

// Improved link extraction to match Python utils.py logic (extract all <a> tags with href, filter, deduplicate, handle edge cases)
func (i *WebBasedStudioImpl) scrapeLinks(startUrl string, regexMatchLink string) ([]string, *core.NachnaException) {
	resp, err := utils.FetchURL(startUrl)
	if err != nil {
		return nil, err
	}
	if resp == nil {
		return nil, &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("Empty Response fetched from url - %s", startUrl),
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

	linkSet := make(map[string]struct{})
	var links []string

	// Parse base URL for absolute link resolution
	baseUrl := startUrl
	// Try to get <base href="..."> if present
	if baseTag := doc.Find("base[href]").First(); baseTag.Length() > 0 {
		if baseHref, exists := baseTag.Attr("href"); exists && baseHref != "" {
			baseUrl = baseHref
		}
	}

	// Helper to resolve relative URLs to absolute
	resolveUrl := func(href string) string {
		parsedHref := strings.TrimSpace(href)
		if strings.HasPrefix(parsedHref, "http://") || strings.HasPrefix(parsedHref, "https://") {
			return parsedHref
		}
		// If starts with '/', join with scheme+host of startUrl
		if strings.HasPrefix(parsedHref, "/") {
			// Parse startUrl to get scheme and host
			u, err := url.Parse(startUrl)
			if err == nil {
				return fmt.Sprintf("%s://%s%s", u.Scheme, u.Host, parsedHref)
			}
		}
		// Otherwise, join with baseUrl as relative
		u, err := url.Parse(baseUrl)
		if err == nil {
			// Remove trailing slash from base path if present
			basePath := strings.TrimSuffix(u.Path, "/")
			// If baseUrl has no path, just join
			if basePath == "" {
				return fmt.Sprintf("%s://%s/%s", u.Scheme, u.Host, parsedHref)
			}
			return fmt.Sprintf("%s://%s%s/%s", u.Scheme, u.Host, basePath, parsedHref)
		}
		// Fallback: return as is
		return parsedHref
	}

	// Extract all <a> tags with href, normalize, deduplicate, resolve to absolute
	doc.Find("a[href]").Each(func(_ int, sel *goquery.Selection) {
		href, exists := sel.Attr("href")
		if exists {
			href = strings.TrimSpace(href)
			// Ignore empty or fragment-only links
			if href == "" || href == "#" {
				return
			}
			absHref := resolveUrl(href)
			if _, seen := linkSet[absHref]; !seen {
				linkSet[absHref] = struct{}{}
				links = append(links, absHref)
			}
		}
	})

	// Filter links using regex, deduplicate again if needed
	links = utils.GetStringSetWithRegexFilters(links, regexMatchLink)
	return links, nil
}

func (i *WebBasedStudioImpl) FetchExistingWorkshops(studioId string, startUrl string, regexMatchLink string) ([]coreModels.Workshop, []string, []string, []string, *core.NachnaException) {
	links, err := i.scrapeLinks(startUrl, regexMatchLink)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	workshops := []coreModels.Workshop{}
	ignoredLinks := []string{}
	missingArtists := []string{}
	oldLinks := []string{}
	for inx, link := range links {
		// Process screenshot
		screenshotPath := BuildScreenshotPath(studioId, link)
		screenshotErr := utils.GetScreenshotGivenUrl(link, screenshotPath)
		if screenshotErr != nil {
			return nil, nil, nil, nil, screenshotErr
		}
		fmt.Printf("Fetched screenshot for %s %d/%d\n", link, inx, len(links))
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
		data, err := ai.OpenAIAnalyzer{}.GetInstance().Analyze(screenshotPath, studioId, artistsData)
		if err != nil {
			return nil, nil, nil, nil, err
		}
		if data == nil || !data.IsValid {
			ignoredLinks = append(ignoredLinks, link)
			fmt.Println("Ignored")
			continue
		}
		fmt.Printf("Analyzed %s %d/%d\n", link, inx, len(links))
		uuid := ""
		if studioId == "dance_n_addiction" || studioId == "manifestbytmn" {
			parts := strings.Split(link, "/")
			if len(parts) >= 3 {
				uuid = fmt.Sprintf("%s/%s", studioId, parts[len(parts)-3])
			}
		} else {
			parts := strings.Split(link, "/")
			if len(parts) >= 1 {
				uuid = fmt.Sprintf("%s/%s", studioId, parts[len(parts)-1])
			}
		}
		timeDetails := []coreModels.TimeDetail{}

		for _, event := range data.EventDetails {
			// Deduplicate timeDetails by (day, month, year, startTime, endTime)
			seen := make(map[string]struct{})
			for _, t := range event.TimeDetails {
				key := fmt.Sprintf("%v-%v-%v-%v-%v",
					*t.Day, *t.Month, *t.Year,
					*t.StartTime, *t.EndTime,
				)
				fmt.Println(key, seen)
				if _, ok := seen[key]; ok {
					continue
				}
				seen[key] = struct{}{}
				timeDetails = append(timeDetails, coreModels.TimeDetail{
					Day:       t.Day,
					Month:     t.Month,
					Year:      t.Year,
					StartTime: t.StartTime,
					EndTime:   t.EndTime,
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
				StudioId:        studioId,
				PaymentLink:     link,
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
				fmt.Printf("Old Link\n")
			} else {
				workshops = append(workshops, workshop)
				if len(event.ArtistIDList) == 0 {
					missingArtists = append(missingArtists, link)
				}
				fmt.Printf("Accepted %d\n", len(timeDetails))
			}
		}
	}
	return workshops, ignoredLinks, oldLinks, missingArtists, nil
}

var studioServiceInstance *WebBasedStudioImpl

func (WebBasedStudioImpl) GetInstance() *WebBasedStudioImpl {
	if studioServiceInstance == nil {
		lock.Lock()
		defer lock.Unlock()
		if studioServiceInstance == nil {
			studioServiceInstance = &WebBasedStudioImpl{}
		}
	}
	return studioServiceInstance
}
