package handler

import (
	"dance_api_go/src/types"
	"net/http"
)

func HealthCheckHandler() types.GenericResponse {
	return types.GenericResponse{
		StatusCode: http.StatusOK,
		Success:    true,
		Data: types.HealthCheckResponse{
			Success: true,
		},
	}
}
