package types

import (
	"encoding/json"
	"log"
)

// Response represents the standard API response structure
type Response struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

type GenericResponse struct {
	StatusCode int         `json:"-"`
	Success    bool        `json:"success"`
	Data       interface{} `json:"data,omitempty"`
	Error      string      `json:"error,omitempty"`
}

func (r GenericResponse) Serialize() []byte {
	resp, err := json.Marshal(r)
	if err != nil {
		log.Printf("Error serializing response: %v", err)
		return []byte(`{"success":false,"error":"internal server error"}`)
	}
	return resp
}

type HealthCheckResponse struct {
	Success bool `json:"success"`
}
