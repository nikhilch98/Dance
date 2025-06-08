"""Data models for the Nachna API."""

from .auth import (
    UserRegistration,
    UserLogin,
    ProfileUpdate,
    PasswordUpdate,
    UserProfile,
    AuthResponse,
    DeviceTokenRequest,
    ConfigRequest,
)
from .reactions import (
    EntityType,
    ReactionType,
    ReactionRequest,
    ReactionDeleteRequest,
    ReactionResponse,
    UserReactionsResponse,
    ReactionStatsResponse,
)
from .notifications import PushNotificationRequest
from .workshops import (
    TimeDetails,
    WorkshopListItem,
    Artist,
    Studio,
    WorkshopSession,
    DaySchedule,
    CategorizedWorkshopResponse,
    EventDetails,
)
from .admin import (
    AssignArtistPayload,
    AssignSongPayload,
    AnalyzeRequest,
)

# Search models
from .search import SearchUserResult, SearchArtistResult, SearchWorkshopResult

__all__ = [
    # Auth models
    "UserRegistration",
    "UserLogin", 
    "ProfileUpdate",
    "PasswordUpdate",
    "UserProfile",
    "AuthResponse",
    "DeviceTokenRequest",
    "ConfigRequest",
    # Reaction models
    "EntityType",
    "ReactionType",
    "ReactionRequest",
    "ReactionDeleteRequest",
    "ReactionResponse",
    "UserReactionsResponse",
    "ReactionStatsResponse",
    # Notification models
    "PushNotificationRequest",
    # Workshop models
    "TimeDetails",
    "WorkshopListItem",
    "Artist",
    "Studio",
    "WorkshopSession",
    "DaySchedule",
    "CategorizedWorkshopResponse",
    "EventDetails",
    # Search models
    "SearchUserResult",
    "SearchArtistResult",
    "SearchWorkshopResult",
    # Admin models
    "AssignArtistPayload",
    "AssignSongPayload",
    "AnalyzeRequest",
] 