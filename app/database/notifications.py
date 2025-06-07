"""Notification database operations."""

import re
from datetime import datetime, timedelta
from typing import List, Optional, Tuple, Dict
from bson import ObjectId

from utils.utils import get_mongo_client
from app.models.reactions import EntityType, ReactionType


class PushNotificationOperations:
    """Database operations for push notification management."""
    
    @staticmethod
    def register_device_token(user_id: str, device_token: str, platform: str) -> bool:
        """Register or update device token for a user."""
        client = get_mongo_client()
        
        # First, deactivate any other tokens for this device (in case it was used by another user)
        client["dance_app"]["device_tokens"].update_many(
            {"device_token": device_token, "user_id": {"$ne": user_id}},
            {"$set": {"is_active": False, "updated_at": datetime.utcnow()}}
        )
        
        # Check if user already has a token entry for this platform
        existing_token = client["dance_app"]["device_tokens"].find_one({
            "user_id": user_id,
            "platform": platform
        })
        
        if existing_token:
            # Update existing token
            result = client["dance_app"]["device_tokens"].update_one(
                {"_id": existing_token["_id"]},
                {"$set": {
                    "device_token": device_token,
                    "updated_at": datetime.utcnow(),
                    "is_active": True
                }}
            )
            return result.modified_count > 0
        else:
            # Insert new token entry
            token_data = {
                "user_id": user_id,
                "device_token": device_token,
                "platform": platform,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
                "is_active": True
            }
            
            result = client["dance_app"]["device_tokens"].insert_one(token_data)
            return result.inserted_id is not None
    
    @staticmethod
    def get_device_token_given_user_id(user_id: str) -> Optional[str]:
        """Get active device tokens for multiple users."""
        client = get_mongo_client()
        
        token = client["dance_app"]["device_tokens"].find_one({
            "user_id": user_id,
            "is_active": True
        })
        
        return token["device_token"] if token else None
    
    @staticmethod
    def get_device_tokens(user_ids: List[str]) -> List[dict]:
        """Get active device tokens for multiple users."""
        client = get_mongo_client()
        
        tokens = list(client["dance_app"]["device_tokens"].find({
            "user_id": {"$in": user_ids},
            "is_active": True
        }))
        
        return tokens
    
    @staticmethod
    def deactivate_device_token(device_token: str) -> bool:
        """Deactivate a device token (when it becomes invalid)."""
        client = get_mongo_client()
        
        result = client["dance_app"]["device_tokens"].update_one(
            {"device_token": device_token},
            {"$set": {"is_active": False, "updated_at": datetime.utcnow()}}
        )
        
        return result.modified_count > 0
    
    @staticmethod
    def get_all_active_device_tokens() -> List[dict]:
        """Get all active device tokens for sending test notifications to all users."""
        client = get_mongo_client()
        
        tokens = list(client["dance_app"]["device_tokens"].find({
            "is_active": True
        }))
        
        return tokens


class NotificationOperations:
    """Database operations for notification tracking to prevent duplicates."""
    
    @staticmethod
    def has_notification_been_sent(user_id: str, workshop_uuid: str, notification_type: str) -> bool:
        """Check if a notification has already been sent for a specific workshop to a user."""
        client = get_mongo_client()
        
        existing_notification = client["dance_app"]["notification_history"].find_one({
            "user_id": user_id,
            "workshop_uuid": workshop_uuid,
            "notification_type": notification_type,
            "is_sent": True
        })
        
        return existing_notification is not None
    
    @staticmethod
    def has_artist_notification_been_sent_recently(user_id: str, artist_id: str, days: int = 7) -> bool:
        """Check if any notification has been sent for the same user and artist within the specified days."""
        client = get_mongo_client()
        
        # Calculate the cutoff date
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        # Check if any notification was sent for this user-artist combination within the timeframe
        existing_notification = client["dance_app"]["notification_history"].find_one({
            "user_id": user_id,
            "artist_id": artist_id,
            "is_sent": True,
            "sent_at": {"$gte": cutoff_date}
        })
        
        return existing_notification is not None
    
    @staticmethod
    def get_recent_notification_stats(timeframe_days: int = 7) -> Dict[str, int]:
        """Get statistics about recent notifications sent."""
        client = get_mongo_client()
        
        cutoff_date = datetime.utcnow() - timedelta(days=timeframe_days)
        
        try:
            # Count total notifications sent in timeframe
            total_sent = client["dance_app"]["notifications"].count_documents({
                "sent_at": {"$gte": cutoff_date}
            })
            
            # Count unique users who received notifications
            unique_users_pipeline = [
                {"$match": {"sent_at": {"$gte": cutoff_date}}},
                {"$group": {"_id": "$user_id"}},
                {"$count": "unique_users"}
            ]
            
            unique_users_result = list(client["dance_app"]["notifications"].aggregate(unique_users_pipeline))
            unique_users = unique_users_result[0]["unique_users"] if unique_users_result else 0
            
            return {
                "total_sent": total_sent,
                "unique_users": unique_users,
                "timeframe_days": timeframe_days
            }
            
        except Exception as e:
            print(f"Error getting notification stats: {e}")
            return {"total_sent": 0, "unique_users": 0, "timeframe_days": timeframe_days}

    @staticmethod
    def get_total_notifications_sent() -> int:
        """Get the total count of all notifications sent."""
        client = get_mongo_client()
        
        try:
            # Count all notifications in the notifications collection
            total_count = client["dance_app"]["notifications"].count_documents({})
            return total_count
            
        except Exception as e:
            print(f"Error getting total notifications sent: {e}")
            return 0
    
    @staticmethod
    def get_recent_artist_notification_stats(artist_id: str, days: int = 7) -> dict:
        """Get recent notification statistics for a specific artist."""
        client = get_mongo_client()
        
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        
        try:
            # Count notifications sent for this artist in the timeframe
            count = client["dance_app"]["notifications"].count_documents({
                "artist_id": artist_id,
                "sent_at": {"$gte": cutoff_date}
            })
            
            return {
                "artist_id": artist_id,
                "notifications_sent": count,
                "timeframe_days": days,
                "cutoff_date": cutoff_date.isoformat()
            }
            
        except Exception as e:
            print(f"Error getting recent notification stats for artist {artist_id}: {e}")
            return {
                "artist_id": artist_id,
                "notifications_sent": 0,
                "timeframe_days": days,
                "error": str(e)
            }
    
    @staticmethod
    def record_notification_sent(user_id: str, workshop_uuid: str, artist_id: str, notification_type: str, title: str, body: str) -> bool:
        """Record that a notification has been sent."""
        client = get_mongo_client()
        
        notification_record = {
            "user_id": user_id,
            "workshop_uuid": workshop_uuid,
            "artist_id": artist_id,
            "notification_type": notification_type,
            "title": title,
            "body": body,
            "is_sent": True,
            "sent_at": datetime.utcnow(),
            "created_at": datetime.utcnow()
        }
        
        result = client["dance_app"]["notification_history"].insert_one(notification_record)
        return result.inserted_id is not None
    
    @staticmethod
    def get_workshop_details_for_comparison(workshop_uuid: str) -> Optional[dict]:
        """Get workshop details for comparison to detect changes."""
        client = get_mongo_client()
        
        workshop = client["discovery"]["workshops_v2"].find_one({"uuid": workshop_uuid})
        if not workshop:
            return None
            
        # Extract key details that we want to track for changes
        details = {
            "uuid": workshop.get("uuid"),
            "time_details": workshop.get("time_details", []),
            "pricing_info": workshop.get("pricing_info"),
            "payment_link": workshop.get("payment_link"),
            "is_sold_out": workshop.get("is_sold_out", False)
        }
        
        return details
    
    @staticmethod
    def has_workshop_changed_significantly(workshop_uuid: str) -> Tuple[bool, str]:
        """Check if workshop has changed significantly enough to warrant a new notification.
        
        Returns:
            tuple: (has_changed: bool, change_type: str)
        """
        client = get_mongo_client()
        
        # Get the last notification sent for this workshop
        last_notification = client["dance_app"]["notification_history"].find_one(
            {"workshop_uuid": workshop_uuid},
            sort=[("sent_at", -1)]
        )
        
        if not last_notification:
            return False, ""
        
        # Get current workshop details
        current_workshop = NotificationOperations.get_workshop_details_for_comparison(workshop_uuid)
        if not current_workshop:
            return False, ""
        
        # Check for significant changes
        # 1. Time/Date change
        if last_notification.get("workshop_time_details") != current_workshop.get("time_details"):
            return True, "schedule_change"
        
        # 2. Price drop
        old_price = last_notification.get("workshop_pricing_info", "")
        new_price = current_workshop.get("pricing_info", "")
        if old_price and new_price:
            try:
                # Simple price extraction (you might need to adjust based on your pricing format)
                old_price_num = float(re.findall(r'\d+', old_price)[0])
                new_price_num = float(re.findall(r'\d+', new_price)[0])
                if new_price_num < old_price_num:
                    return True, "price_drop"
            except:
                pass
        
        # 3. Sold out status change (reopened)
        if last_notification.get("workshop_is_sold_out", False) and not current_workshop.get("is_sold_out", False):
            return True, "reopened"
        
        return False, ""
    
    @staticmethod
    def should_send_reminder(workshop_uuid: str, user_id: str) -> bool:
        """Check if we should send a 24-hour reminder for a workshop."""
        client = get_mongo_client()
        
        # Check if reminder already sent
        reminder_sent = client["dance_app"]["notification_history"].find_one({
            "user_id": user_id,
            "workshop_uuid": workshop_uuid,
            "notification_type": "reminder_24h",
            "is_sent": True
        })
        
        if reminder_sent:
            return False
        
        # Get workshop details
        workshop = client["discovery"]["workshops_v2"].find_one({"uuid": workshop_uuid})
        if not workshop:
            return False
        
        # Check if workshop is within 24-48 hours
        for time_detail in workshop.get("time_details", []):
            try:
                workshop_date = datetime(
                    year=time_detail.get("year"),
                    month=time_detail.get("month"),
                    day=time_detail.get("day")
                )
                
                time_until_workshop = workshop_date - datetime.now()
                hours_until = time_until_workshop.total_seconds() / 3600
                
                # Send reminder if workshop is between 24-48 hours away
                if 24 <= hours_until <= 48:
                    return True
            except:
                continue
        
        return False
    
    @staticmethod
    def cleanup_old_notifications(days_to_keep: int = 90) -> int:
        """Clean up old notification history records."""
        client = get_mongo_client()
        
        cutoff_date = datetime.utcnow() - timedelta(days=days_to_keep)
        
        result = client["dance_app"]["notification_history"].delete_many({
            "sent_at": {"$lt": cutoff_date}
        })
        
        return result.deleted_count 