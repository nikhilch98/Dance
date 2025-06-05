"""Version validation middleware."""

from fastapi import HTTPException, Query

from app.config.constants import APIConfig


def validate_version(version: str = Query(APIConfig.DEFAULT_VERSION)) -> str:
    """Validate API version parameter.

    Args:
        version: API version string

    Returns:
        Validated version string

    Raises:
        HTTPException: If version is not supported
    """
    if version not in APIConfig.SUPPORTED_VERSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported API version. Supported versions: {APIConfig.SUPPORTED_VERSIONS}",
        )
    return version 