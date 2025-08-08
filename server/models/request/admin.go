package request

import (
	"encoding/json"
	"io"
	"nachna/core"
)

type AssignArtistRequest struct {
	ArtistIDList   []string `json:"artist_id_list"`
	ArtistNameList []string `json:"artist_name_list"`
}

func (r *AssignArtistRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if len(r.ArtistIDList) == 0 {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "artist_id_list is required",
		}
	}

	if len(r.ArtistNameList) == 0 {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "artist_name_list is required",
		}
	}

	return nil
}

type AssignSongRequest struct {
	Song string `json:"song"`
}

func (r *AssignSongRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.Song == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "song is required",
		}
	}

	return nil
}

type TestNotificationRequest struct {
	ArtistID *string `json:"artist_id,omitempty"`
	Title    *string `json:"title,omitempty"`
	Body     *string `json:"body,omitempty"`
}

func (r *TestNotificationRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	return nil
}

type UpdateInstagramLinkRequest struct {
	ChoreoInstaLink string `json:"choreo_insta_link"`
}

func (r *UpdateInstagramLinkRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.ChoreoInstaLink == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "choreo_insta_link is required",
		}
	}

	return nil
}
