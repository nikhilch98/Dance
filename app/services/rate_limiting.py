"""Rate limiting service."""

import time
from collections import defaultdict
from typing import Dict, List

from app.config.settings import get_settings

settings = get_settings()


class RateLimitService:
    """Service for handling API rate limiting."""
    
    def __init__(self):
        # Simple in-memory rate limiter
        self.rate_limit_store: Dict[str, List[float]] = defaultdict(list)
    
    def check_rate_limit(self, user_id: str, endpoint: str) -> bool:
        """Check if user has exceeded rate limit for an endpoint."""
        key = f"{user_id}:{endpoint}"
        current_time = time.time()
        
        # Clean up old entries
        self.rate_limit_store[key] = [
            timestamp for timestamp in self.rate_limit_store[key]
            if current_time - timestamp < settings.rate_limit_window
        ]
        
        # Check if limit exceeded
        if len(self.rate_limit_store[key]) >= settings.rate_limit_max_requests:
            return False
        
        # Add current request
        self.rate_limit_store[key].append(current_time)
        return True


# Global rate limiter instance
rate_limiter = RateLimitService()


def check_rate_limit(user_id: str, endpoint: str) -> bool:
    """Check if user has exceeded rate limit for an endpoint."""
    return rate_limiter.check_rate_limit(user_id, endpoint) 