package studio

import (
	"fmt"
	"nachna/core"
	coreModels "nachna/models/core"
	"path"
	"strings"
)

type BaseStudio interface {
	GetInstance(startUrl string, studioId string, regexMatchLink string, maxDepth int64, maxWorkers int64) BaseStudio
	FetchExistingWorkshops() ([]coreModels.Workshop, *core.NachnaException)
	scrapeLinks() ([]string, *core.NachnaException)
}

func BuildScreenshotPath(studioID, link string) string {
	// Grab the last portion of the URL after the final “/”.
	base := path.Base(link)
	if base == "" || base == "." { // happens when link ends with "/"
		base = "index"
	}

	// Strip any query-string / fragment so the file name is clean.
	if i := strings.IndexAny(base, "?#"); i != -1 {
		base = base[:i]
	}

	// Make sure we end with .png
	return fmt.Sprintf("screenshots/%s_%s.png", studioID, base)
}
