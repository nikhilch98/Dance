"""Application constants and configuration."""


class APIConfig:
    """API configuration and version management."""
    
    SUPPORTED_VERSIONS = ["v2"]
    DEFAULT_VERSION = "v2"
    CORS_ORIGINS = ["*"]  # Allow all origins for development


class APNsConfig:
    """APNs service configuration."""
    
    SANDBOX_URL = "https://api.sandbox.push.apple.com"
    PRODUCTION_URL = "https://api.push.apple.com"


class RateLimitConfig:
    """Rate limiting configuration."""
    
    WINDOW = 60  # 60 seconds
    MAX_REQUESTS = 30  # Max 30 requests per minute per user 