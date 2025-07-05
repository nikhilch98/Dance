package api

import (
	"nachna/core"
	"nachna/models/response"
	"nachna/utils"
	"net/http"
)

func HealthCheck(r *http.Request) (any, *core.NachnaException) {
	return response.HealthCheckResponse{Success: true}, nil
}

func init() {
	Router.HandleFunc(utils.MakeHandler("/health_check", HealthCheck)).Methods(http.MethodGet)
}
