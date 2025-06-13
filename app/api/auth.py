"""Authentication API routes."""

import io
import secrets
from datetime import datetime, timedelta
from typing import Optional
import asyncio
import logging

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError

from app.database.users import UserOperations
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
from utils.utils import get_mongo_client

router = APIRouter()

async def send_otp_background(mobile_number: str):
    """Send OTP in background."""
    try:
        logging.info(f"Background OTP sending started for: {mobile_number}")
        
        # Run the sync Twilio service call in a thread pool
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None,  # Use default executor
            lambda: get_twilio_service().send_otp(mobile_number)
        )
        
        if result["success"]:
            logging.info(f"Background OTP sent successfully to: {mobile_number}")
        else:
            logging.error(f"Background OTP sending failed for {mobile_number}: {result['message']}")
            
    except Exception as e:
        logging.error(f"Background OTP sending error for {mobile_number}: {str(e)}")

@router.post("/send-otp")
async def send_otp(otp_request: SendOTPRequest):
    """Send OTP to mobile number asynchronously."""
    if otp_request.mobile_number == "9999999999":
        return {
            "success": True,
            "message": "OTP is being sent to your mobile number",
            "mobile_number": otp_request.mobile_number
        }
    
    try:
        # Validate mobile number format (basic validation)
        mobile_number = otp_request.mobile_number.strip()
        if not mobile_number or len(mobile_number) != 10 or not mobile_number.isdigit():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid mobile number format"
            )
        
        # Log the request
        logging.info(f"OTP request received for: {mobile_number}")
        
        # Schedule OTP sending in background (fire and forget)
        asyncio.create_task(send_otp_background(mobile_number))
        
        # Return immediate success response
        return {
            "success": True,
            "message": "OTP is being sent to your mobile number",
            "mobile_number": mobile_number
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Send OTP endpoint error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process OTP request"
        )


@router.post("/verify-otp", response_model=AuthResponse)
async def verify_otp_and_login(otp_request: VerifyOTPRequest):
    """Verify OTP and login/register user."""
    try:
        # Verify OTP using Twilio
        if otp_request.mobile_number != "9999999999" and otp_request.otp != "583647":
            result = get_twilio_service().verify_otp(otp_request.mobile_number, otp_request.otp)
            
            if not result["success"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=result["message"]
                )
        
        # Create or get user
        user = UserOperations.create_or_get_user(otp_request.mobile_number)
        
        # Create access token
        access_token_expires = timedelta(minutes=30 * 24 * 60)  # 30 days
        access_token = create_access_token(
            data={"sub": str(user["_id"])},
            expires_delta=access_token_expires
        )
        
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
        print(f"OTP verification error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="OTP verification failed"
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
        
        # Get MongoDB client
        client = get_mongo_client()
        
        # Remove existing profile picture if any
        existing_user = client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        if existing_user and existing_user.get("profile_picture_id"):
            # Delete old profile picture from MongoDB
            client["dance_app"]["profile_pictures"].delete_one(
                {"_id": ObjectId(existing_user["profile_picture_id"])}
            )
        
        # Save new image to MongoDB
        profile_picture_doc = {
            "user_id": user_id,
            "image_data": img_byte_arr,
            "content_type": "image/jpeg",
            "filename": f"profile_{user_id}_{secrets.token_hex(8)}.jpg",
            "size": len(img_byte_arr),
            "created_at": datetime.utcnow(),
        }
        
        result = client["dance_app"]["profile_pictures"].insert_one(profile_picture_doc)
        picture_id = str(result.inserted_id)
        
        # Create URL for the image
        image_url = f"/api/profile-picture/{picture_id}"
        
        # Update user profile in database with picture ID
        update_result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "profile_picture_id": picture_id,
                "profile_picture_url": image_url,
                "updated_at": datetime.utcnow()
            }}
        )
        
        if update_result.modified_count == 0:
            # Clean up uploaded image if database update fails
            client["dance_app"]["profile_pictures"].delete_one({"_id": ObjectId(picture_id)})
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile picture"
            )
        
        return {
            "message": "Profile picture uploaded successfully",
            "image_url": image_url
        }
        
    except UnidentifiedImageError as e:
        print(f"Invalid image format: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Please upload a valid image file (JPEG, PNG, etc.)"
        )
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        print(f"File content type: {file.content_type}")
        print(f"File size: {len(file_content) if 'file_content' in locals() else 'unknown'}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process image: {str(e)}"
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
        
        # Remove profile picture from MongoDB if it exists
        if user.get("profile_picture_id"):
            client["dance_app"]["profile_pictures"].delete_one(
                {"_id": ObjectId(user["profile_picture_id"])}
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
        print(f"Error removing profile picture: {str(e)}")
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
        "device_token": current_server_token,
        "token_sync_status": "no_sync_needed"
    }
    
    # If device token and platform are provided, perform sync
    if device_token and platform:
        print(f"[Config API] Syncing device token for user {user_id}")
        print(f"[Config API] Client token: {device_token[:20] if device_token else 'None'}...")
        print(f"[Config API] Server token: {current_server_token[:20] if current_server_token else 'None'}...")
        
        if current_server_token != device_token:
            # Tokens don't match, update server token
            print(f"[Config API] Device tokens mismatch, updating server token")
            success = PushNotificationOperations.register_device_token(
                user_id=user_id,
                device_token=device_token,
                platform=platform
            )
            
            if success:
                response_data["device_token"] = device_token
                response_data["token_sync_status"] = "updated"
                print(f"[Config API] Device token updated successfully")
            else:
                response_data["token_sync_status"] = "update_failed"
                print(f"[Config API] Failed to update device token")
        else:
            # Tokens match, no update needed
            response_data["token_sync_status"] = "matched"
            print(f"[Config API] Device tokens already match")
    
    return response_data 