"""Input validation utilities."""

import re
from typing import Optional
from bson import ObjectId
from bson.errors import InvalidId

from app.utils.exceptions import ValidationError


def validate_object_id(value: str, field_name: str = "id") -> ObjectId:
    """
    Validate and convert a string to MongoDB ObjectId.

    Args:
        value: String value to validate
        field_name: Name of the field for error messages

    Returns:
        Valid ObjectId

    Raises:
        ValidationError: If the value is not a valid ObjectId
    """
    if not value:
        raise ValidationError(
            message=f"Invalid {field_name}: value cannot be empty",
            field=field_name
        )

    try:
        return ObjectId(value)
    except (InvalidId, TypeError) as e:
        raise ValidationError(
            message=f"Invalid {field_name}: not a valid ObjectId format",
            field=field_name,
            details={"value": value[:20] + "..." if len(value) > 20 else value}
        )


def is_valid_object_id(value: str) -> bool:
    """
    Check if a string is a valid MongoDB ObjectId without raising exception.

    Args:
        value: String value to check

    Returns:
        True if valid, False otherwise
    """
    if not value or not isinstance(value, str):
        return False
    try:
        ObjectId(value)
        return True
    except (InvalidId, TypeError):
        return False


def validate_mobile_number(mobile: str, field_name: str = "mobile_number") -> str:
    """
    Validate Indian mobile number format.

    Args:
        mobile: Mobile number to validate
        field_name: Name of the field for error messages

    Returns:
        Cleaned mobile number

    Raises:
        ValidationError: If the mobile number is invalid
    """
    if not mobile:
        raise ValidationError(
            message=f"Invalid {field_name}: value cannot be empty",
            field=field_name
        )

    # Clean the number
    cleaned = mobile.strip().replace(" ", "").replace("-", "")

    # Remove country code if present
    if cleaned.startswith("+91"):
        cleaned = cleaned[3:]
    elif cleaned.startswith("91") and len(cleaned) == 12:
        cleaned = cleaned[2:]

    # Validate format
    if not cleaned.isdigit():
        raise ValidationError(
            message=f"Invalid {field_name}: must contain only digits",
            field=field_name
        )

    if len(cleaned) != 10:
        raise ValidationError(
            message=f"Invalid {field_name}: must be 10 digits",
            field=field_name
        )

    # Check for valid Indian mobile number prefix (6-9)
    if cleaned[0] not in "6789":
        raise ValidationError(
            message=f"Invalid {field_name}: must start with 6, 7, 8, or 9",
            field=field_name
        )

    return cleaned


def sanitize_string(
    value: Optional[str],
    max_length: int = 1000,
    allow_html: bool = False
) -> Optional[str]:
    """
    Sanitize a string input.

    Args:
        value: String to sanitize
        max_length: Maximum allowed length
        allow_html: Whether to allow HTML tags

    Returns:
        Sanitized string or None
    """
    if value is None:
        return None

    if not isinstance(value, str):
        value = str(value)

    # Strip whitespace
    value = value.strip()

    # Truncate if too long
    if len(value) > max_length:
        value = value[:max_length]

    # Remove HTML tags if not allowed
    if not allow_html:
        value = re.sub(r'<[^>]+>', '', value)

    # Remove null bytes and other control characters
    value = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', value)

    return value if value else None


def validate_url(url: str, allowed_schemes: list = None) -> str:
    """
    Validate URL format.

    Args:
        url: URL to validate
        allowed_schemes: List of allowed URL schemes (default: http, https)

    Returns:
        Validated URL

    Raises:
        ValidationError: If URL is invalid
    """
    if not url:
        raise ValidationError(message="URL cannot be empty", field="url")

    allowed = allowed_schemes or ["http", "https"]
    url_pattern = re.compile(
        r'^(?:' + '|'.join(allowed) + r')://'
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'
        r'localhost|'
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
        r'(?::\d+)?'
        r'(?:/?|[/?]\S+)$', re.IGNORECASE
    )

    if not url_pattern.match(url):
        raise ValidationError(
            message="Invalid URL format",
            field="url",
            details={"allowed_schemes": allowed}
        )

    return url
