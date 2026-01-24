"""Rate limiting service with MongoDB backend for distributed rate limiting."""

import time
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from functools import wraps

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse

from app.config.logging_config import get_logger
from app.config.settings import get_settings
from app.config.constants import RateLimitConfig
from utils.utils import get_mongo_client

logger = get_logger(__name__)
settings = get_settings()


class RateLimitService:
    """
    Service for handling API rate limiting.

    Uses MongoDB for distributed rate limiting that works across multiple workers.
    Falls back to in-memory rate limiting if MongoDB is unavailable.
    """

    COLLECTION_NAME = "rate_limits"
    DATABASE_NAME = "dance_app"

    def __init__(self):
        # In-memory fallback for when MongoDB is unavailable
        self._memory_store: Dict[str, List[float]] = defaultdict(list)
        self._use_mongodb = True

    def _get_collection(self):
        """Get the rate limits collection."""
        try:
            client = get_mongo_client()
            return client[self.DATABASE_NAME][self.COLLECTION_NAME]
        except Exception as e:
            logger.warning(f"MongoDB unavailable for rate limiting, using in-memory: {e}")
            self._use_mongodb = False
            return None

    def check_rate_limit(
        self,
        key: str,
        max_requests: int = None,
        window_seconds: int = None
    ) -> Tuple[bool, int, int]:
        """
        Check if rate limit is exceeded.

        Args:
            key: Unique identifier for rate limiting (e.g., "user_id:endpoint" or "ip:endpoint")
            max_requests: Maximum allowed requests in window (default from settings)
            window_seconds: Time window in seconds (default from settings)

        Returns:
            Tuple of (allowed: bool, remaining: int, reset_time: int)
        """
        max_requests = max_requests or RateLimitConfig.MAX_REQUESTS_PER_WINDOW
        window_seconds = window_seconds or RateLimitConfig.WINDOW_SECONDS
        current_time = time.time()

        if self._use_mongodb:
            try:
                return self._check_mongodb_rate_limit(key, max_requests, window_seconds, current_time)
            except Exception as e:
                logger.warning(f"MongoDB rate limit check failed, using in-memory: {e}")
                self._use_mongodb = False

        return self._check_memory_rate_limit(key, max_requests, window_seconds, current_time)

    def _check_mongodb_rate_limit(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
        current_time: float
    ) -> Tuple[bool, int, int]:
        """Check rate limit using MongoDB."""
        collection = self._get_collection()
        if not collection:
            return self._check_memory_rate_limit(key, max_requests, window_seconds, current_time)

        window_start = current_time - window_seconds
        reset_time = int(current_time + window_seconds)

        # Find or create rate limit document
        doc = collection.find_one({"key": key})

        if doc:
            # Filter timestamps within current window
            timestamps = [ts for ts in doc.get("timestamps", []) if ts > window_start]
            request_count = len(timestamps)

            if request_count >= max_requests:
                # Rate limit exceeded
                remaining = 0
                return False, remaining, reset_time

            # Add current request
            timestamps.append(current_time)
            collection.update_one(
                {"key": key},
                {
                    "$set": {
                        "timestamps": timestamps,
                        "expires_at": datetime.utcnow() + timedelta(seconds=window_seconds * 2)
                    }
                }
            )
            remaining = max_requests - len(timestamps)
        else:
            # First request for this key
            collection.insert_one({
                "key": key,
                "timestamps": [current_time],
                "expires_at": datetime.utcnow() + timedelta(seconds=window_seconds * 2)
            })
            remaining = max_requests - 1

        return True, remaining, reset_time

    def _check_memory_rate_limit(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
        current_time: float
    ) -> Tuple[bool, int, int]:
        """Check rate limit using in-memory store (fallback)."""
        window_start = current_time - window_seconds
        reset_time = int(current_time + window_seconds)

        # Clean up old entries
        self._memory_store[key] = [
            ts for ts in self._memory_store[key] if ts > window_start
        ]

        request_count = len(self._memory_store[key])

        if request_count >= max_requests:
            return False, 0, reset_time

        # Add current request
        self._memory_store[key].append(current_time)
        remaining = max_requests - len(self._memory_store[key])

        return True, remaining, reset_time

    def check_otp_rate_limit(
        self,
        mobile_number: str,
        ip_address: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Check OTP-specific rate limits.

        Args:
            mobile_number: Mobile number requesting OTP
            ip_address: Client IP address

        Returns:
            Tuple of (allowed: bool, error_message: str)
        """
        # Check per-mobile rate limit
        mobile_key = f"otp:mobile:{mobile_number}"
        allowed, remaining, reset = self.check_rate_limit(
            mobile_key,
            max_requests=RateLimitConfig.OTP_SEND_MAX_PER_MOBILE,
            window_seconds=RateLimitConfig.WINDOW_SECONDS
        )

        if not allowed:
            return False, f"Too many OTP requests for this number. Please wait before trying again."

        # Check per-IP rate limit if IP is provided
        if ip_address:
            ip_key = f"otp:ip:{ip_address}"
            allowed, remaining, reset = self.check_rate_limit(
                ip_key,
                max_requests=RateLimitConfig.OTP_SEND_MAX_PER_IP,
                window_seconds=RateLimitConfig.WINDOW_SECONDS
            )

            if not allowed:
                return False, "Too many OTP requests from your location. Please wait before trying again."

        return True, ""

    def check_otp_verification_attempts(self, mobile_number: str) -> Tuple[bool, int]:
        """
        Check OTP verification attempts to prevent brute force.

        Args:
            mobile_number: Mobile number being verified

        Returns:
            Tuple of (allowed: bool, attempts_remaining: int)
        """
        key = f"otp_verify:{mobile_number}"
        allowed, remaining, _ = self.check_rate_limit(
            key,
            max_requests=RateLimitConfig.OTP_VERIFY_MAX_ATTEMPTS,
            window_seconds=RateLimitConfig.OTP_LOCKOUT_MINUTES * 60
        )

        return allowed, remaining

    def reset_otp_attempts(self, mobile_number: str) -> None:
        """Reset OTP verification attempts after successful verification."""
        key = f"otp_verify:{mobile_number}"

        try:
            if self._use_mongodb:
                collection = self._get_collection()
                if collection:
                    collection.delete_one({"key": key})
        except Exception as e:
            logger.warning(f"Failed to reset OTP attempts: {e}")

        # Also clear from memory store
        if key in self._memory_store:
            del self._memory_store[key]


# Global rate limiter instance
rate_limiter = RateLimitService()


def check_rate_limit(user_id: str, endpoint: str) -> bool:
    """Check if user has exceeded rate limit for an endpoint."""
    key = f"{user_id}:{endpoint}"
    allowed, _, _ = rate_limiter.check_rate_limit(key)
    return allowed


def rate_limit_dependency(
    max_requests: int = None,
    window_seconds: int = None,
    key_func=None
):
    """
    FastAPI dependency for rate limiting endpoints.

    Args:
        max_requests: Maximum requests allowed in window
        window_seconds: Time window in seconds
        key_func: Function to generate rate limit key from request (default: client IP)

    Usage:
        @router.post("/endpoint")
        async def endpoint(
            request: Request,
            _: None = Depends(rate_limit_dependency(max_requests=5, window_seconds=60))
        ):
            ...
    """
    async def dependency(request: Request):
        # Generate key
        if key_func:
            key = key_func(request)
        else:
            # Default to client IP
            key = f"ip:{request.client.host if request.client else 'unknown'}"

        allowed, remaining, reset_time = rate_limiter.check_rate_limit(
            key,
            max_requests=max_requests,
            window_seconds=window_seconds
        )

        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later.",
                headers={
                    "X-RateLimit-Limit": str(max_requests or RateLimitConfig.MAX_REQUESTS_PER_WINDOW),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(reset_time),
                    "Retry-After": str(window_seconds or RateLimitConfig.WINDOW_SECONDS)
                }
            )

        # Could add headers to response here if needed
        return None

    return dependency
