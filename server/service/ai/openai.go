package ai

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"nachna/core"
	"time"
)

var lockOpenAI = &sync.Mutex{}

type OpenAIAnalyzer struct{}

func (a *OpenAIAnalyzer) generateSystemPrompt(artistsDataList []map[string]string, currentDateTime string) string {
	return ""
}

func (a *OpenAIAnalyzer) Analyze(screenshotPath string, artistsDataList []map[string]string, modelVersion string) (*EventSummary, *core.NachnaException) {
	imageBytes, err := os.ReadFile(screenshotPath)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to read screenshot file",
		}
	}
	base64Image := base64.StdEncoding.EncodeToString(imageBytes)

	prompt := a.generateSystemPrompt(artistsDataList, time.Now().Format("January 2, 2006"))

	requestBody := map[string]interface{}{
		"model": modelVersion,
		"messages": []map[string]interface{}{
			{
				"role":    "system",
				"content": prompt,
			},
			{
				"role": "user",
				"content": []map[string]interface{}{
					{
						"type": "text",
						"text": "Description of the workshop",
					},
					{
						"type": "image_url",
						"image_url": map[string]interface{}{
							"url":    fmt.Sprintf("data:image/png;base64,%s", base64Image),
							"detail": "high",
						},
					},
				},
			},
		},
		"response_format": "json",
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to serialize request body",
		}
	}

	req, err := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to create HTTP request",
		}
	}
	req.Header.Set("Authorization", "Bearer "+os.Getenv("OPENAI_API_KEY"))
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   502,
			ErrorMessage: "Error contacting OpenAI API",
		}
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to read OpenAI response body",
		}
	}

	if resp.StatusCode >= 400 {
		return nil, &core.NachnaException{
			LogMessage:   string(respBody),
			StatusCode:   resp.StatusCode,
			ErrorMessage: "OpenAI returned an error",
		}
	}

	var parsedResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(respBody, &parsedResp); err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to parse OpenAI response wrapper",
		}
	}

	if len(parsedResp.Choices) == 0 {
		return nil, &core.NachnaException{
			LogMessage:   "empty choices array",
			StatusCode:   500,
			ErrorMessage: "OpenAI returned no choices",
		}
	}

	var eventSummary EventSummary
	if err := json.Unmarshal([]byte(parsedResp.Choices[0].Message.Content), &eventSummary); err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to unmarshal EventSummary from GPT content",
		}
	}

	if strings.Contains(modelVersion, "gpt") {
		time.Sleep(2 * time.Second)
	}

	return &eventSummary, nil
}

var openAIAnalyzer *OpenAIAnalyzer

func (OpenAIAnalyzer) GetInstance() AIAnalyzer {
	if openAIAnalyzer == nil {
		lockOpenAI.Lock()
		defer lockOpenAI.Unlock()
		if openAIAnalyzer == nil {
			openAIAnalyzer = &OpenAIAnalyzer{}
		}
	}
	return openAIAnalyzer
}
