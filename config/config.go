package config

import (
	"flag"
	"os"
)

// Constants for environment
const (
	DefaultEnv     = "prod"
	ProdMongoDBURI = "mongodb+srv://admin:admin@cluster0.8czn7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
)

// Config holds application configuration
type Config struct {
	Host         string
	Port         int
	Username     string
	Password     string
	DBName       string
	MongoDBURI   string
	OpenAIAPIKey string
}

// NewConfig creates a new configuration based on environment
func NewConfig(env string) *Config {
	cfg := &Config{}

	if env == "dev" {
		cfg.Host = "localhost"
		cfg.Port = 27017
		cfg.Username = "admin"
		cfg.Password = "admin"
		cfg.DBName = "admin"
		cfg.MongoDBURI = "mongodb://" + cfg.Username + ":" + cfg.Password + "@" + cfg.Host + ":" + "27017" + "/"
	} else if env == "prod" {
		cfg.Host = "cluster0.8czn7.mongodb.net"
		cfg.Port = 27017
		cfg.Username = "admin"
		cfg.Password = "admin"
		cfg.DBName = "admin"
		cfg.MongoDBURI = ProdMongoDBURI
	}

	// Get OpenAI API Key from environment or use default
	cfg.OpenAIAPIKey = os.Getenv("OPENAI_API_KEY")
	if cfg.OpenAIAPIKey == "" {
		cfg.OpenAIAPIKey = "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"
	}

	return cfg
}

// ParseArgs parses command-line arguments for environment configuration
func ParseArgs() *Config {
	_ = flag.Bool("dev", false, "Run in development environment")
	prodFlag := flag.Bool("prod", false, "Run in production environment")

	flag.Parse()

	if *prodFlag {
		return NewConfig("prod")
	}

	return NewConfig("dev")
}
