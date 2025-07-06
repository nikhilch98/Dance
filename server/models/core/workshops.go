package core

type TimeDetail struct {
	Day       *string `json:"day"`
	Month     *string `json:"month"`
	Year      *string `json:"year"`
	StartTime *string `json:"start_time"`
	EndTime   *string `json:"end_time"`
}

type Workshop struct {
	StudioId        string       `json:"studio_id"`
	PaymentLink     *string      `json:"payment_link"`
	PaymentLinkType string       `json:"payment_link_type"` // Can only be whatsapp / url for now
	Uuid            string       `json:"uuid"`
	EventType       string       `json:"event_type"` // Can only be regulars / workshop / intensive for now
	TimeDetails     []TimeDetail `json:"time_details"`
	By              *string      `json:"by"`
	Song            *string      `json:"song"`
	PricingInfo     *string      `json:"pricing_info"`
	ArtistIdList    []string     `json:"artist_id_list"`
	UpdatedAt       int64        `json:"updated_at"`
	ChoreoInstaLink *string      `json:"choreo_insta_link"`
}
