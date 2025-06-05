"""Authentication API routes."""

import io
import secrets
from datetime import datetime, timedelta
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import Response
from PIL import Image, UnidentifiedImageError

from app.database.users import UserOperations
from app.models.auth import (
    AuthResponse,
    DeviceTokenRequest,
    PasswordUpdate,
    ProfileUpdate,
    UserLogin,
    UserProfile,
    UserRegistration,
)
from app.services.auth import (
    create_access_token,
    format_user_profile,
    verify_admin_user,
    verify_token,
)
from utils.utils import get_mongo_client

router = APIRouter()


@router.post("/register", response_model=AuthResponse)
async def register_user(user_data: UserRegistration):
    """Register a new user."""
    try:
        # Create user
        new_user = UserOperations.create_user(
            mobile_number=user_data.mobile_number,
            password=user_data.password
        )
        
        # Create access token
        access_token_expires = timedelta(minutes=30 * 24 * 60)  # 30 days
        access_token = create_access_token(
            data={"sub": str(new_user["_id"])},
            expires_delta=access_token_expires
        )
        
        # Format user profile
        user_profile = format_user_profile(new_user)
        
        return AuthResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_profile
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Registration error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )


@router.post("/login", response_model=AuthResponse)
async def login_user(user_data: UserLogin):
    """Login user."""
    # Authenticate user
    user = UserOperations.authenticate_user(
        mobile_number=user_data.mobile_number,
        password=user_data.password
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password"
        )
    
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


@router.put("/password")
async def update_user_password(
    password_data: PasswordUpdate,
    user_id: str = Depends(verify_token)
):
    """Update user password."""
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Verify current password
    from app.database.users import verify_password
    if not verify_password(password_data.current_password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Update password
    success = UserOperations.update_user_password(user_id, password_data.new_password)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password update failed"
        )
    
    return {"message": "Password updated successfully"}


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