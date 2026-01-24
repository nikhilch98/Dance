"""Request ID middleware for request tracking and distributed tracing."""

import uuid
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import logging

logger = logging.getLogger(__name__)

REQUEST_ID_HEADER = "X-Request-ID"


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Middleware to add request ID to all requests for tracking."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Process request and add request ID."""
        # Get existing request ID or generate new one
        request_id = request.headers.get(REQUEST_ID_HEADER)
        if not request_id:
            request_id = str(uuid.uuid4())

        # Store in request state for access in handlers
        request.state.request_id = request_id

        # Process the request
        response = await call_next(request)

        # Add request ID to response headers
        response.headers[REQUEST_ID_HEADER] = request_id

        return response


def get_request_id(request: Request) -> str:
    """Get the request ID from request state."""
    return getattr(request.state, "request_id", "unknown")
