package response

import (
	"encoding/json"
	"time"
)

// StreamingResponseType defines the type of streaming response
type StreamingResponseType string

const (
	StreamingTypeLog      StreamingResponseType = "logs"
	StreamingTypeProgress StreamingResponseType = "progress_bar"
)

// StreamingResponse represents a streaming update
type StreamingResponse struct {
	Type      StreamingResponseType `json:"type"`
	Timestamp time.Time             `json:"timestamp"`
	Data      interface{}           `json:"data"`
}

// LogUpdate represents a log message update
type LogUpdate struct {
	Message string `json:"message"`
	Level   string `json:"level"` // info, warning, error, success
}

// ProgressUpdate represents a progress bar update
type ProgressUpdate struct {
	Percentage float64 `json:"percentage"`
	Current    int     `json:"current"`
	Total      int     `json:"total"`
	Message    string  `json:"message,omitempty"`
}

// NewLogResponse creates a new log streaming response
func NewLogResponse(message, level string) *StreamingResponse {
	return &StreamingResponse{
		Type:      StreamingTypeLog,
		Timestamp: time.Now(),
		Data: LogUpdate{
			Message: message,
			Level:   level,
		},
	}
}

// NewProgressResponse creates a new progress streaming response
func NewProgressResponse(percentage float64, current, total int, message string) *StreamingResponse {
	return &StreamingResponse{
		Type:      StreamingTypeProgress,
		Timestamp: time.Now(),
		Data: ProgressUpdate{
			Percentage: percentage,
			Current:    current,
			Total:      total,
			Message:    message,
		},
	}
}

// ToJSON converts the streaming response to JSON bytes
func (s *StreamingResponse) ToJSON() ([]byte, error) {
	return json.Marshal(s)
}
