package config

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/joho/godotenv"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	MongoClient *mongo.Client
	DB          *mongo.Database
)

// InitDB initializes the database connection
func InitDB() error {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: No .env file found: %v", err)
	}

	// Load configuration
	cfg, err := LoadConfig()
	if err != nil {
		log.Printf("Warning: Failed to load config: %v", err)
	}

	// Connect to MongoDB with retry logic
	maxRetries := 5
	for i := 0; i < maxRetries; i++ {
		mongoURI := os.Getenv("MONGODB_URI")
		if mongoURI == "" {
			mongoURI = cfg.MongoURI
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		clientOptions := options.Client().ApplyURI(mongoURI)
		MongoClient, err = mongo.Connect(ctx, clientOptions)
		if err == nil {
			// Try to ping the database
			if err = MongoClient.Ping(ctx, nil); err == nil {
				log.Printf("Successfully connected to MongoDB")
				DB = MongoClient.Database(cfg.DBName)
				return nil
			}
		}

		log.Printf("Failed to connect to MongoDB (attempt %d/%d): %v", i+1, maxRetries, err)
		if i < maxRetries-1 {
			time.Sleep(time.Second * time.Duration(i+1))
		}
	}
	return err
}
