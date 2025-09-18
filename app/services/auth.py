"""Authentication services."""

from datetime import datetime, timedelta
from typing import Optional
import jwt
from fastapi import HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from functools import wraps

from app.config.settings import get_settings
from app.database.notifications import PushNotificationOperations
from app.database.users import UserOperations
from app.models.auth import UserProfile

settings = get_settings()
security = HTTPBearer()


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.access_token_expire_minutes)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    return encoded_jwt


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token and return user info."""
    try:
        payload = jwt.decode(credentials.credentials, settings.secret_key, algorithms=[settings.algorithm])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user_id
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


def verify_admin_user(user_id: str = Depends(verify_token)):
    """Dependency function to verify admin user."""
    user = UserOperations.get_user_by_id(user_id)
    if not user or not user.get('is_admin', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return user_id


def format_user_profile(user_data: dict) -> UserProfile:
    """Format user data to UserProfile model."""
    user_id = str(user_data["_id"])
    return UserProfile(
        user_id=user_id,
        mobile_number=user_data["mobile_number"],
        name=user_data.get("name"),
        date_of_birth=user_data.get("date_of_birth"),
        gender=user_data.get("gender"),
        profile_picture_url=user_data.get("profile_picture_url"),
        profile_picture_id=user_data.get("profile_picture_id"),
        # profile_complete=user_data.get("profile_complete", False),
        profile_complete=all([
            user_data.get("name"),
            user_data.get("date_of_birth"),
            user_data.get("gender")
        ]),
        is_admin=user_data.get("is_admin", False),
        admin_studios_list=user_data.get("admin_studios_list", []),
        admin_access_list=user_data.get("admin_access_list", []),
        created_at=user_data["created_at"],
        updated_at=user_data["updated_at"],
        device_token=PushNotificationOperations.get_device_token_given_user_id(user_id)
    )


class AuthService:
    """Authentication service for handling user authentication and authorization."""
    
    @staticmethod
    def user_authentication(func):
        """Decorator to require user authentication for API endpoints."""
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract user_id from kwargs if it exists (injected by Depends(verify_token))
            user_id = kwargs.get('user_id')
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required"
                )
            return await func(*args, **kwargs)
        return wrapper

    @staticmethod
    def admin_authentication(func):
        """Decorator to require admin authentication for API endpoints. Must be used with @user_authentication."""
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract user_id from kwargs (should be injected by @user_authentication + Depends(verify_token))
            user_id = kwargs.get('user_id')
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authentication required"
                )
            
            # Check if user is admin
            user = UserOperations.get_user_by_id(user_id)
            if not user or not user.get('is_admin', False):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Admin access required"
                )
            
            return await func(*args, **kwargs)
        return wrapper 