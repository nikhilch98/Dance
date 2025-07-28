package ai

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"nachna/core"
	"nachna/utils"
	"os"
	"sync"
	"time"

	"github.com/openai/openai-go"
)

var lockOpenAI = &sync.Mutex{}

type OpenAIAnalyzer struct{}

func (a *OpenAIAnalyzer) generateSystemPrompt(artistsDataList []map[string]string, currentDateTime string) (string, *core.NachnaException) {
	// Convert artists data to JSON string for the prompt
	artistsJSON, err := json.Marshal(artistsDataList)
	if err != nil {
		return "", &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to marshal artists data while generating system prompt",
		}
	}
	artistsStr := string(artistsJSON)

	return "You are given data about an event (potentially a dance workshop, intensive, or regulars class). " +
		"You must analyze the provided text and image (the screenshot) to determine " +
		"the type of event and extract its details if it's a Bangalore-based dance event.\n\n" +
		"Artists Data for additional context : " + artistsStr + "\n\n" +
		"Current Date for reference : " + currentDateTime + "\n\n" +
		"1. Determine if the event is a dance workshop, intensive, or regulars class based in Bangalore.\n" +
		"2. If it is NOT a valid Bangalore-based dance event OR if the event is in the past (the definition of past is if the day is before the current date. Lets take an example : If current date is 15th July 2025 05:00PM, Case 1: if Event is on 15th july 2025 04:00PM, then it is considered valid since the event is on the same day and not in the past, Case 2: if Event is on 16th july 2025 04:00PM, then it is valid since the event is in the future, Case 3: if Event is on 14th july 2025 04:00PM, then it is invalid since the event is in the past), set `is_valid` to `false`, " +
		"   `event_type` to null, and provide an empty list for `event_details`.\n" +
		"3. If it IS a valid Bangalore-based dance event, set `is_valid` to `true`, determine the `event_type` ('workshop', 'intensive', or 'regulars'), and " +
		"   return a list of one or more event objects under `event_details` with the " +
		"   following structure:\n\n" +
		"   **`event_details`:** (array of objects)\n" +
		"   Each object must have:\n" +
		"   - **`time_details`:** (array of objects) Each time object contains details for one session/day:\n" +
		"     * **`day`**: integer day of the month (null if not found)\n" +
		"     * **`month`**: integer month (1–12) (null if not found)\n" +
		"     * **`year`**: 4-digit year (null if not found).\n" +
		"       - If no year is specified but the event date is clearly in the future relative to the current date, " +
		"         choose the earliest valid future year. Otherwise, use the current year if the month/day suggest it's upcoming, or null.\n" +
		"     * **`start_time`**: string, 12-hour format \"HH:MM AM/PM\" with leading zeros (e.g., \"01:00 PM\", \"05:30 AM\"). Null if not found.\n" +
		"     * **`end_time`**: string, 12-hour format \"HH:MM AM/PM\" with leading zeros (e.g., \"01:00 PM\", \"05:30 AM\"). Null if not found.\n" +
		"     * NOTE: Only intensives or regulars typically have multiple entries in `time_details` array (for multiple days/sessions). Workshops usually have only one.\n\n" +
		"   - **`by`**: string with the instructor's name(s). If multiple, use ' X ' to separate. Null if not found.\n" +
		"   - **`song`**: string with the routine/song name if available, else null.\n" +
		"   - **`pricing_info`**: string if pricing is found, else null. Format multiple tiers/options separated by a newline character '\\n'. Do not include taxes/fees like GST , Service charge , etc. \n" +
		"   - **`artist_id_list`**: array of strings. If the instructor(s) in `by` match entries in the provided artists list, use those `artist_id`s; otherwise empty array. For multiple instructors, include all matching artist_ids.\n\n" +
		"   **IMPORTANT Extraction Notes**:\n" +
		"   - If multiple distinct classes/routines are offered within the same event post (e.g., different songs/styles with separate pricing/times), create a separate object in `event_details` for each.\n" +
		"   - If different routines share the same date/time, use the same `time_details` object(s) for each corresponding `event_details` object.\n" +
		"   - Prioritize information from sections explicitly labeled 'Workshop Details', 'Event Details', 'Session Details', 'About Event', etc., especially for timings, song, and pricing.\n" +
		"   - For 'Dance N Addiction' studio posts specifically, look for an 'About event details' or 'session details' section for potentially more accurate information.\n\n" +
		"4. Only return a valid JSON object with this exact structure:\n" +
		"   ```json\n" +
		"   {\n" +
		"       \"is_valid\": <boolean>,\n" +
		"       \"event_type\": <\"workshop\" | \"intensive\" | \"regulars\" | null>,\n" +
		"       \"event_details\": [\n" +
		"           {\n" +
		"               \"time_details\": [\n" +
		"                   {\n" +
		"                       \"day\": <int | null>,\n" +
		"                       \"month\": <int | null>,\n" +
		"                       \"year\": <int | null>,\n" +
		"                       \"start_time\": <string | null>,\n" +
		"                       \"end_time\": <string | null>\n" +
		"                   }\n" +
		"                   // ... more time objects if applicable (intensive/regulars)\n" +
		"               ],\n" +
		"               \"by\": <string | null>,\n" +
		"               \"song\": <string | null>,\n" +
		"               \"pricing_info\": <string | null>,\n" +
		"               \"artist_id_list\": <array of strings>\n" +
		"           }\n" +
		"           // ... more event objects if applicable (multiple distinct routines)\n" +
		"       ]\n" +
		"   }\n" +
		"   ```\n\n" +
		"5. Do not include any extra text, explanations, or formatting outside the JSON structure.\n" +
		"6. Ensure all string values in the JSON are properly escaped.\n" +
		"7. Use the provided `artists` data *only* for matching and populating `artist_id_list`. Do not infer other details from it.\n" +
		"8. Return only the raw JSON object.", nil
}

func (a *OpenAIAnalyzer) Analyze(screenshotPath string, artistsDataList []map[string]string) (*EventSummary, *core.NachnaException) {
	client := openai.NewClient()
	// Generate schema for the response
	eventSymmarySchema := utils.GenerateSchema[EventSummary]()
	schemaParam := openai.ResponseFormatJSONSchemaJSONSchemaParam{
		Name:        "event_summary",
		Description: openai.String("Notable information about a dance event"),
		Schema:      eventSymmarySchema,
		Strict:      openai.Bool(true),
	}
	// Generate system prompt
	systemPrompt, systemPromptErr := a.generateSystemPrompt(artistsDataList, time.Now().Format("January 2, 2006"))
	if systemPromptErr != nil {
		return nil, systemPromptErr
	}
	// Read screenshot file
	imageBytes, err := os.ReadFile(screenshotPath)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to read screenshot file",
		}
	}
	base64Image := base64.StdEncoding.EncodeToString(imageBytes)
	// Send request to OpenAI API
	chat, openAIErr := client.Chat.Completions.New(context.TODO(), openai.ChatCompletionNewParams{
		Messages: []openai.ChatCompletionMessageParamUnion{
			openai.SystemMessage(systemPrompt),
			openai.UserMessage([]openai.ChatCompletionContentPartUnionParam{
				openai.TextContentPart("Description of the workshop"),
				openai.ImageContentPart(openai.ChatCompletionContentPartImageImageURLParam{
					URL:    fmt.Sprintf("data:image/png;base64,%s", base64Image),
					Detail: "high",
				}),
			}),
		},
		ResponseFormat: openai.ChatCompletionNewParamsResponseFormatUnion{
			OfJSONSchema: &openai.ResponseFormatJSONSchemaParam{
				JSONSchema: schemaParam,
			},
		},
		// only certain models can perform structured outputs
		Model: openai.ChatModelGPT4o2024_08_06,
	})
	if openAIErr != nil {
		return nil, &core.NachnaException{
			LogMessage:   openAIErr.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to send request to OpenAI API",
		}
	}
	var eventSummary EventSummary
	err = json.Unmarshal([]byte(chat.Choices[0].Message.Content), &eventSummary)
	if err != nil {
		return nil, &core.NachnaException{
			LogMessage:   err.Error(),
			StatusCode:   500,
			ErrorMessage: "Failed to unmarshal response from OpenAI API",
		}
	}

	// Wait for 2 seconds to avoid rate limit
	time.Sleep(2 * time.Second)

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
