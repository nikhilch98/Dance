"""Application settings and configuration."""

import os
import logging
from functools import lru_cache
from typing import Optional
# Use v1 BaseSettings for compatibility
from pydantic.v1 import BaseSettings, validator

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings."""

    # Environment
    app_env: str = os.getenv("APP_ENV", "production")
    debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Security - SECRET_KEY is required in production
    secret_key: str = os.getenv("SECRET_KEY", "")
    algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    access_token_expire_minutes: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "10080"))  # 7 days (reduced from 30)

    # Test mode - only enable in development
    enable_test_user: bool = os.getenv("ENABLE_TEST_USER", "false").lower() == "true"
    test_mobile_number: str = os.getenv("TEST_MOBILE_NUMBER", "9999999999")
    test_otp: str = os.getenv("TEST_OTP", "583647")

    # APNs Configuration - Optional with warnings
    apns_auth_key_id: Optional[str] = os.getenv("APNS_AUTH_KEY_ID")
    apns_team_id: Optional[str] = os.getenv("APNS_TEAM_ID")
    apns_bundle_id: str = os.getenv("APNS_BUNDLE_ID", "com.nachna.nachna")
    apns_key_path: str = os.getenv("APNS_KEY_PATH", "./AuthKey_W5H5A6ZUS2.p8")
    apns_use_sandbox: bool = os.getenv("APNS_USE_SANDBOX", "false").lower() == "true"

    @validator("secret_key", pre=True, always=True)
    def validate_secret_key(cls, v):
        """Validate that secret key is set and secure."""
        if not v or v == "your-secret-key-here-change-in-production":
            env = os.getenv("APP_ENV", "production")
            if env == "production":
                raise ValueError(
                    "SECRET_KEY must be set in production environment. "
                    "Generate a secure key using: python -c \"import secrets; print(secrets.token_hex(32))\""
                )
            # Use a development key for non-production
            logger.warning("⚠️ Using development SECRET_KEY - NOT SECURE FOR PRODUCTION")
            return "dev-secret-key-not-for-production-use"
        if len(v) < 32:
            logger.warning("⚠️ SECRET_KEY is shorter than recommended (32+ characters)")
        return v
    
    # Twilio Configuration
    twilio_account_sid: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    twilio_auth_token: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    twilio_verify_service_sid: str = os.getenv("TWILIO_VERIFY_SERVICE_SID", "")

    razorpay_key_id: str = os.getenv("RAZORPAY_KEY_ID", "")
    razorpay_secret_key: str = os.getenv("RAZORPAY_SECRET_KEY", "")
    razorpay_callback_url: str = "https://nachna.com/api/razorpay/webhook"
    
    # Rate Limiting
    rate_limit_window: int = 60  # seconds
    rate_limit_max_requests: int = 30
    
    # Reward System Configuration
    reward_cashback_percentage: float = 10.0  # 10% cashback on workshop bookings
    reward_redemption_cap_percentage: float = 10.0  # Max 10% of workshop cost can be redeemed
    reward_redemption_cap_per_workshop: float = 50.0  # Max 50 rupees redeemable per workshop
    reward_exchange_rate: float = 1.0  # 1 reward point = 1 rupee
    reward_welcome_bonus: float = 100.0  # Welcome bonus in rupees
    
    # Server Configuration
    host: str = "127.0.0.1"
    port: int = 8002
    workers: int = 4
    reload: bool = False
    log_level: str = "info"
    
    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    """Get cached application settings."""
    settings = Settings()

    # Log warnings for missing optional configs
    if not settings.apns_auth_key_id:
        logger.warning("⚠️ APNS_AUTH_KEY_ID not set - push notifications will not work")
    if not settings.apns_team_id:
        logger.warning("⚠️ APNS_TEAM_ID not set - push notifications will not work")
    if settings.enable_test_user:
        logger.warning("⚠️ Test user mode is ENABLED - disable in production (ENABLE_TEST_USER=false)")

    return settings 