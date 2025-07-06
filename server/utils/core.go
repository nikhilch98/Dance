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
	"github.com/go-rod/rod/lib/launcher"
	"github.com/go-rod/rod/lib/proto"
	rodutils "github.com/go-rod/rod/lib/utils"
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

func GetScreenshotGivenUrl(targetURL, screenshotPath string) *core.NachnaException {
	// ---------- 1. Launch Chromium with the same flags you showed ----------
	fmt.Println("GetScreenshotGivenUrl", targetURL, screenshotPath)
	launch := launcher.New().
		Bin("/usr/bin/chromium-browser").
		Headless(true).
		Proxy(os.Getenv("HTTP_PROXY")). // safe to leave empty
		Set("--single-process").
		Set("--v", "99").
		Set("--enable-webgl").
		Set("--disable-dev-shm-usage").
		Set("--ignore-gpu-blacklist").
		Set("--ignore-certificate-errors").
		Set("--allow-running-insecure-content").
		Set("--disable-extensions").
		Set("--user-data-dir", "/tmp/user-data").
		Set("--data-path", "/tmp/data-path").
		Set("--homedir", "/tmp").
		Set("--disk-cache-dir", "/tmp/cache-dir").
		Set("--no-sandbox").
		Set("--use-gl", "osmesa").
		Set("--window-size", "400,650")
	wsURL, err := launch.Launch()
	if err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("launch chrome: %v", err),
		}
	}
	fmt.Println("jhgmjnhgjhgbfvnhbgfv")
	fmt.Println("Connecting to:", wsURL)
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
	fmt.Println("rgfedwwfeg")
	// ---------- 3. Navigate & wait ----------
	if err = page.Navigate(targetURL); err != nil {
		return &core.NachnaException{
			StatusCode:   500,
			ErrorMessage: fmt.Sprintf("navigate %s: %v", targetURL, err),
		}
	}
	fmt.Println("gfegdwsqadfgbfgdws")
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
