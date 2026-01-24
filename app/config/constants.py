"""Application constants and configuration."""

import os


class APIConfig:
    """API configuration and version management."""

    SUPPORTED_VERSIONS = ["v2"]
    DEFAULT_VERSION = "v2"

    # CORS Configuration - Specific origins for security
    # Add/remove origins based on your deployment
    CORS_ORIGINS = [
        # Production domains
        "https://nachna.com",
        "https://www.nachna.com",
        "https://api.nachna.com",
        # Development (only if APP_ENV is not production)
        *([
            "http://localhost:3000",
            "http://localhost:8000",
            "http://localhost:8002",
            "http://127.0.0.1:3000",
            "http://127.0.0.1:8000",
            "http://127.0.0.1:8002",
        ] if os.getenv("APP_ENV", "production") != "production" else [])
    ]


class APNsConfig:
    """APNs service configuration."""

    SANDBOX_URL = "https://api.sandbox.push.apple.com"
    PRODUCTION_URL = "https://api.push.apple.com"


class RateLimitConfig:
    """Rate limiting configuration."""

    # General rate limits
    WINDOW_SECONDS = 60  # Window size in seconds
    MAX_REQUESTS_PER_WINDOW = 30  # Max requests per window per user

    # OTP specific rate limits
    OTP_SEND_MAX_PER_MOBILE = 3  # Max OTP sends per mobile per window
    OTP_SEND_MAX_PER_IP = 10  # Max OTP sends per IP per window
    OTP_VERIFY_MAX_ATTEMPTS = 5  # Max OTP verification attempts
    OTP_LOCKOUT_MINUTES = 15  # Lockout duration after max attempts


class CacheConfig:
    """Cache configuration."""

    # Cache TTLs in seconds
    WORKSHOPS_TTL = 3600  # 1 hour
    ARTISTS_TTL = 3600  # 1 hour
    STUDIOS_TTL = 3600  # 1 hour
    CONFIG_TTL = 300  # 5 minutes
    IMAGE_TTL = 3600  # 1 hour


class OrderStatus:
    """Order status constants."""

    CREATED = "created"
    PENDING = "pending"
    PAID = "paid"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    REFUNDED = "refunded" 