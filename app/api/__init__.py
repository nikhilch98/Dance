"""API routes for the Nachna API."""

from .auth import router as auth_router
from .workshops import router as workshops_router
from .reactions import router as reactions_router
from .notifications import router as notifications_router
from .admin import router as admin_router
from .web import router as web_router
from .search import router as search_router

__all__ = [
    "auth_router",
    "workshops_router", 
    "reactions_router",
    "notifications_router",
    "admin_router",
    "web_router",
    "search_router",
] 