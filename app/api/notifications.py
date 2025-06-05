"""Notification API routes."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.database.notifications import PushNotificationOperations
from app.models.auth import DeviceTokenRequest
from app.services.auth import verify_token

router = APIRouter()


@router.post("/notifications/register-token")
async def register_device_token(
    token_data: DeviceTokenRequest,
    user_id: str = Depends(verify_token)
):
    """Register device token for push notifications."""
    success = PushNotificationOperations.register_device_token(
        user_id=user_id,
        device_token=token_data.device_token,
        platform=token_data.platform
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to register device token"
        )
    
    return {"message": "Device token registered successfully"}


@router.get("/config")
async def get_config(user_id: str = Depends(verify_token)):
    """Get app configuration for authenticated user."""
    from app.database.users import UserOperations
    
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    device_token = PushNotificationOperations.get_device_token_given_user_id(user_id)
    return {
        "is_admin": user.get("is_admin", False),
        "device_token": device_token    
    } 