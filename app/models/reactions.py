"""Reaction system data models."""

from datetime import datetime
from typing import List
from enum import Enum
from pydantic import BaseModel, Field


class EntityType(str, Enum):
    """Enum for entity types that can be reacted to."""
    ARTIST = "ARTIST"


class ReactionType(str, Enum):
    """Enum for reaction types."""
    LIKE = "LIKE"
    NOTIFY = "NOTIFY"


class ReactionRequest(BaseModel):
    """Request model for creating/updating reactions."""
    entity_id: str = Field(..., min_length=1)
    entity_type: EntityType
    reaction: ReactionType


class ReactionDeleteRequest(BaseModel):
    """Request model for soft deleting reactions."""
    reaction_id: str = Field(..., min_length=1)


class ReactionResponse(BaseModel):
    """Response model for reactions."""
    id: str
    user_id: str
    entity_id: str
    entity_type: EntityType
    reaction: ReactionType
    created_at: datetime
    updated_at: datetime
    is_deleted: bool = False


class UserReactionsResponse(BaseModel):
    """Response model for user's reactions grouped by entity type."""
    liked_artists: List[str] = []
    notified_artists: List[str] = []


class ReactionStatsResponse(BaseModel):
    """Response model for reaction statistics."""
    entity_id: str
    entity_type: EntityType
    like_count: int = 0
    notify_count: int = 0 