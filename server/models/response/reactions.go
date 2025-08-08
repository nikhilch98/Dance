package response

type ReactionResponse struct {
	ID         string `json:"id"`
	UserID     string `json:"user_id"`
	EntityID   string `json:"entity_id"`
	EntityType string `json:"entity_type"`
	Reaction   string `json:"reaction"`
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
	IsDeleted  bool   `json:"is_deleted"`
}

type UserReactionsResponse struct {
	LikedArtists    []string `json:"liked_artists"`
	FollowedArtists []string `json:"followed_artists"`
	LikedWorkshops  []string `json:"liked_workshops"`
	LikedStudios    []string `json:"liked_studios"`
}

type ReactionStatsResponse struct {
	EntityID    string `json:"entity_id"`
	EntityType  string `json:"entity_type"`
	LikeCount   int64  `json:"like_count"`
	FollowCount int64  `json:"follow_count"`
}
