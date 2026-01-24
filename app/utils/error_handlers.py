"""Global exception handlers for FastAPI."""

from typing import Dict, Any, Optional
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
import logging

from app.utils.exceptions import AppException

logger = logging.getLogger(__name__)


def create_error_response(
    code: str,
    message: str,
    details: Optional[Dict[str, Any]] = None,
    status_code: int = 500
) -> JSONResponse:
    """Create a standardized error response."""
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "error": {
                "code": code,
                "message": message,
                "details": details or {}
            }
        }
    )


def create_success_response(
    data: Any,
    message: Optional[str] = None
) -> Dict[str, Any]:
    """Create a standardized success response."""
    response = {
        "success": True,
        "data": data
    }
    if message:
        response["message"] = message
    return response


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """Handle custom application exceptions."""
    logger.error(
        f"AppException: {exc.code} - {exc.message}",
        extra={
            "path": request.url.path,
            "method": request.method,
            "code": exc.code,
            "details": exc.details
        }
    )
    return create_error_response(
        code=exc.code,
        message=exc.message,
        details=exc.details,
        status_code=exc.status_code
    )


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Handle HTTP exceptions."""
    logger.warning(
        f"HTTPException: {exc.status_code} - {exc.detail}",
        extra={
            "path": request.url.path,
            "method": request.method
        }
    )

    # Map status codes to error codes
    code_map = {
        400: "BAD_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        405: "METHOD_NOT_ALLOWED",
        422: "UNPROCESSABLE_ENTITY",
        429: "TOO_MANY_REQUESTS",
        500: "INTERNAL_ERROR",
        502: "BAD_GATEWAY",
        503: "SERVICE_UNAVAILABLE",
    }

    return create_error_response(
        code=code_map.get(exc.status_code, "HTTP_ERROR"),
        message=str(exc.detail) if exc.detail else "An error occurred",
        status_code=exc.status_code
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Handle request validation errors."""
    errors = []
    for error in exc.errors():
        field = ".".join(str(loc) for loc in error["loc"])
        errors.append({
            "field": field,
            "message": error["msg"],
            "type": error["type"]
        })

    logger.warning(
        f"ValidationError: {len(errors)} validation errors",
        extra={
            "path": request.url.path,
            "method": request.method,
            "errors": errors
        }
    )

    return create_error_response(
        code="VALIDATION_ERROR",
        message="Request validation failed",
        details={"errors": errors},
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle unexpected exceptions."""
    logger.exception(
        f"Unhandled exception: {type(exc).__name__} - {str(exc)}",
        extra={
            "path": request.url.path,
            "method": request.method
        }
    )

    return create_error_response(
        code="INTERNAL_ERROR",
        message="An unexpected error occurred",
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
    )


def register_exception_handlers(app: FastAPI) -> None:
    """Register all exception handlers with the FastAPI app."""
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    # Only catch truly unexpected exceptions - let specific ones bubble up
    # app.add_exception_handler(Exception, generic_exception_handler)
