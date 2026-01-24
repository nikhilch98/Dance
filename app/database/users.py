"""User database operations."""

from datetime import datetime
from typing import Optional
from bson import ObjectId
from bson.errors import InvalidId
from fastapi import HTTPException, status

from app.config.logging_config import get_logger
from utils.utils import get_mongo_client
from app.database.rewards import RewardOperations

logger = get_logger(__name__)


def is_valid_object_id(value: str) -> bool:
    """Check if a string is a valid MongoDB ObjectId."""
    if not value or not isinstance(value, str):
        return False
    try:
        ObjectId(value)
        return True
    except (InvalidId, TypeError):
        return False





class UserOperations:
    """Database operations for user management."""
    
    @staticmethod
    def create_or_get_user(mobile_number: str) -> dict:
        """Create a new user or get existing user by mobile number."""
        client = get_mongo_client()
        
        # Check if user already exists
        existing_user = client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
        if existing_user:
            return existing_user
        
        # Create new user
        user_data = {
            "mobile_number": mobile_number,
            "name": None,
            "date_of_birth": None,
            "gender": None,
            "profile_complete": False,
            "is_admin": False,
            "admin_access_list": [],
            "admin_studios_list": [],
            "admin_artist_access_denied_list": [],
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }
        
        result = client["dance_app"]["users"].insert_one(user_data)
        user_data["_id"] = result.inserted_id

        # Award welcome bonus to new user
        try:
            user_id_str = str(user_data["_id"])
            RewardOperations.award_welcome_bonus(user_id_str)
            logger.info(f"Welcome bonus awarded to new user {user_id_str}")
        except Exception as e:
            logger.error(f"Failed to award welcome bonus to new user {user_data['_id']}: {e}")
            # Don't fail the user creation if welcome bonus fails
            pass

        return user_data
    
    @staticmethod
    def get_user_by_mobile(mobile_number: str) -> Optional[dict]:
        """Get user by mobile number."""
        client = get_mongo_client()
        return client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
    
    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[dict]:
        """Get user by ID."""
        if not is_valid_object_id(user_id):
            logger.warning(f"Invalid user_id format: {user_id[:20] if user_id else 'None'}...")
            return None

        client = get_mongo_client()
        try:
            return client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        except InvalidId:
            logger.warning(f"Invalid ObjectId format for user_id: {user_id[:20]}...")
            return None
        except Exception as e:
            logger.exception(f"Error fetching user by id: {e}")
            return None
    
    @staticmethod
    def update_user_profile(user_id: str, profile_data: dict) -> bool:
        """Update user profile."""
        client = get_mongo_client()

        # First update the profile with new data
        update_data = {
            **profile_data,
            "updated_at": datetime.utcnow()
        }

        result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": update_data}
        )

        if result.modified_count == 0:
            return False

        # Now check profile completeness based on the updated user data
        updated_user = client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        if not updated_user:
            return False

        # Check if profile is complete (has all required fields with actual values)
        profile_complete = all([
            updated_user.get("name") and updated_user.get("name").strip(),
            updated_user.get("date_of_birth") and updated_user.get("date_of_birth").strip(),
            updated_user.get("gender") and updated_user.get("gender").strip()
        ])

        # Update the profile_complete status
        client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"profile_complete": profile_complete}}
        )

        return True
    


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

    @staticmethod
    def delete_user(user_id: str) -> bool:
        """Delete a user and all their associated data."""
        client = get_mongo_client()
        
        try:
            # Delete user document
            user_result = client["dance_app"]["users"].delete_one({"_id": ObjectId(user_id)})
            
            # Delete user's reactions
            client["dance_app"]["reactions"].delete_many({"user_id": user_id})
            
            # Delete user's device tokens
            client["dance_app"]["device_tokens"].delete_many({"user_id": user_id})
            
            # Delete user's profile picture if exists
            client["dance_app"]["profile_pictures"].delete_many({"user_id": user_id})
            
            return user_result.deleted_count > 0
            
        except Exception as e:
            logger.exception(f"Error deleting user {user_id}: {e}")
            return False

    @staticmethod
    def get_total_user_count() -> int:
        """Get the total count of distinct users in the database."""
        client = get_mongo_client()
        
        try:
            # Count all users in the users collection
            total_count = client["dance_app"]["users"].count_documents({})
            return total_count
            
        except Exception as e:
            logger.exception(f"Error getting total user count: {e}")
            return 0 

    @staticmethod
    def add_artist(artist_id: str, artist_name: str, artist_aliases: list = None) -> dict:
        """Adds a new artist to the database.

        Args:
            artist_id: The artist's Instagram ID (used as unique identifier)
            artist_name: The artist's display name
            artist_aliases: Optional list of alternative names/nicknames for the artist
        """
        client = get_mongo_client()
        db = client["discovery"]

        instagram_link = f"https://www.instagram.com/{artist_id}/"

        artist_data = {
            "artist_id": artist_id,
            "artist_name": artist_name,
            "instagram_link": instagram_link,
            "image_url": None,
            "artist_aliases": artist_aliases if artist_aliases else [],
        }

        result = db["artists_v2"].update_one(
            {"artist_id": artist_id},
            {"$set": artist_data},
            upsert=True
        )

        artist_data["_id"] = result.upserted_id
        return artist_data 