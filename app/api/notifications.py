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


 