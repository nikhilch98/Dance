"""API routes for the Nachna API."""

from .auth import router as auth_router
from .workshops import router as workshops_router
from .reactions import router as reactions_router
from .notifications import router as notifications_router
from .admin import router as admin_router
from .web import router as web_router
from .search import router as search_router
from .mcp import router as mcp_router
from .razorpay import router as razorpay_router
from .orders import router as orders_router
from .rewards import router as rewards_router
from .version import router as version_router
from .reels import router as reels_router

__all__ = [
    "auth_router",
    "workshops_router",
    "reactions_router",
    "notifications_router",
    "admin_router",
    "web_router",
    "search_router",
    "mcp_router",
    "razorpay_router",
    "orders_router",
    "rewards_router",
    "version_router",
    "reels_router",
] 