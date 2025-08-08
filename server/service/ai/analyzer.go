package ai

import (
	coreModels "nachna/models/core"
)

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
	IsValid      bool                     `json:"is_valid"`
	EventType    coreModels.EventTypeEnum `json:"event_type"`
	EventDetails []EventDetails           `json:"event_details"`
}
