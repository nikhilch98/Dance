"""Health check endpoints for monitoring and load balancers."""

from datetime import datetime
from typing import Dict, Any
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
import logging

from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def health_check() -> Dict[str, Any]:
    """
    Basic health check endpoint for load balancers.

    Returns 200 if the server is running.
    This is a lightweight check that doesn't verify external dependencies.
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "nachna-api"
    }


@router.get("/ready", status_code=status.HTTP_200_OK)
async def readiness_check() -> JSONResponse:
    """
    Readiness check endpoint that verifies all dependencies.

    Returns 200 if the service is ready to handle requests.
    Returns 503 if any dependency is unavailable.
    """
    checks = {
        "mongodb": False,
    }

    # Check MongoDB connection
    try:
        client = get_mongo_client()
        client.admin.command("ping")
        checks["mongodb"] = True
    except Exception as e:
        logger.error(f"MongoDB health check failed: {e}")
        checks["mongodb"] = False

    # Determine overall status
    all_healthy = all(checks.values())

    response = {
        "status": "ready" if all_healthy else "not_ready",
        "timestamp": datetime.utcnow().isoformat(),
        "checks": checks
    }

    if all_healthy:
        return JSONResponse(content=response, status_code=status.HTTP_200_OK)
    else:
        return JSONResponse(content=response, status_code=status.HTTP_503_SERVICE_UNAVAILABLE)


@router.get("/info")
async def service_info() -> Dict[str, Any]:
    """
    Get service information.

    Returns basic information about the running service.
    """
    return {
        "service": "nachna-api",
        "version": "2.0.0",
        "environment": "production",
        "timestamp": datetime.utcnow().isoformat()
    }
