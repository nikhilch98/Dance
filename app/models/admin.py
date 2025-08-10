"""Admin-related data models."""

from typing import List
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