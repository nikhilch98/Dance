"""Custom exception classes for the application."""

from typing import Optional, Dict, Any


class AppException(Exception):
    """Base exception for application errors."""

    def __init__(
        self,
        message: str,
        code: str = "APP_ERROR",
        status_code: int = 500,
        details: Optional[Dict[str, Any]] = None
    ):
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details or {}
        super().__init__(self.message)

    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to dictionary for JSON response."""
        return {
            "error": {
                "code": self.code,
                "message": self.message,
                "details": self.details
            }
        }


class ValidationError(AppException):
    """Exception for input validation errors."""

    def __init__(
        self,
        message: str = "Validation failed",
        field: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        error_details = details or {}
        if field:
            error_details["field"] = field
        super().__init__(
            message=message,
            code="VALIDATION_ERROR",
            status_code=400,
            details=error_details
        )


class NotFoundError(AppException):
    """Exception for resource not found errors."""

    def __init__(
        self,
        resource: str = "Resource",
        resource_id: Optional[str] = None,
        message: Optional[str] = None
    ):
        details = {}
        if resource_id:
            details["resource_id"] = resource_id
        super().__init__(
            message=message or f"{resource} not found",
            code="NOT_FOUND",
            status_code=404,
            details=details
        )


class AuthenticationError(AppException):
    """Exception for authentication failures."""

    def __init__(
        self,
        message: str = "Authentication failed",
        details: Optional[Dict[str, Any]] = None
    ):
        super().__init__(
            message=message,
            code="AUTHENTICATION_ERROR",
            status_code=401,
            details=details
        )


class AuthorizationError(AppException):
    """Exception for authorization failures."""

    def __init__(
        self,
        message: str = "Access denied",
        required_permission: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        error_details = details or {}
        if required_permission:
            error_details["required_permission"] = required_permission
        super().__init__(
            message=message,
            code="AUTHORIZATION_ERROR",
            status_code=403,
            details=error_details
        )


class DatabaseError(AppException):
    """Exception for database operation failures."""

    def __init__(
        self,
        message: str = "Database operation failed",
        operation: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        error_details = details or {}
        if operation:
            error_details["operation"] = operation
        super().__init__(
            message=message,
            code="DATABASE_ERROR",
            status_code=500,
            details=error_details
        )


class RateLimitError(AppException):
    """Exception for rate limit exceeded."""

    def __init__(
        self,
        message: str = "Rate limit exceeded",
        retry_after: Optional[int] = None,
        details: Optional[Dict[str, Any]] = None
    ):
        error_details = details or {}
        if retry_after:
            error_details["retry_after"] = retry_after
        super().__init__(
            message=message,
            code="RATE_LIMIT_EXCEEDED",
            status_code=429,
            details=error_details
        )


class ExternalServiceError(AppException):
    """Exception for external service failures."""

    def __init__(
        self,
        service: str,
        message: str = "External service error",
        details: Optional[Dict[str, Any]] = None
    ):
        error_details = details or {}
        error_details["service"] = service
        super().__init__(
            message=message,
            code="EXTERNAL_SERVICE_ERROR",
            status_code=502,
            details=error_details
        )
