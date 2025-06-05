"""Notification-related data models."""

from typing import List, Dict, Optional
from pydantic import BaseModel


class PushNotificationRequest(BaseModel):
    """Request model for sending push notifications."""
    user_ids: List[str]
    title: str
    body: str
    data: Optional[Dict[str, str]] = None 