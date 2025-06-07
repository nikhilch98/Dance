"""Workshop-related data models."""

from typing import List, Optional
from pydantic import BaseModel, HttpUrl


class TimeDetails(BaseModel):
    """Time details for a workshop session."""
    day: int
    month: int
    year: int
    start_time: str
    end_time: Optional[str] = None


class WorkshopListItem(BaseModel):
    """Complete workshop information including all sessions."""
    uuid: str
    payment_link: HttpUrl
    studio_id: str
    studio_name: str
    updated_at: float
    by: Optional[str]
    song: Optional[str]
    pricing_info: Optional[str]
    timestamp_epoch: int
    artist_id_list: Optional[List[str]] = []
    artist_image_urls: Optional[List[Optional[HttpUrl]]] = []
    date: Optional[str]
    time: Optional[str]
    event_type: Optional[str]
    choreo_insta_link: Optional[HttpUrl]


class Artist(BaseModel):
    """Artist profile information."""
    id: str
    name: str
    image_url: Optional[HttpUrl]
    instagram_link: HttpUrl


class Studio(BaseModel):
    """Studio profile information."""
    id: str
    name: str
    image_url: Optional[HttpUrl]
    instagram_link: HttpUrl


class WorkshopSession(BaseModel):
    """Individual workshop session information."""
    date: str
    time: str
    song: Optional[str]
    studio_id: Optional[str]
    artist: Optional[str]
    artist_id_list: Optional[List[str]] = []
    payment_link: HttpUrl
    pricing_info: Optional[str]
    timestamp_epoch: int
    event_type: Optional[str]
    choreo_insta_link: Optional[HttpUrl]


class DaySchedule(BaseModel):
    """Schedule of workshops for a specific day."""
    day: str
    workshops: List[WorkshopSession]


class CategorizedWorkshopResponse(BaseModel):
    """Response structure for workshops categorized by week."""
    this_week: List[DaySchedule]
    post_this_week: List[WorkshopSession]


class EventDetails(BaseModel):
    """Event details model for workshop processing."""
    mongo_id: str
    payment_link: str
    studio_id: str
    uuid: str
    event_type: str
    artist_name: Optional[str]
    artist_id_list: Optional[List[str]] = []
    song: Optional[str]
    pricing_info: Optional[str]
    updated_at: float
    date_without_day: str
    date_with_day: str
    time_str: str
    timestamp_epoch: int
    time_year: Optional[int]
    time_month: Optional[int]
    time_day: Optional[int]
    time_day_full_string: Optional[str] 
    choreo_insta_link: Optional[HttpUrl]