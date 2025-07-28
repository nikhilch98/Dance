package utils

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"nachna/core"
	"nachna/models/response"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/launcher"
	"github.com/go-rod/rod/lib/proto"
	rodutils "github.com/go-rod/rod/lib/utils"
	"github.com/invopop/jsonschema"
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
		if strings.HasPrefix(arrItem, startsWith) {
			if _, exists := seen[arrItem]; !exists {
				seen[arrItem] = true
				filtered = append(filtered, arrItem)
			}
		}
	}
	return filtered
}

func GetScreenshotGivenUrl(targetURL, screenshotPath string) *core.NachnaException {
	// ---------- 1. Launch Chromium with the same flags you showed ----------
	launch := launcher.New().
		Headless(true).
		NoSandbox(true). // helper wrapper for --no-sandbox
		RemoteDebuggingPort(9222)
	wsURL, err := launch.Launch()
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("launch chrome: %v", err),
		}
	}
	// ---------- 2. Connect, ignore cert errors, emulate device ----------
	browser := rod.New().ControlURL(wsURL).MustConnect()
	defer browser.MustClose()
	browser.MustIgnoreCertErrors(true)

	page, err := browser.Page(proto.TargetCreateTarget{URL: "about:blank"})
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("new page: %v", err),
		}
	}
	// ---------- 3. Navigate & wait ----------
	if err = page.Navigate(targetURL); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("navigate %s: %v", targetURL, err),
		}
	}
	page.WaitLoad()

	img, err := page.Screenshot(true, &proto.PageCaptureScreenshot{})
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("screenshot error (%s): %v", targetURL, err),
		}
	}

	// ---------- 5. Write file (ensure parent dir exists) ----------
	if err := os.MkdirAll(filepath.Dir(screenshotPath), 0o755); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("mkdir error (%s): %v", screenshotPath, err),
		}
	}
	if err := rodutils.OutputFile(screenshotPath, img); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("write file error (%s): %v", screenshotPath, err),
		}
	}

	return nil // 👍 success
}

func GenerateSchema[T any]() interface{} {
	// Structured Outputs uses a subset of JSON schema
	// These flags are necessary to comply with the subset
	reflector := jsonschema.Reflector{
		AllowAdditionalProperties: false,
		DoNotReference:            true,
	}
	var v T
	schema := reflector.Reflect(v)
	return schema
}

func StringPtrSliceToStringSlice(s []*string) []string {
	if s == nil {
		return []string{}
	}
	result := make([]string, len(s))
	for i, item := range s {
		if item != nil {
			result[i] = *item
		}
	}
	return result
}
