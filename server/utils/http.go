package utils

import (
	"bytes"
	"nachna/constants"
	"nachna/models/response"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"
	"time"
)	

const (
	TimeOut = 180 * time.Second
)

type ChannelResponse struct {
	Host       string
	Data       string
	StatusCode int
}

func GetHeader(key string, req *http.Request) string {
	return req.Header.Get(key)
}

func GetQueryString(arg *http.Request) string {
	var query string
	if arg != nil {
		query = arg.URL.RawQuery
	} else {
		return ""
	}
	return query
}

func GetPaginationParams(r *http.Request) (int, int) {

	skip := r.URL.Query().Get("skip")
	skipInt, err := strconv.Atoi(skip)
	if err != nil {
		skipInt = 0
	}
	limit := r.URL.Query().Get("limit")
	limitInt, err := strconv.Atoi(limit)
	if err != nil {
		limitInt = 10
	}
	return skipInt, limitInt
}

func GetCursorParam(r *http.Request) response.Cursor {

	cursor := r.URL.Query().Get("cursor")
	if cursor == "" {
		return response.Cursor{
			Skip:  0,
			Limit: 10,
		}
	}
	sDec, err := base64.StdEncoding.DecodeString(cursor)
	if err != nil {
		print(err)
		return response.Cursor{
			Skip:  0,
			Limit: 10,
		}
	}
	var res response.Cursor
	err = json.Unmarshal(sDec, &res)
	return res
}

func GenerateResponse(writer http.ResponseWriter, statusCode int, out []byte) {
	writer.Header().Set("Access-Control-Allow-Origin", "*")
	writer.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	writer.Header().Set("Content-Type", "application/json; char-set=utf-8")
	writer.Header().Set("Connection", "Keep-Alive")
	writer.Header().Set("X-Content-Type-Options", "nosniff")
	writer.Header().Set("Access-Control-Allow-Origin", "*")
	length := len(out)
	writer.WriteHeader(statusCode)
	writer.Header().Set("Content-Length", strconv.Itoa(length))
	_, _ = writer.Write(out)
}

func SetHeader(req *http.Request, key string, value string) {
	req.Header.Set(key, value)
}

func CopyHeaders(key string, origReq *http.Request, req *http.Request) {
	value := GetHeader(key, origReq)
	if len(value) > 0 {
		SetHeader(req, key, value)
		value = ""
	}
}

func UpdateHeaders(origReq *http.Request, req *http.Request) {
	CopyHeaders(constants.XNachnaRequestId, origReq, req)
	cookies := origReq.Cookies()
	for _, cookie := range cookies {
		req.AddCookie(cookie)
	}
}

func responseBodyReader(req *http.Request, client *http.Client) ([]byte, int, error) {
	var statusCode int

	resp, err := client.Do(req)
	if resp != nil {
		statusCode = resp.StatusCode
		if statusCode != 200 {
			return []byte{}, statusCode, errors.New("invalidHTMLResponseCode: response status code is " + strconv.Itoa(statusCode))
		}
		defer func() { _ = resp.Body.Close() }()
	}

	if err == nil {
		var body []byte
		body, err = ioutil.ReadAll(resp.Body)
		if err == nil {
			return body, statusCode, nil
		} else {
			return []byte{}, statusCode, errors.New("Error in api request - 2")
		}
	} else {
		return []byte{}, statusCode, err
	}
}

func HttpRequests(requestType string, baseUrl string, path string, params map[string]string, headers map[string]string, body interface{}, timeoutMilliSeconds int) ([]byte, int, error) {
	client := http.Client{
		Timeout: time.Duration(timeoutMilliSeconds * 1000 * 1000),
	}

	request := baseUrl + path
	if len(params) != 0 {
		var paramStringList []string
		for key, value := range params {
			paramStringList = append(paramStringList, key+"="+value)
		}
		request += "?" + strings.Join(paramStringList[:], "&")
	}

	var req *http.Request
	if body != nil {
		buf, _ := json.Marshal(body)
		buffer := bytes.NewBuffer(buf)
		req, _ = http.NewRequest(requestType, request, buffer)
		SetHeader(req, "Content-Type", "application/json")
		SetHeader(req, "Content-Length", strconv.Itoa(buffer.Len()))
	} else {
		req, _ = http.NewRequest(requestType, request, nil)
		SetHeader(req, "Content-Type", "application/json")
		SetHeader(req, "Content-Length", strconv.Itoa(0))
	}

	for key, value := range headers {
		SetHeader(req, key, value)
	}
	data, statusCode, err := responseBodyReader(req, &client)

	if err == nil {
		return data, statusCode, nil
	} else {
		return []byte{}, statusCode, err
	}
}
