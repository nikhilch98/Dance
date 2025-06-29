"""Main FastAPI application for the Nachna Dance Workshop API."""

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from app.config.constants import APIConfig
from app.config.settings import get_settings
from app.middleware.logging import log_response_time_middleware
from app.api import (
    auth_router,
    workshops_router,
    reactions_router,
    notifications_router,
    admin_router,
    web_router,
    search_router,
    mcp_router,
)
from app.services.notifications import notification_service
from utils.utils import DatabaseManager, start_cache_invalidation_watcher

settings = get_settings()


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    
    app = FastAPI(
        title="Dance Workshop API",
        description="API for managing dance workshops, artists, and studios",
        version="2.0.0",
    )

    # Mount static files and templates
    app.mount("/static", StaticFiles(directory="static"), name="static")
    
    # Add GZip middleware for response compression
    app.add_middleware(GZipMiddleware, minimum_size=1000)

    # Security middleware with OpenAI MCP support
    app.add_middleware(
        CORSMiddleware,
        allow_origins=APIConfig.CORS_ORIGINS + [
            "https://api.openai.com",
            "https://chat.openai.com", 
            "https://platform.openai.com",
            "https://*.openai.com"
        ],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    # Add response time logging middleware
    app.middleware("http")(log_response_time_middleware)

    # Include API routers
    app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
    app.include_router(workshops_router, prefix="/api", tags=["Workshops"])
    app.include_router(reactions_router, prefix="/api", tags=["Reactions"])
    app.include_router(notifications_router, prefix="/api", tags=["Notifications"])
    app.include_router(search_router, prefix="/api", tags=["Search"])
    app.include_router(mcp_router, prefix="/mcp", tags=["MCP (Model Context Protocol)"])
    app.include_router(admin_router, prefix="/admin", tags=["Admin"])
    app.include_router(web_router, tags=["Web"])

    return app


app = create_app()


@app.on_event("startup")
async def startup_event():
    """Initialize database connection pool and start services on startup."""
    # Initialize database connection pool with a test query
    client = DatabaseManager.get_mongo_client()
    client.admin.command("ping")
    print("MongoDB connection pool initialized")

    # Start the cache invalidation watcher
    start_cache_invalidation_watcher()
    print("Cache invalidation watcher started")

    # Start the workshop notification watcher
    notification_service.start_workshop_notification_watcher()
    print("Workshop notification watcher started")


@app.on_event("shutdown")
async def shutdown_event():
    """Close database connections when the application shuts down."""
    DatabaseManager.close_connections()
    print("Application shutdown: Database connections closed.")


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