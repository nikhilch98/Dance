package response

import "nachna/models/mongodb"

type WorkshopListItem struct {
	ID              string       `json:"_id"`
	StudioID        string       `json:"studio_id"`
	PaymentLink     string       `json:"payment_link"`
	PaymentLinkType string       `json:"payment_link_type"`
	UUID            string       `json:"uuid"`
	EventType       string       `json:"event_type"`
	TimeDetails     []TimeDetail `json:"time_details"`
	By              *string      `json:"by,omitempty"`
	Song            *string      `json:"song,omitempty"`
	PricingInfo     *string      `json:"pricing_info,omitempty"`
	ArtistIDList    []string     `json:"artist_id_list"`
	UpdatedAt       int64        `json:"updated_at"`
	ChoreoInstaLink *string      `json:"choreo_insta_link,omitempty"`
	Artist          *Artist      `json:"artist,omitempty"`
	Studio          *Studio      `json:"studio,omitempty"`
}

type TimeDetail struct {
	Day       *int64  `json:"day"`
	Month     *int64  `json:"month"`
	Year      *int64  `json:"year"`
	StartTime *string `json:"start_time"`
	EndTime   *string `json:"end_time"`
}

type CategorizedWorkshopResponse struct {
	ThisWeek     []WorkshopListItem `json:"this_week"`
	PostThisWeek []WorkshopListItem `json:"post_this_week"`
}

type Artist struct {
	ID            string  `json:"_id"`
	ArtistID      string  `json:"artist_id"`
	ArtistName    string  `json:"artist_name"`
	InstagramLink *string `json:"instagram_link,omitempty"`
	ProfileImage  *string `json:"profile_image,omitempty"`
	Description   *string `json:"description,omitempty"`
}

type Studio struct {
	ID            string  `json:"_id"`
	StudioID      string  `json:"studio_id"`
	StudioName    string  `json:"studio_name"`
	InstagramLink *string `json:"instagram_link,omitempty"`
	Location      *string `json:"location,omitempty"`
	Description   *string `json:"description,omitempty"`
}

type WorkshopSession struct {
	WorkshopID      string       `json:"workshop_id"`
	StudioID        string       `json:"studio_id"`
	PaymentLink     string       `json:"payment_link"`
	PaymentLinkType string       `json:"payment_link_type"`
	UUID            string       `json:"uuid"`
	EventType       string       `json:"event_type"`
	TimeDetails     []TimeDetail `json:"time_details"`
	By              *string      `json:"by,omitempty"`
	Song            *string      `json:"song,omitempty"`
	PricingInfo     *string      `json:"pricing_info,omitempty"`
	ArtistIDList    []string     `json:"artist_id_list"`
	UpdatedAt       int64        `json:"updated_at"`
	ChoreoInstaLink *string      `json:"choreo_insta_link,omitempty"`
	Artist          *Artist      `json:"artist,omitempty"`
	Studio          *Studio      `json:"studio,omitempty"`
}

// Helper functions to convert from MongoDB models

func FormatWorkshopListItem(workshop *mongodb.Workshop, artist *Artist, studio *Studio) WorkshopListItem {
	timeDetails := make([]TimeDetail, len(workshop.TimeDetails))
	for i, td := range workshop.TimeDetails {
		timeDetails[i] = TimeDetail{
			Day:       td.Day,
			Month:     td.Month,
			Year:      td.Year,
			StartTime: td.StartTime,
			EndTime:   td.EndTime,
		}
	}

	return WorkshopListItem{
		ID:              workshop.ID.Hex(),
		StudioID:        workshop.StudioID,
		PaymentLink:     workshop.PaymentLink,
		PaymentLinkType: string(workshop.PaymentLinkType),
		UUID:            workshop.UUID,
		EventType:       string(workshop.EventType),
		TimeDetails:     timeDetails,
		By:              workshop.By,
		Song:            workshop.Song,
		PricingInfo:     workshop.PricingInfo,
		ArtistIDList:    workshop.ArtistIDList,
		UpdatedAt:       workshop.UpdatedAt,
		ChoreoInstaLink: workshop.ChoreoInstaLink,
		Artist:          artist,
		Studio:          studio,
	}
}

func FormatArtist(artist *mongodb.Artist) Artist {
	return Artist{
		ID:            artist.ID.Hex(),
		ArtistID:      artist.ArtistID,
		ArtistName:    artist.ArtistName,
		InstagramLink: &artist.InstagramLink,
		ProfileImage:  &artist.ImageUrl,
		Description:   nil, // Not in current model
	}
}

func FormatStudio(studio *mongodb.Studio) Studio {
	return Studio{
		ID:            studio.ID.Hex(),
		StudioID:      studio.StudioID,
		StudioName:    studio.StudioName,
		InstagramLink: studio.InstagramLink,
		Location:      studio.Location,
		Description:   studio.Description,
	}
}
