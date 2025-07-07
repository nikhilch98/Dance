package ai

import (
	"nachna/core"
)

type AIAnalyzer interface {
	GetInstance() AIAnalyzer
	generateSystemPrompt(artistsDataList []map[string]string, currentDateTime string) (string, *core.NachnaException)
	Analyze(screenshotPath string, artistsDataList []map[string]string) (*EventSummary, *core.NachnaException)
}

type TimeDetails struct {
	Day       *int64  `json:"day"`
	Month     *int64  `json:"month"`
	Year      *int64  `json:"year"`
	StartTime *string `json:"start_time"`
	EndTime   *string `json:"end_time"`
}

type EventDetails struct {
	TimeDetails  []TimeDetails `json:"time_details"`
	By           *string       `json:"by"`
	Song         *string       `json:"song"`
	PricingInfo  *string       `json:"pricing_info"`
	ArtistIDList []*string     `json:"artist_id_list"`
}

type EventSummary struct {
	IsValid      bool           `json:"is_valid"`
	EventType    string         `json:"event_type"`
	EventDetails []EventDetails `json:"event_details"`
}
