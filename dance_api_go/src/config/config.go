package config

import (
	"encoding/json"
	"os"
)

// Config holds all configuration for the application
type Config struct {
	Port      string `json:"port"`
	MongoURI  string `json:"mongo_uri"`
	DBName    string `json:"db_name"`
	StaticDir string `json:"static_dir"`
}

// LoadConfig loads configuration from config.json
func LoadConfig() (*Config, error) {
	file, err := os.Open("config.json")
	if err != nil {
		return &Config{
			Port:      "8002",
			MongoURI:  "mongodb://localhost:27017",
			DBName:    "discovery",
			StaticDir: "static",
		}, nil
	}
	defer file.Close()

	var config Config
	if err := json.NewDecoder(file).Decode(&config); err != nil {
		return nil, err
	}

	return &config, nil
}
