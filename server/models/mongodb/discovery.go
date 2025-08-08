package mongodb

import (
	"nachna/models/core"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// Artist represents an artist in the database
type Artist struct {
	ID            primitive.ObjectID `bson:"_id" json:"id"`
	ArtistID      string             `bson:"artist_id" json:"artist_id"`
	ArtistName    string             `bson:"artist_name" json:"artist_name"`
	ImageUrl      string             `bson:"image_url" json:"image_url"`
	InstagramLink string             `bson:"instagram_link" json:"instagram_link"`
}

type Studio struct {
	ID            primitive.ObjectID `bson:"_id" json:"id"`
	StudioID      string             `bson:"studio_id" json:"studio_id"`
	StudioName    string             `bson:"studio_name" json:"studio_name"`
	InstagramLink *string            `bson:"instagram_link,omitempty" json:"instagram_link,omitempty"`
	Location      *string            `bson:"location,omitempty" json:"location,omitempty"`
	Description   *string            `bson:"description,omitempty" json:"description,omitempty"`
}

type ChoreoLink struct {
	ID              primitive.ObjectID `bson:"_id" json:"id"`
	Song            string             `bson:"song" json:"song"`
	ArtistIdList    []string           `bson:"artist_id_list" json:"artist_id_list"`
	ChoreoInstaLink string             `bson:"choreo_insta_link" json:"choreo_insta_link"`
}

type Workshop struct {
	ID              primitive.ObjectID       `bson:"_id,omitempty" json:"_id"`
	PaymentLink     string                   `bson:"payment_link" json:"payment_link"`
	PaymentLinkType core.PaymentLinkTypeEnum `bson:"payment_link_type" json:"payment_link_type"`
	StudioID        string                   `bson:"studio_id" json:"studio_id"`
	UUID            string                   `bson:"uuid" json:"uuid"`
	EventType       core.EventTypeEnum       `bson:"event_type" json:"event_type"`
	TimeDetails     []core.TimeDetail        `bson:"time_details" json:"time_details"`
	By              *string                  `bson:"by" json:"by"`
	Song            *string                  `bson:"song" json:"song"`
	PricingInfo     *string                  `bson:"pricing_info" json:"pricing_info"`
	ArtistIDList    []string                 `bson:"artist_id_list" json:"artist_id_list"`
	UpdatedAt       int64                    `bson:"updated_at" json:"updated_at"`
	ChoreoInstaLink *string                  `bson:"choreo_insta_link" json:"choreo_insta_link"`
}
