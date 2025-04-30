package models

// TimeDetails represents time details for a workshop session
type TimeDetails struct {
	Day       int    `json:"day" bson:"day"`
	Month     int    `json:"month" bson:"month"`
	Year      int    `json:"year" bson:"year"`
	StartTime string `json:"start_time" bson:"start_time"`
	EndTime   string `json:"end_time,omitempty" bson:"end_time,omitempty"`
}

// WorkshopDetail represents details of a specific workshop session
type WorkshopDetail struct {
	TimeDetails    TimeDetails `json:"time_details" bson:"time_details"`
	By             string      `json:"by,omitempty" bson:"by,omitempty"`
	Song           string      `json:"song,omitempty" bson:"song,omitempty"`
	PricingInfo    string      `json:"pricing_info,omitempty" bson:"pricing_info,omitempty"`
	TimestampEpoch int64       `json:"timestamp_epoch" bson:"timestamp_epoch"`
	ArtistID       string      `json:"artist_id,omitempty" bson:"artist_id,omitempty"`
	Date           string      `json:"date,omitempty" bson:"date,omitempty"`
	Time           string      `json:"time,omitempty" bson:"time,omitempty"`
}

// Workshop represents complete workshop information including all sessions
type Workshop struct {
	ID              string           `json:"_id,omitempty" bson:"_id,omitempty"`
	UUID            string           `json:"uuid" bson:"uuid"`
	PaymentLink     string           `json:"payment_link" bson:"payment_link"`
	StudioID        string           `json:"studio_id" bson:"studio_id"`
	StudioName      string           `json:"studio_name,omitempty" bson:"studio_name,omitempty"`
	UpdatedAt       float64          `json:"updated_at" bson:"updated_at"`
	Version         int              `json:"version,omitempty" bson:"version,omitempty"`
	WorkshopDetails []WorkshopDetail `json:"workshop_details" bson:"workshop_details"`
}

// Artist represents artist profile information
type Artist struct {
	ID            string `json:"id" bson:"artist_id"`
	Name          string `json:"name" bson:"artist_name"`
	ImageURL      string `json:"image_url,omitempty" bson:"image_url,omitempty"`
	InstagramLink string `json:"instagram_link" bson:"instagram_link"`
}

// Studio represents studio profile information
type Studio struct {
	ID            string `json:"id" bson:"studio_id"`
	Name          string `json:"name" bson:"studio_name"`
	ImageURL      string `json:"image_url,omitempty" bson:"image_url,omitempty"`
	InstagramLink string `json:"instagram_link" bson:"instagram_link"`
}

// WorkshopSession represents individual workshop session information
type WorkshopSession struct {
	Date           string                 `json:"date" bson:"date"`
	Time           string                 `json:"time" bson:"time"`
	Song           string                 `json:"song,omitempty" bson:"song,omitempty"`
	StudioID       string                 `json:"studio_id,omitempty" bson:"studio_id,omitempty"`
	Artist         string                 `json:"artist,omitempty" bson:"artist,omitempty"`
	ArtistID       string                 `json:"artist_id,omitempty" bson:"artist_id,omitempty"`
	PaymentLink    string                 `json:"payment_link" bson:"payment_link"`
	PricingInfo    string                 `json:"pricing_info,omitempty" bson:"pricing_info,omitempty"`
	TimestampEpoch int64                  `json:"timestamp_epoch" bson:"timestamp_epoch"`
	TimeDetails    map[string]interface{} `json:"time_details,omitempty" bson:"time_details,omitempty"`
}

// DaySchedule represents schedule of workshops for a specific day
type DaySchedule struct {
	Day       string            `json:"day" bson:"day"`
	Workshops []WorkshopSession `json:"workshops" bson:"workshops"`
}

// CategorizedWorkshopResponse represents response structure for workshops categorized by week
type CategorizedWorkshopResponse struct {
	ThisWeek     []DaySchedule     `json:"this_week" bson:"this_week"`
	PostThisWeek []WorkshopSession `json:"post_this_week" bson:"post_this_week"`
}

// WorkshopSummary represents a workshop summary from AI processing
type WorkshopSummary struct {
	IsWorkshop      bool             `json:"is_workshop" bson:"is_workshop"`
	WorkshopDetails []WorkshopDetail `json:"workshop_details" bson:"workshop_details"`
}
