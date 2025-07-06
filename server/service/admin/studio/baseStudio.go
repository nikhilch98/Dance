package studio

import (
	"nachna/core"
	coreModels "nachna/models/core"
)

type BaseStudio interface {
	GetInstance(startUrl string, studioId string, regexMatchLink string, maxDepth int64, maxWorkers int64) BaseStudio
	FetchExistingWorkshops() ([]coreModels.Workshop, *core.NachnaException)
	scrapeLinks() ([]string, *core.NachnaException)
}
