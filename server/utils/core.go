package utils

import (
	"nachna/models/response"
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"
)

func ContainsString(s []string, e string) bool {
	for _, a := range s {
		if a == e {
			return true
		}
	}
	return false
}

func Unmarshal[T any](bytes []byte) (*T, error) {
	out := new(T)
	if err := json.Unmarshal(bytes, out); err != nil {
		return nil, err
	}
	return out, nil
}

func GetEncodedCursor(data response.Cursor) string {

	jsonString, _ := json.Marshal(data)
	sEnc := base64.StdEncoding.EncodeToString(jsonString)
	return sEnc
}

func GetCurrentDatetimeString() string {
	return time.Now().UTC().Format("2006-01-02T15:04:05.000000Z")
}

func GetKeysFromSet(s map[string]bool) []string {
	keys := make([]string, 0)
	for val, _ := range s {
		keys = append(keys, val)
	}
	return keys
}

func Stringify(s interface{}) string {
	val, _ := json.Marshal(s)
	return string(val)
}

func GetStringSetWithRegexFilters(arr []string, startsWith string) []string {
	seen := make(map[string]bool)
	var filtered []string

	for _, arrItem := range arr {
		lowerArritem := strings.ToLower(arrItem)
		if strings.HasPrefix(lowerArritem, startsWith) {
			if _, exists := seen[lowerArritem]; !exists {
				seen[lowerArritem] = true
				filtered = append(filtered, lowerArritem)
			}
		}
	}
	return filtered
}
