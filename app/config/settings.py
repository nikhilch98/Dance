"""Application settings and configuration."""

import os
from functools import lru_cache
try:
    from pydantic_settings import BaseSettings
except ImportError:
    from pydantic import BaseSettings


class Settings(BaseSettings):
    """Application settings."""
    
    # Security
    secret_key: str = "your-secret-key-here-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30 * 24 * 60  # 30 days
    
    # APNs Configuration
    apns_auth_key_id: str = "W5H5A6ZUS2"
    apns_team_id: str = "TJ9YTH589R"
    apns_bundle_id: str = "com.nachna.nachna"
    apns_key_path: str = "./AuthKey_W5H5A6ZUS2.p8"
    apns_use_sandbox: bool = False
    
    # Rate Limiting
    rate_limit_window: int = 60  # seconds
    rate_limit_max_requests: int = 30
    
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
    return Settings() 