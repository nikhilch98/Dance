"""User database operations."""

from datetime import datetime
from typing import Optional
from bson import ObjectId
from fastapi import HTTPException, status
from passlib.context import CryptContext
import logging

from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)


class UserOperations:
    """Database operations for user management."""
    
    @staticmethod
    def create_user(mobile_number: str, password: str) -> dict:
        """Create a new user."""
        client = get_mongo_client()
        
        # Check if user already exists
        existing_user = client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this mobile number already exists"
            )
        
        # Create new user
        user_data = {
            "mobile_number": mobile_number,
            "password_hash": get_password_hash(password),
            "name": None,
            "date_of_birth": None,
            "gender": None,
            "profile_complete": False,
            "is_admin": False,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }
        
        result = client["dance_app"]["users"].insert_one(user_data)
        user_data["_id"] = result.inserted_id
        return user_data
    
    @staticmethod
    def authenticate_user(mobile_number: str, password: str) -> Optional[dict]:
        """Authenticate user credentials."""
        client = get_mongo_client()
        user = client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
        
        if not user or not verify_password(password, user["password_hash"]):
            return None
        return user
    
    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[dict]:
        """Get user by ID."""
        client = get_mongo_client()
        try:
            return client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        except Exception:
            return None
    
    @staticmethod
    def update_user_profile(user_id: str, profile_data: dict) -> bool:
        """Update user profile."""
        client = get_mongo_client()
        
        # Check if profile is complete
        profile_complete = all([
            profile_data.get("name"),
            profile_data.get("date_of_birth"),
            profile_data.get("gender")
        ])
        
        update_data = {
            **profile_data,
            "profile_complete": profile_complete,
            "updated_at": datetime.utcnow()
        }
        
        result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": update_data}
        )
        return result.modified_count > 0
    
    @staticmethod
    def update_user_password(user_id: str, new_password: str) -> bool:
        """Update user password."""
        client = get_mongo_client()
        
        result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "password_hash": get_password_hash(new_password),
                "updated_at": datetime.utcnow()
            }}
        )
        return result.modified_count > 0

    @staticmethod
    def delete_user_account(user_id: str) -> bool:
        """Delete a user account.
        
        Moves user data to users_deleted, deletes profile picture, 
        device tokens, and then removes user from users collection.
        """
        client = get_mongo_client()
        db = client["dance_app"]
        
        user = db["users"].find_one({"_id": ObjectId(user_id)})
        if not user:
            return False  # User not found
        
        # 1. Copy user to users_deleted collection
        user_deleted_data = user.copy()
        user_deleted_data["deleted_at"] = datetime.utcnow()
        db["users_deleted"].insert_one(user_deleted_data)
        
        # 2. Delete profile picture from profile_pictures collection
        if user.get("profile_picture_id"):
            try:
                db["profile_pictures"].delete_one({"_id": ObjectId(user.get("profile_picture_id"))})
            except Exception as e:
                logger.error(f"Error deleting profile picture for user {user_id}: {e}")
                # Continue with deletion even if picture removal fails
        
        # 3. Delete device tokens from device_tokens collection
        try:
            db["device_tokens"].delete_many({"user_id": user_id})
        except Exception as e:
            logger.error(f"Error deleting device tokens for user {user_id}: {e}")
            # Continue with deletion
            
        # 4. Delete user from users collection
        result = db["users"].delete_one({"_id": ObjectId(user_id)})
        
        return result.deleted_count > 0 