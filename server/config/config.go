package config

import (
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
)

type Configuration struct {
	Env             string `json:"env"`
	HttpPort        int    `json:"http_port"`
	WebBasedStudios []struct {
		Url      string `json:"url"`
		Name     string `json:"name"`
		BaseUrl  string `json:"base_url"`
		MaxDepth int    `json:"max_depth"`
	} `json:"web_based_studios"`
	ApiContextPath string `json:"api_context_path"`
	MongoDB        struct {
		Uri string `json:"uri"`
	} `json:"mongodb"`
	NewRelic struct {
		AppName    string `json:"app_name"`
		LicenseKey string `json:"license_key"`
		IsEnabled  bool   `json:"is_enabled"`
	} `json:"new_relic"`
}

var Config Configuration

func init() {
	Config = LoadConfig()
}

func LoadConfig() Configuration {
	var config Configuration
	configFile, err := os.Open("config.json")
	if err != nil {
		log.Fatal("Error in reading config file", err)
	}
	defer configFile.Close()
	configBytes, _ := ioutil.ReadAll(configFile)
	err = json.Unmarshal(configBytes, &config)
	if err != nil {
		log.Fatal("Error in unmarshalling config file", err)
	}

	// Override with environment variables if they exist
	if mongoUri := os.Getenv("MONGODB_URI"); mongoUri != "" {
		config.MongoDB.Uri = mongoUri
	}

	if newRelicAppName := os.Getenv("NEW_RELIC_APP_NAME"); newRelicAppName != "" {
		config.NewRelic.AppName = newRelicAppName
	}

	if newRelicLicenseKey := os.Getenv("NEW_RELIC_LICENSE_KEY"); newRelicLicenseKey != "" {
		config.NewRelic.LicenseKey = newRelicLicenseKey
	}

	if newRelicEnabled := os.Getenv("NEW_RELIC_ENABLED"); newRelicEnabled != "" {
		config.NewRelic.IsEnabled = newRelicEnabled == "true"
	}

	// Override API keys in web-based studios if environment variables exist
	for i := range config.WebBasedStudios {
		studio := &config.WebBasedStudios[i]
		if studio.Name == "dance_n_addiction" {
			if apiKey := os.Getenv("YOACTIV_API_KEY_DANCE_N_ADDICTION"); apiKey != "" {
				// Extract the API key parameter from the URL and replace it
				studio.Url = "https://www.yoactiv.com/eventplugin.aspx?Apikey=" + apiKey
			}
		} else if studio.Name == "manifestbytmn" {
			if apiKey := os.Getenv("YOACTIV_API_KEY_MANIFEST_BY_TMN"); apiKey != "" {
				// Extract the API key parameter from the URL and replace it
				studio.Url = "https://www.yoactiv.com/eventplugin.aspx?Apikey=" + apiKey
			}
		}
	}

	return config
}
