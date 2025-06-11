"""Authentication-related data models."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class SendOTPRequest(BaseModel):
    """Send OTP request model."""
    mobile_number: str = Field(..., pattern=r"^\d{10}$", description="10-digit mobile number without country code")


class VerifyOTPRequest(BaseModel):
    """Verify OTP request model."""
    mobile_number: str = Field(..., pattern=r"^\d{10}$", description="10-digit mobile number without country code")
    otp: str = Field(..., pattern=r"^\d{6}$", description="6-digit OTP code")


class ProfileUpdate(BaseModel):
    """Profile update request model."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    date_of_birth: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    gender: Optional[str] = Field(None, pattern=r"^(male|female|other)$")





class UserProfile(BaseModel):
    """User profile response model."""
    user_id: str
    mobile_number: str
    name: Optional[str]
    date_of_birth: Optional[str]
    gender: Optional[str]
    profile_picture_url: Optional[str] = None
    profile_picture_id: Optional[str] = None
    profile_complete: bool
    is_admin: Optional[bool] = False
    created_at: datetime
    updated_at: datetime
    device_token: Optional[str] = None


class AuthResponse(BaseModel):
    """Authentication response model."""
    access_token: str
    token_type: str
    user: UserProfile


class DeviceTokenRequest(BaseModel):
    """Request model for device token registration."""
    device_token: str
    platform: str = Field(..., pattern=r"^(ios|android)$")


class ConfigRequest(BaseModel):
    """Request model for app config with optional device token."""
    device_token: Optional[str] = None
    platform: Optional[str] = Field(None, pattern=r"^(ios|android)$") 