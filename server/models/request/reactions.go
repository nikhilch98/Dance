package request

import (
	"encoding/json"
	"io"
	"nachna/core"
)

type ReactionRequest struct {
	EntityID   string `json:"entity_id"`
	EntityType string `json:"entity_type"` // artist, workshop, studio
	Reaction   string `json:"reaction"`    // like, notify
}

func (r *ReactionRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.EntityID == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "entity_id is required",
		}
	}

	if r.EntityType == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "entity_type is required",
		}
	}

	if r.Reaction == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "reaction is required",
		}
	}

	return nil
}

type ReactionDeleteRequest struct {
	ReactionID string `json:"reaction_id"`
}

func (r *ReactionDeleteRequest) FromJSON(body io.Reader) *core.NachnaException {
	err := json.NewDecoder(body).Decode(r)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid JSON format",
			LogMessage:   err.Error(),
		}
	}

	if r.ReactionID == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "reaction_id is required",
		}
	}

	return nil
}
