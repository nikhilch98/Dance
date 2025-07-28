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
	return config
}
