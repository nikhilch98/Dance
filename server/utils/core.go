package utils

import (
	"fmt"
	"nachna/core"
	"nachna/models/response"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/proto"
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

func GetScreenshotGivenUrl(url string, screenshotPath string) *core.NachnaException {
	browser := rod.New().Timeout(30 * time.Second)
	if err := browser.Connect(); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("rod connect error: %v", err),
		}
	}
	defer browser.Close()

	page, err := browser.Page(proto.TargetCreateTarget{URL: "about:blank"})
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("new page error: %v", err),
		}
	}

	if err = page.Navigate(url); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("navigate error (%s): %v", url, err),
		}
	}
	page.WaitLoad()

	img, err := page.Screenshot(true, &proto.PageCaptureScreenshot{})
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("screenshot error (%s): %v", url, err),
		}
	}

	if err := os.MkdirAll(filepath.Dir(screenshotPath), 0o755); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("mkdir error (%s): %v", screenshotPath, err),
		}
	}

	if err := os.WriteFile(screenshotPath, img, 0o644); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("write file error (%s): %v", screenshotPath, err),
		}
	}

	return nil
}
