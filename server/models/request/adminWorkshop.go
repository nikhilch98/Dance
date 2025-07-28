package request

import (
	"encoding/json"
	"io"
	"nachna/core"
	"strings"
)

type AdminWorkshopRequest struct {
	StudioId string `json:"studio_id"`
}

func (u *AdminWorkshopRequest) FromJSON(r io.Reader) *core.NachnaException {
	e := json.NewDecoder(r)
	err := e.Decode(u)
	if err != nil {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "Invalid request body",
		}
	}
	return u.Validate()
}

// Validate ensures that all required fields are present and valid
func (u *AdminWorkshopRequest) Validate() *core.NachnaException {
	if strings.TrimSpace(u.StudioId) == "" {
		return &core.NachnaException{
			StatusCode:   400,
			ErrorMessage: "studio_id is required in request body",
		}
	}
	return nil
}
