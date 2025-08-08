package response

type MissingArtistSession struct {
	WorkshopUUID    string `json:"workshop_uuid"`
	Date            string `json:"date"`
	Time            string `json:"time"`
	Song            string `json:"song"`
	StudioName      string `json:"studio_name"`
	PaymentLink     string `json:"payment_link"`
	PaymentLinkType string `json:"payment_link_type"`
	OriginalByField string `json:"original_by_field"`
	TimestampEpoch  int64  `json:"timestamp_epoch"`
	EventType       string `json:"event_type"`
}

type AppInsightsResponse struct {
	Success bool            `json:"success"`
	Data    AppInsightsData `json:"data"`
}

type AppInsightsData struct {
	TotalUsers             int64  `json:"total_users"`
	TotalLikes             int64  `json:"total_likes"`
	TotalFollows           int64  `json:"total_follows"`
	TotalWorkshops         int64  `json:"total_workshops"`
	TotalNotificationsSent int64  `json:"total_notifications_sent"`
	LastUpdated            string `json:"last_updated"`
}

type TestNotificationResponse struct {
	Success bool                    `json:"success"`
	Message string                  `json:"message"`
	Details TestNotificationDetails `json:"details"`
}

type TestNotificationDetails struct {
	TotalUsers      int `json:"total_users"`
	TotalTokens     int `json:"total_tokens"`
	IOSTokens       int `json:"ios_tokens"`
	SuccessfulSends int `json:"successful_sends"`
	TotalAttempts   int `json:"total_attempts"`
}

type WorkshopMissingInstagramLink struct {
	WorkshopID           string   `json:"workshop_id"`
	WorkshopName         string   `json:"workshop_name"`
	Song                 string   `json:"song"`
	By                   string   `json:"by"`
	ArtistIDList         []string `json:"artist_id_list"`
	ArtistInstagramLinks []string `json:"artist_instagram_links"`
}

type ArtistChoreoLinksResponse struct {
	Success bool               `json:"success"`
	Data    []ArtistChoreoLink `json:"data"`
	Count   int                `json:"count"`
}

type ArtistChoreoLink struct {
	URL         string `json:"url"`
	Song        string `json:"song"`
	DisplayText string `json:"display_text"`
}
