import os
import argparse
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

DEFAULT_ENV = "prod"
DEFAULT_AI_MODEL = "openai"


class Config:
    """Configuration management for development and production environments."""

    def __init__(self, env=DEFAULT_ENV, ai_model=DEFAULT_AI_MODEL):
        """Initialize configuration based on environment."""
        self.env = env
        # Get MongoDB URI from environment variables
        if env == "dev":
            self.mongodb_uri = os.environ.get("MONGODB_DEV_URI", "mongodb://admin:admin@localhost:27017/")
        elif env == "prod":
            self.mongodb_uri = os.environ.get("MONGODB_URI", "mongodb+srv://admin:admin@cluster0.8czn7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0")
        else:
            raise ValueError(f"Invalid environment: {env}. Use 'dev' or 'prod'.")

        self.ai_model = ai_model
        # API Keys from environment variables
        self.openai_api_key = os.environ.get("OPENAI_API_KEY")
        self.gemini_api_key = os.environ.get("GEMINI_API_KEY")
        self.gemini_base_url = os.environ.get("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai/")