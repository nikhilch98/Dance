"""Main FastAPI application for the Nachna Dance Workshop API."""

import asyncio
import uvicorn
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.config.constants import APIConfig
from app.config.settings import get_settings
from app.config.logging_config import AppLogger, get_logger
from app.middleware.logging import log_response_time_middleware
from app.middleware.request_id import RequestIdMiddleware
from app.api import (
    auth_router,
    workshops_router,
    reactions_router,
    notifications_router,
    admin_router,
    web_router,
    search_router,
    mcp_router,
    razorpay_router,
    orders_router,
    rewards_router,
    version_router,
    reels_router,
)
from app.api.health import router as health_router
from app.database.indexes import ensure_indexes
from app.utils.error_handlers import register_exception_handlers
from app.services.notifications import notification_service
from app.services.background_qr_service import schedule_qr_generation_task
from app.services.background_rewards_service import BackgroundRewardsService
from app.services.background_order_expiry_service import schedule_order_expiry_task
from utils.utils import DatabaseManager, start_cache_invalidation_watcher

# Initialize logging
settings = get_settings()
AppLogger.initialize(log_level=settings.log_level.upper(), app_env=settings.app_env)
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events."""
    # Startup
    try:
        logger.info("Starting application initialization...")

        # Initialize database connection pool with a test query
        client = DatabaseManager.get_mongo_client()
        client.admin.command("ping")
        logger.info("✅ MongoDB connection pool initialized")

        # Ensure database indexes exist
        try:
            index_results = ensure_indexes()
            total_indexes = sum(len(v) for v in index_results.values())
            logger.info(f"✅ Database indexes verified ({total_indexes} indexes across {len(index_results)} collections)")
        except Exception as e:
            logger.warning(f"⚠️ Index creation had issues (non-fatal): {e}")

        # Start the cache invalidation watcher
        start_cache_invalidation_watcher()
        logger.info("✅ Cache invalidation watcher started")

        # Start the workshop notification watcher
        notification_service.start_workshop_notification_watcher()
        logger.info("✅ Workshop notification watcher started")

        # Start the background QR code generation service
        qr_task = schedule_qr_generation_task()
        if qr_task:
            logger.info("✅ Background QR code generation service started")
        else:
            logger.warning("⚠️ Failed to start background QR code generation service")

        # Start the background rewards generation service
        try:
            rewards_service = BackgroundRewardsService()
            asyncio.create_task(rewards_service.start_rewards_generation_service())
            logger.info("✅ Background rewards generation service started")
        except Exception as e:
            logger.warning(f"⚠️ Failed to start background rewards service: {e}")

        # Start the background order expiry service
        expiry_task = schedule_order_expiry_task()
        if expiry_task:
            logger.info("✅ Background order expiry service started")
        else:
            logger.warning("⚠️ Failed to start background order expiry service")

        logger.info(f"🎉 Application startup complete (env={settings.app_env})")

    except Exception as e:
        logger.error(f"❌ Error during startup: {e}")
        raise

    yield

    # Shutdown
    try:
        DatabaseManager.close_connections()
        logger.info("Application shutdown: Database connections closed.")
    except Exception as e:
        logger.error(f"❌ Error during shutdown: {e}")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""

    app = FastAPI(
        title="Dance Workshop API",
        description="API for managing dance workshops, artists, and studios",
        version="2.0.0",
        lifespan=lifespan  # Use the new lifespan event handler
    )

    # Register custom exception handlers
    register_exception_handlers(app)

    # Mount static files and templates
    app.mount("/static", StaticFiles(directory="static"), name="static")

    # Add Request ID middleware (first, so it's available for all requests)
    app.add_middleware(RequestIdMiddleware)

    # Add GZip middleware for response compression
    app.add_middleware(GZipMiddleware, minimum_size=1000)

    # Security middleware with OpenAI MCP support
    # CORS origins are now properly configured in constants.py
    cors_origins = APIConfig.CORS_ORIGINS + [
        "https://api.openai.com",
        "https://chat.openai.com",
        "https://platform.openai.com",
    ]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*", "X-Request-ID"],
        expose_headers=["X-Request-ID"],
    )

    # Add response time logging middleware
    app.middleware("http")(log_response_time_middleware)

    # Include health check router (no prefix for standard paths)
    app.include_router(health_router, tags=["Health"])

    # Include API routers
    app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
    app.include_router(workshops_router, prefix="/api", tags=["Workshops"])
    app.include_router(reactions_router, prefix="/api", tags=["Reactions"])
    app.include_router(notifications_router, prefix="/api", tags=["Notifications"])
    app.include_router(search_router, prefix="/api", tags=["Search"])
    app.include_router(orders_router, prefix="/api/orders", tags=["Orders & Payments"])
    app.include_router(rewards_router, prefix="/api/rewards", tags=["Rewards System"])
    app.include_router(razorpay_router, prefix="/api/razorpay", tags=["Razorpay Webhooks"])
    app.include_router(version_router, prefix="/api/version", tags=["Version Management"])
    app.include_router(mcp_router, prefix="/mcp", tags=["MCP (Model Context Protocol)"])
    app.include_router(admin_router, prefix="/admin/api", tags=["Admin"])
    app.include_router(reels_router, prefix="/api/reels", tags=["Reels"])
    app.include_router(web_router, tags=["Web"])

    return app


app = create_app()


if __name__ == "__main__":
    # Production configuration with optimizations
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        workers=settings.workers,
        loop="uvloop",  # Use uvloop for better performance
        http="httptools",  # Use httptools for better performance
        reload=settings.reload,
        access_log=False,  # Disable default access logs to prevent duplication with our custom middleware
        log_level=settings.log_level,
        proxy_headers=True,  # Trust proxy headers from NGINX
        forwarded_allow_ips="127.0.0.1",  # Only trust localhost proxy
        # Optimize worker settings
        limit_concurrency=1000,  # Max concurrent connections
        limit_max_requests=10000,  # Restart workers after this many requests to prevent memory leaks
        timeout_keep_alive=5,  # Keep-alive timeout
    ) 