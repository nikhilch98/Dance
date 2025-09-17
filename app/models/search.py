"""Search-related data models."""

from typing import List, Optional
from pydantic import BaseModel, HttpUrl
from datetime import datetime


class SearchUserResult(BaseModel):
    """User search result model."""
    user_id: str
    name: str
    profile_picture_url: Optional[str] = None
    created_at: datetime


class SearchArtistResult(BaseModel):
    """Artist search result model."""
    id: str
    name: str
    image_url: Optional[HttpUrl] = None
    instagram_link: HttpUrl


class SearchWorkshopResult(BaseModel):
    """Workshop search result model."""
    uuid: str
    song: Optional[str]
    artist_names: List[str]
    artist_id_list: Optional[List[str]] = None
    artist_image_urls: Optional[List[Optional[str]]] = None
    studio_id: Optional[str] = None
    studio_name: str
    date: str
    time: str
    timestamp_epoch: int
    payment_link: str
    payment_link_type: str
    pricing_info: Optional[str] = None
    current_price: Optional[float] = None  # Current price in rupees based on tiered pricing
    event_type: Optional[str] = None
    choreo_insta_link: Optional[str] = None 