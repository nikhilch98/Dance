import os
import argparse
import sys

# Production MongoDB connection string
PROD_MONGODB_URI = "mongodb+srv://admin:admin@cluster0.8czn7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"

DEFAULT_ENV = "prod"
DEFAULT_AI_MODEL = "openai"


class Config:
    """Configuration management for development and production environments."""

    def __init__(self, env=DEFAULT_ENV, ai_model=DEFAULT_AI_MODEL):
        """Initialize configuration based on environment."""
        if env == "dev":
            self.host = "localhost"
            self.port = 27017
            self.username = "admin"
            self.password = "admin"
            self.db_name = "admin"
            self.mongodb_uri = (
                f"mongodb://{self.username}:{self.password}@{self.host}:{self.port}/"
            )
        elif env == "prod":
            self.host = "cluster0.8czn7.mongodb.net"
            self.port = 27017
            self.username = "admin"
            self.password = "admin"
            self.db_name = "admin"
            self.mongodb_uri = f"mongodb+srv://{self.username}:{self.password}@{self.host}/?retryWrites=true&w=majority&appName=Cluster0"

        else:
            raise ValueError(f"Invalid environment: {env}. Use 'dev' or 'prod'.")
        self.ai_model = ai_model
        # OpenAI API Key (consider using environment variable)
        self.openai_api_key = os.environ.get("OPENAI_API_KEY")
        self.gemini_api_key = os.environ.get("GEMINI_API_KEY")
        self.gemini_base_url = "https://generativelanguage.googleapis.com/v1beta/openai/"