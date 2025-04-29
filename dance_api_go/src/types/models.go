package types

// TimeDetails represents the timing information for a workshop
type TimeDetails struct {
	Day       int    `json:"day" bson:"day"`
	Month     int    `json:"month" bson:"month"`
	Year      int    `json:"year" bson:"year"`
	StartTime string `json:"start_time" bson:"start_time"`
	EndTime   string `json:"end_time,omitempty" bson:"end_time,omitempty"`
}

// WorkshopDetail represents the details of a workshop session
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

// Workshop represents a complete workshop entity
type Workshop struct {
	UUID            string           `json:"uuid" bson:"uuid"`
	PaymentLink     string           `json:"payment_link" bson:"payment_link"`
	StudioID        string           `json:"studio_id" bson:"studio_id"`
	StudioName      string           `json:"studio_name" bson:"studio_name"`
	UpdatedAt       float64          `json:"updated_at" bson:"updated_at"`
	WorkshopDetails []WorkshopDetail `json:"workshop_details" bson:"workshop_details"`
}

// Studio represents a dance studio entity
type Studio struct {
	ID            string `json:"id" bson:"studio_id"`
	Name          string `json:"name" bson:"studio_name"`
	ImageURL      string `json:"image_url,omitempty" bson:"image_url,omitempty"`
	InstagramLink string `json:"instagram_link" bson:"instagram_link"`
}

// Artist represents a dance artist entity
type Artist struct {
	ID            string `json:"id" bson:"artist_id"`
	Name          string `json:"name" bson:"artist_name"`
	ImageURL      string `json:"image_url,omitempty" bson:"image_url,omitempty"`
	InstagramLink string `json:"instagram_link" bson:"instagram_link"`
}
