package core

type TimeDetail struct {
	Day       *int64  `bson:"day" json:"day"`
	Month     *int64  `bson:"month" json:"month"`
	Year      *int64  `bson:"year" json:"year"`
	StartTime *string `bson:"start_time" json:"start_time"`
	EndTime   *string `bson:"end_time" json:"end_time"`
}

type PaymentLinkTypeEnum string

const (
	PaymentLinkTypeURL      PaymentLinkTypeEnum = "url"
	PaymentLinkTypeWhatsApp PaymentLinkTypeEnum = "whatsapp"
)

type EventTypeEnum string

const (
	EventTypeEnumWorkshop  EventTypeEnum = "workshop"
	EventTypeEnumIntensive EventTypeEnum = "intensive"
	EventTypeEnumRegulars  EventTypeEnum = "regulars"
)

type Workshop struct {
	StudioId        string              `json:"studio_id"`
	PaymentLink     string              `json:"payment_link"`
	PaymentLinkType PaymentLinkTypeEnum `json:"payment_link_type"` // Can only be whatsapp / url for now
	Uuid            string              `json:"uuid"`
	EventType       EventTypeEnum       `json:"event_type"` // Can only be regulars / workshop / intensive for now
	TimeDetails     []TimeDetail        `json:"time_details"`
	By              *string             `json:"by"`
	Song            *string             `json:"song"`
	PricingInfo     *string             `json:"pricing_info"`
	ArtistIdList    []string            `json:"artist_id_list"`
	UpdatedAt       int64               `json:"updated_at"`
	ChoreoInstaLink *string             `json:"choreo_insta_link"`
}
