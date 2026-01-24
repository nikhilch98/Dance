"""Authentication API routes."""

import io
import secrets
from datetime import datetime, timedelta
from typing import Optional
import asyncio

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError

from app.config.logging_config import get_logger, mask_mobile, mask_token
from app.config.settings import get_settings
from app.database.users import UserOperations
from app.database.images import ImageDatabase
from app.models.auth import (
    AuthResponse,
    DeviceTokenRequest,
    ProfileUpdate,
    SendOTPRequest,
    UserProfile,
    VerifyOTPRequest,
)
from app.services.auth import (
    create_access_token,
    format_user_profile,
    verify_admin_user,
    verify_token,
)
from app.services.twilio_service import get_twilio_service
from app.services.audit import AuditService, AuditAction
from app.services.rate_limiting import rate_limiter
from utils.utils import get_mongo_client

logger = get_logger(__name__)
settings = get_settings()

router = APIRouter()

async def send_otp_background(mobile_number: str, ip_address: Optional[str] = None):
    """Send OTP in background with error tracking."""
    masked_mobile = mask_mobile(mobile_number)
    try:
        logger.info(f"Background OTP sending started for: {masked_mobile}")

        # Run the sync Twilio service call in a thread pool
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None,  # Use default executor
            lambda: get_twilio_service().send_otp(mobile_number)
        )

        if result["success"]:
            logger.info(f"Background OTP sent successfully to: {masked_mobile}")
            # Log audit event
            AuditService.log_otp_sent(mobile_number, ip_address)
        else:
            logger.error(f"Background OTP sending failed for {masked_mobile}: {result['message']}")

    except Exception as e:
        logger.exception(f"Background OTP sending error for {masked_mobile}: {str(e)}")

@router.post("/send-otp")
async def send_otp(otp_request: SendOTPRequest, request: Request):
    """Send OTP to mobile number asynchronously."""
    # Get client IP for audit logging and rate limiting
    ip_address = request.client.host if request.client else None

    # Check rate limits before processing
    allowed, error_msg = rate_limiter.check_otp_rate_limit(
        otp_request.mobile_number,
        ip_address
    )
    if not allowed:
        logger.warning(f"OTP rate limit exceeded for {mask_mobile(otp_request.mobile_number)}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=error_msg
        )

    # Check if test user mode is enabled (controlled by environment variable)
    if settings.enable_test_user and otp_request.mobile_number == settings.test_mobile_number:
        logger.info(f"Test user OTP request - bypassing Twilio")
        return {
            "success": True,
            "message": "OTP is being sent to your mobile number",
            "mobile_number": otp_request.mobile_number
        }

    try:
        # Validate mobile number format
        mobile_number = otp_request.mobile_number.strip()
        if not mobile_number or len(mobile_number) != 10 or not mobile_number.isdigit():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid mobile number format. Must be 10 digits."
            )

        # Validate Indian mobile number prefix (6-9)
        if mobile_number[0] not in "6789":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid mobile number. Must start with 6, 7, 8, or 9."
            )

        # Log the request (masked)
        logger.info(f"OTP request received for: {mask_mobile(mobile_number)}")

        # Schedule OTP sending in background with error callback
        task = asyncio.create_task(send_otp_background(mobile_number, ip_address))

        # Add callback to log errors
        def handle_task_exception(t):
            if t.exception():
                logger.error(f"OTP background task failed: {t.exception()}")

        task.add_done_callback(handle_task_exception)

        # Return immediate success response
        return {
            "success": True,
            "message": "OTP is being sent to your mobile number",
            "mobile_number": mobile_number
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Send OTP endpoint error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process OTP request"
        )


@router.post("/verify-otp", response_model=AuthResponse)
async def verify_otp_and_login(otp_request: VerifyOTPRequest, request: Request):
    """Verify OTP and login/register user."""
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    is_test_user = False

    # Check verification attempt rate limit (prevent brute force)
    allowed, attempts_remaining = rate_limiter.check_otp_verification_attempts(
        otp_request.mobile_number
    )
    if not allowed:
        logger.warning(f"OTP verification locked out for {mask_mobile(otp_request.mobile_number)}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many verification attempts. Please wait 15 minutes before trying again."
        )

    try:
        # Check if test user mode is enabled
        if settings.enable_test_user and otp_request.mobile_number == settings.test_mobile_number:
            if otp_request.otp == settings.test_otp:
                logger.info("Test user login - bypassing OTP verification")
                is_test_user = True
            else:
                # Even for test user, require correct test OTP
                AuditService.log_login_attempt(
                    otp_request.mobile_number, ip_address, user_agent,
                    success=False, error_message="Invalid test OTP"
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid OTP"
                )
        else:
            # Verify OTP using Twilio for real users
            result = get_twilio_service().verify_otp(otp_request.mobile_number, otp_request.otp)

            if not result["success"]:
                AuditService.log_login_attempt(
                    otp_request.mobile_number, ip_address, user_agent,
                    success=False, error_message=result["message"]
                )
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=result["message"]
                )

        # Create or get user
        user = UserOperations.create_or_get_user(otp_request.mobile_number)
        user_id = str(user["_id"])

        # Create access token with configured expiration
        access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
        access_token = create_access_token(
            data={"sub": user_id},
            expires_delta=access_token_expires
        )

        # Reset OTP attempts on successful verification
        rate_limiter.reset_otp_attempts(otp_request.mobile_number)

        # Log successful login
        AuditService.log_login_attempt(
            otp_request.mobile_number, ip_address, user_agent, success=True
        )
        logger.info(f"User logged in: {user_id} (test_user={is_test_user})")

        # Format user profile
        user_profile = format_user_profile(user)

        return AuthResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_profile
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"OTP verification error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OTP verification failed. Please try again."
        )


@router.get("/profile", response_model=UserProfile)
async def get_user_profile(user_id: str = Depends(verify_token)):
    """Get current user profile."""
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return format_user_profile(user)


@router.put("/profile", response_model=UserProfile)
async def update_user_profile(
    profile_data: ProfileUpdate,
    user_id: str = Depends(verify_token)
):
    """Update user profile."""
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Prepare update data (only include non-None values)
    update_data = {}
    if profile_data.name is not None:
        update_data["name"] = profile_data.name
    if profile_data.date_of_birth is not None:
        update_data["date_of_birth"] = profile_data.date_of_birth
    if profile_data.gender is not None:
        update_data["gender"] = profile_data.gender
    
    # Update profile
    success = UserOperations.update_user_profile(user_id, update_data)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profile update failed"
        )
    
    # Return updated profile
    updated_user = UserOperations.get_user_by_id(user_id)
    return format_user_profile(updated_user)


@router.post("/profile-picture")
async def upload_profile_picture(
    file: UploadFile = File(...),
    user_id: str = Depends(verify_token)
):
    """Upload user profile picture to MongoDB."""
    # Validate file type - be more flexible with content type
    if file.content_type and not file.content_type.startswith('image/'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image"
        )
    
    # Validate file size (max 5MB)
    max_size = 5 * 1024 * 1024  # 5MB
    file_content = await file.read()
    if len(file_content) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size must be less than 5MB"
        )
    
    try:
        # Validate and process image - this will fail if it's not a valid image
        image = Image.open(io.BytesIO(file_content))
        
        # Verify it's actually an image by trying to load it
        image.verify()
        
        # Reopen the image since verify() closes it
        image = Image.open(io.BytesIO(file_content))
        
        # Convert to RGB if necessary
        if image.mode in ('RGBA', 'LA', 'P'):
            image = image.convert('RGB')
        
        # Resize image to max 800x800 while maintaining aspect ratio
        max_size = (800, 800)
        image.thumbnail(max_size, Image.Resampling.LANCZOS)
        
        # Convert processed image to bytes
        img_byte_arr = io.BytesIO()
        image.save(img_byte_arr, "JPEG", quality=85, optimize=True)
        img_byte_arr = img_byte_arr.getvalue()
        
        # Store image in centralized image collection
        image_id = ImageDatabase.store_image(
            data=img_byte_arr,
            image_type="user",
            entity_id=user_id,
            content_type="image/jpeg"
        )
        
        # Create URL for the new centralized image API
        image_url = f"/api/image/user/{user_id}"
        
        # Also store in old collection for backward compatibility during transition
        client = get_mongo_client()
        profile_picture_doc = {
            "user_id": user_id,
            "image_data": img_byte_arr,
            "content_type": "image/jpeg",
            "filename": f"profile_{user_id}_{secrets.token_hex(8)}.jpg",
            "size": len(img_byte_arr),
            "created_at": datetime.utcnow(),
        }
        
        client["dance_app"]["profile_pictures"].update_one(
            {"user_id": user_id},
            {"$set": profile_picture_doc},
            upsert=True
        )
        
        # Update user profile in database
        update_result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "profile_picture_id": image_id,
                "profile_picture_url": image_url,
                "updated_at": datetime.utcnow()
            }}
        )
        
        if update_result.modified_count == 0:
            # Clean up uploaded image if database update fails
            ImageDatabase.delete_image("user", user_id)
            client["dance_app"]["profile_pictures"].delete_one({"user_id": user_id})
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile picture"
            )
        
        return {
            "message": "Profile picture uploaded successfully",
            "image_url": image_url
        }
        
    except UnidentifiedImageError as e:
        logger.warning(f"Invalid image format uploaded: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Please upload a valid image file (JPEG, PNG, etc.)"
        )
    except Exception as e:
        logger.exception(
            f"Error processing image - content_type: {file.content_type}, "
            f"size: {len(file_content) if 'file_content' in locals() else 'unknown'}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process image. Please try again."
        )


@router.delete("/profile-picture")
async def remove_profile_picture(user_id: str = Depends(verify_token)):
    """Remove user profile picture from MongoDB."""
    try:
        client = get_mongo_client()
        
        # Get current user to find existing profile picture
        user = client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Remove profile picture from centralized image collection
        ImageDatabase.delete_image("user", user_id)
        
        # Also remove from old collection for backward compatibility
        if user.get("profile_picture_id"):
            client["dance_app"]["profile_pictures"].delete_one(
                {"user_id": user_id}
            )
        
        # Remove profile picture references from user document
        update_result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$unset": {
                "profile_picture_id": "",
                "profile_picture_url": ""
            },
             "$set": {"updated_at": datetime.utcnow()}}
        )
        
        if update_result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to remove profile picture"
            )
        
        return {"message": "Profile picture removed successfully"}
        
    except Exception as e:
        logger.exception(f"Error removing profile picture for user {user_id}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to remove profile picture"
        )


@router.delete("/account")
async def delete_account(user_id: str = Depends(verify_token)):
    """Delete user account."""
    success = UserOperations.delete_user_account(user_id)
    if not success:
        user_exists = UserOperations.get_user_by_id(user_id)
        if not user_exists:
            client = get_mongo_client()
            deleted_user = client["dance_app"]["users_deleted"].find_one({"_id": ObjectId(user_id)})
            if deleted_user:
                return {"message": "Account already deleted."}

            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found or account deletion failed."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Account deletion failed."
            )
            
    return {"message": "Account deleted successfully"}


@router.get("/config")
async def get_config_with_device_token_sync(
    device_token: Optional[str] = None,
    platform: Optional[str] = None,
    user_id: str = Depends(verify_token)
):
    """Get app configuration with device token synchronization."""
    from app.database.notifications import PushNotificationOperations
    
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get current device token from database
    current_server_token = PushNotificationOperations.get_device_token_given_user_id(user_id)
    
    # Initialize response data
    response_data = {
        "is_admin": user.get("is_admin", False),
        "admin_access_list": user.get("admin_access_list", []),
        "admin_studios_list": user.get("admin_studios_list", []),
        "admin_artist_access_denied_list": user.get("admin_artist_access_denied_list", []),
        "device_token": current_server_token,
        "token_sync_status": "no_sync_needed"
    }
    
    # If device token and platform are provided, perform sync
    if device_token and platform:
        logger.debug(f"Syncing device token for user {user_id}")
        logger.debug(f"Client token: {mask_token(device_token)}, Server token: {mask_token(current_server_token)}")

        if current_server_token != device_token:
            # Tokens don't match, update server token
            logger.info(f"Device tokens mismatch for user {user_id}, updating")
            success = PushNotificationOperations.register_device_token(
                user_id=user_id,
                device_token=device_token,
                platform=platform
            )

            if success:
                response_data["device_token"] = device_token
                response_data["token_sync_status"] = "updated"
                logger.info(f"Device token updated successfully for user {user_id}")
            else:
                response_data["token_sync_status"] = "update_failed"
                logger.warning(f"Failed to update device token for user {user_id}")
        else:
            # Tokens match, no update needed
            response_data["token_sync_status"] = "matched"
            logger.debug(f"Device tokens already match for user {user_id}")

    return response_data 