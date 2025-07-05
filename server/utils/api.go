package utils

import (
	"nachna/config"
	"nachna/constants"
	"nachna/core"
	"nachna/logs"
	ResponseModels "nachna/models/response"
	"encoding/json"
	"fmt"
	"github.com/NYTimes/gziphandler"
	"github.com/google/uuid"
	newrelic "github.com/newrelic/go-agent"
	"net/http"
	"strings"
	"time"
)

type FuncDef func(r *http.Request) (any, *core.NachnaException)

var newrelicApp = GetNewRelicApplication()

func GetNewRelicApplication() newrelic.Application {
	newrelicConfig := newrelic.NewConfig(config.Config.NewRelic.AppName, config.Config.NewRelic.LicenseKey)
	newrelicConfig.AppName = config.Config.NewRelic.AppName
	newrelicConfig.License = config.Config.NewRelic.LicenseKey
	newrelicConfig.Enabled = config.Config.NewRelic.IsEnabled
	app, _ := newrelic.NewApplication(newrelicConfig)
	return app
}

func LogAccessRequest(r *http.Request, statusCode int, duration time.Duration) {
	// Extract client IP and port
	clientAddr := r.RemoteAddr
	
	// Build full URL with query string
	fullURL := r.URL.Path
	if r.URL.RawQuery != "" {
		fullURL += "?" + r.URL.RawQuery
	}
	
	// Format: INFO:server:127.0.0.1:38932 - "GET /api/workshops_by_artist/?version=v2 HTTP/1.1" 200 - | 24.2ms
	logMessage := fmt.Sprintf("server:%s - \"%s %s %s\" %d - | %.1fms",
		clientAddr,
		r.Method,
		fullURL,
		r.Proto,
		statusCode,
		float64(duration.Nanoseconds())/1000000.0, // Convert to milliseconds
	)
	
	fmt.Println(logMessage)
}

func makeHandlerUtil(fn FuncDef) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Connection", "close")
		requestUID := GetHeader(constants.XNachnaRequestId, r)
		if requestUID == "" {
			requestUID = uuid.New().String()
			SetHeader(r, constants.XNachnaRequestId, requestUID)
		}

		defer r.Body.Close()
		
		printResponseFunc := func(start time.Time, statusCode int) {
			duration := time.Since(start)
			LogAccessRequest(r, statusCode, duration)
		}
		startTime := time.Now()
		response, err := fn(r)
		if err == nil {
			defer printResponseFunc(startTime, 200)
			res, _ := json.Marshal(response)
			GenerateResponse(w, 200, res)
		} else {
			defer printResponseFunc(startTime, err.StatusCode)
			// Log additional error details separately if needed
			if err.LogMessage != "" {
				logs.LogInfo(logs.Fields{
					"request_id":  requestUID,
					"error":       err.ErrorMessage,
					"stack_trace": err.LogMessage,
				}, "api_error_details")
			}
			response := ResponseModels.CustomErrorMessage{Message: err.ErrorMessage}
			res, _ := json.Marshal(response)
			GenerateResponse(w, err.StatusCode, res)
		}

	}
}

type AuthTokenValidityResponse struct {
	Roles  []string `json:"roles"`
	UserId string   `json:"userId"`
}

func isValidToken(token string, roles []string) (bool, string, *core.NachnaException) {
	// TODO: Implement token validation
	return true, "", nil
}

//Authentication wrapper for http handler
func MakeHandler(path string, fn FuncDef, roles ...string) (string, http.HandlerFunc) {
	httpFunc := func(w http.ResponseWriter, r *http.Request) {
		if roles == nil || len(roles) == 0 {
			makeHandlerUtil(fn)(w, r)
			return
		}
		requestUID := GetHeader(constants.XNachnaRequestId, r)
		if requestUID == "" {
			requestUID = uuid.New().String()
			SetHeader(r, constants.XNachnaRequestId, requestUID)
		}
		authToken := GetHeader(constants.Authorization, r)
		if authToken == "" {
			LogAccessRequest(r, 401, 0)
			logs.LogInfo(logs.Fields{
				"request_id": requestUID,
				"error":      "Auth token not present in header",
			}, "auth_error_details")
			response := ResponseModels.CustomErrorMessage{Message: "Unauthorized"}
			res, _ := json.Marshal(response)
			GenerateResponse(w, 401, res)
			return
		}

		x := strings.Split(authToken, " ")
		if len(x) < 2 {
			LogAccessRequest(r, 401, 0)
			logs.LogInfo(logs.Fields{
				"request_id": requestUID,
				"error":      "Invalid auth token format",
			}, "auth_error_details")
			response := ResponseModels.CustomErrorMessage{Message: "Unauthorized"}
			res, _ := json.Marshal(response)
			GenerateResponse(w, 401, res)
			return
		}
		scheme := strings.ToLower(x[0])
		if scheme != "bearer" {
			LogAccessRequest(r, 401, 0)
			logs.LogInfo(logs.Fields{
				"request_id": requestUID,
				"error":      "Invalid auth token scheme",
			}, "auth_error_details")
			response := ResponseModels.CustomErrorMessage{Message: "Unauthorized"}
			res, _ := json.Marshal(response)
			GenerateResponse(w, 401, res)
			return
		}
		isValid, userId, err := isValidToken(x[1], roles)
		if err != nil {
			LogAccessRequest(r, err.StatusCode, 0)
			logs.LogInfo(logs.Fields{
				"request_id": requestUID,
				"error":      err.ErrorMessage,
				"details":    err.LogMessage,
			}, "auth_error_details")
			response := ResponseModels.CustomErrorMessage{Message: err.ErrorMessage}
			res, _ := json.Marshal(response)
			GenerateResponse(w, err.StatusCode, res)
			return
		}
		if !isValid {
			LogAccessRequest(r, 500, 0)
			logs.LogInfo(logs.Fields{
				"request_id": requestUID,
				"error":      "Token validation failed",
			}, "auth_error_details")
			response := ResponseModels.CustomErrorMessage{Message: "Error in authenticating the request"}
			res, _ := json.Marshal(response)
			GenerateResponse(w, 500, res)
			return
		}
		SetHeader(r, constants.XNachnaUserId, userId)
		makeHandlerUtil(fn)(w, r)
	}

	if config.Config.NewRelic.IsEnabled {
		_, httpFunc = newrelic.WrapHandleFunc(newrelicApp, path, httpFunc)
	}
	return path, httpFunc
}

//Gzip wrapper for http handler
func Gzip(next http.Handler) http.Handler {
	return gziphandler.GzipHandler(next)
}
