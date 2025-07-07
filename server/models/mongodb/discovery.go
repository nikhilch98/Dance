package mongodb

import (
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

type ChoreoLink struct {
	ID              primitive.ObjectID `bson:"_id" json:"id"`
	Song            string             `bson:"song" json:"song"`
	ArtistIdList    []string           `bson:"artist_id_list" json:"artist_id_list"`
	ChoreoInstaLink string             `bson:"choreo_insta_link" json:"choreo_insta_link"`
}
