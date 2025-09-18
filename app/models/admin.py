"""Admin-related data models."""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, HttpUrl


class AssignArtistPayload(BaseModel):
    """Payload for assigning artists to a workshop."""
    artist_id_list: List[str]
    artist_name_list: List[str]


class AssignSongPayload(BaseModel):
    """Payload for assigning a song to a workshop."""
    song: str


class AnalyzeRequest(BaseModel):
    """Request model for the analysis endpoint."""
    link: HttpUrl
    ai_model: str  # 'openai' or 'gemini' 

class CreateArtistPayload(BaseModel):
    """Payload for creating a new artist."""
    artist_id: str
    artist_name: str


class QRVerificationRequest(BaseModel):
    """Request model for QR code verification."""
    qr_data: str


class QRVerificationResponse(BaseModel):
    """Response model for QR code verification."""
    valid: bool
    error: Optional[str] = None
    registration_data: Optional[Dict[str, Any]] = None
    verification_details: Optional[Dict[str, Any]] = None


class RegistrationData(BaseModel):
    """Model for registration data extracted from QR code."""
    order_id: str
    workshop: Dict[str, Any]
    registration: Dict[str, Any]
    verification: Dict[str, Any]
    payment: Optional[Dict[str, Any]] = None


class MarkAttendanceRequest(BaseModel):
    """Request model for marking attendance."""
    order_id: str


class MarkAttendanceResponse(BaseModel):
    """Response model for attendance marking."""
    success: bool
    message: str
    order_id: str
    marked_at: Optional[str] = None