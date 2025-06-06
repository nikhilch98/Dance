"""Notification services."""

import asyncio
import threading
import time as time_module
from datetime import datetime, timedelta
from typing import Dict, Optional

import httpx
import jwt
from cryptography.hazmat.primitives import serialization

from app.config.constants import APNsConfig
from app.config.settings import get_settings
from app.database.reactions import ReactionOperations
from app.database.notifications import PushNotificationOperations, NotificationOperations
from utils.utils import get_mongo_client

settings = get_settings()


class APNsService:
    """Apple Push Notification service integration with proper JWT authentication."""
    
    def __init__(self, use_sandbox: bool = True):
        self.base_url = APNsConfig.SANDBOX_URL if use_sandbox else APNsConfig.PRODUCTION_URL
        self.auth_key_id = settings.apns_auth_key_id
        self.team_id = settings.apns_team_id
        self.bundle_id = settings.apns_bundle_id
        self.key_path = settings.apns_key_path
        self._private_key = None
        self._load_private_key()
        
    def _load_private_key(self):
        """Load the private key from the .p8 file."""
        try:
            with open(self.key_path, 'rb') as key_file:
                self._private_key = serialization.load_pem_private_key(
                    key_file.read(),
                    password=None
                )
            print(f"✅ APNs private key loaded successfully from {self.key_path}")
        except FileNotFoundError:
            print(f"❌ APNs private key file not found: {self.key_path}")
            self._private_key = None
        except Exception as e:
            print(f"❌ Error loading APNs private key: {str(e)}")
            self._private_key = None
    
    def _generate_jwt_token(self):
        """Generate JWT token for APNs authentication."""
        if not self._private_key:
            raise Exception("Private key not loaded")
            
        # JWT payload
        now = datetime.utcnow()
        payload = {
            'iss': self.team_id,  # Issuer (Team ID)
            'iat': int(now.timestamp()),  # Issued at
            'exp': int((now + timedelta(minutes=55)).timestamp()),  # Expires (max 1 hour)
        }
        
        # JWT headers
        headers = {
            'alg': 'ES256',
            'kid': self.auth_key_id,  # Key ID
        }
        
        # Generate the token
        token = jwt.encode(
            payload, 
            self._private_key, 
            algorithm='ES256', 
            headers=headers
        )
        
        return token
        
    async def send_notification(self, device_token: str, title: str, body: str, data: dict = None):
        """Send push notification via APNs."""
        if not self._private_key:
            print("❌ APNs private key not available")
            return False
            
        payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "sound": "default",
                "badge": 1,
                "mutable-content": 1
            }
        }
        
        if data:
            payload.update(data)
        
        try:
            jwt_token = self._generate_jwt_token()
        except Exception as e:
            print(f"❌ Failed to generate JWT token: {str(e)}")
            return False
        
        headers = {
            "authorization": f"bearer {jwt_token}",
            "apns-topic": self.bundle_id,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-expiration": "0"
        }
        
        try:
            # Use HTTP/2 with proper configuration
            async with httpx.AsyncClient(
                http2=True,
                timeout=30.0,
                verify=True
            ) as client:
                response = await client.post(
                    f"{self.base_url}/3/device/{device_token}",
                    headers=headers,
                    json=payload
                )
                
                if response.status_code == 200:
                    print(f"✅ APNs notification sent successfully to {device_token[:10]}...")
                    return True
                else:
                    print(f"❌ APNs error: {response.status_code} - {response.text}")
                    # Log the response for debugging
                    try:
                        error_data = response.json()
                        print(f"   Error details: {error_data}")
                    except:
                        pass
                    return False
                    
        except httpx.TimeoutException:
            print("❌ APNs request timeout")
            return False
        except Exception as e:
            print(f"❌ APNs exception: {str(e)}")
            import traceback
            traceback.print_exc()
            return False


class NotificationService:
    """Service for handling workshop notifications and watchers."""
    
    def __init__(self):
        self.apns_service = APNsService(use_sandbox=settings.apns_use_sandbox)
    
    def start_workshop_notification_watcher(self):
        """Start watching for new workshop insertions and updates to send notifications."""
        import threading
        
        def workshop_notification_watcher():
            client = get_mongo_client()
            db = client["discovery"]
            workshops_collection = db["workshops_v2"]
            
            # Watch for both insert and update operations
            pipeline = [
                {
                    "$match": {
                        "operationType": {"$in": ["insert", "update", "replace"]}
                    }
                }
            ]
            
            try:
                with workshops_collection.watch(pipeline=pipeline, full_document="updateLookup") as stream:
                    for change in stream:
                        try:
                            operation_type = change['operationType']
                            print(f"Workshop change detected: {operation_type}")
                            
                            # Get the full document
                            workshop = change.get('fullDocument')
                            if not workshop:
                                continue
                            
                            workshop_uuid = workshop.get('uuid')
                            if not workshop_uuid:
                                print(f"Workshop UUID not found, skipping")
                                continue
                            
                            # Extract artist IDs from the workshop
                            artist_ids = workshop.get('artist_id_list', [])
                            if not artist_ids:
                                print(f"No artist IDs found in workshop {workshop_uuid}")
                                continue
                            
                            # Determine notification type based on operation and changes
                            if operation_type == "insert":
                                # New workshop - send new workshop notifications
                                for artist_id in artist_ids:
                                    if artist_id and artist_id not in [None, "", "TBA", "tba", "N/A", "n/a"]:
                                        asyncio.run(self.send_workshop_notifications(artist_id, workshop, "new_workshop"))
                            
                            elif operation_type in ["update", "replace"]:
                                # Check if this is a significant change
                                has_changed, change_type = NotificationOperations.has_workshop_changed_significantly(workshop_uuid)
                                
                                if has_changed and change_type:
                                    # Send update notifications
                                    for artist_id in artist_ids:
                                        if artist_id and artist_id not in [None, "", "TBA", "tba", "N/A", "n/a"]:
                                            asyncio.run(self.send_workshop_notifications(artist_id, workshop, change_type))
                            
                        except Exception as e:
                            print(f"Error processing workshop change: {e}")
                            import traceback
                            traceback.print_exc()
                            
            except Exception as e:
                print(f"Workshop notification watcher error: {e}")
                import traceback
                traceback.print_exc()
        
        def reminder_notification_scheduler():
            """Periodically check for workshops that need 24-hour reminders."""
            import time as time_module
            from datetime import datetime, timedelta
            
            while True:
                try:
                    # Sleep for 1 hour between checks
                    time_module.sleep(3600)
                    
                    client = get_mongo_client()
                    
                    # Get all workshops happening in the next 24-48 hours
                    current_time = datetime.utcnow()
                    tomorrow = current_time + timedelta(days=1)
                    day_after = current_time + timedelta(days=2)
                    
                    # Find workshops in the reminder window
                    workshops = client["discovery"]["workshops_v2"].find({
                        "event_type": {"$nin": ["regulars"]}
                    })
                    
                    for workshop in workshops:
                        workshop_uuid = workshop.get('uuid')
                        if not workshop_uuid:
                            continue
                        
                        artist_ids = workshop.get('artist_id_list', [])
                        if not artist_ids:
                            continue
                        
                        # Check each time detail
                        for time_detail in workshop.get('time_details', []):
                            try:
                                workshop_date = datetime(
                                    year=time_detail.get('year'),
                                    month=time_detail.get('month'),
                                    day=time_detail.get('day')
                                )
                                
                                # Check if in reminder window (24-48 hours)
                                if tomorrow <= workshop_date <= day_after:
                                    # Get all users who have notifications enabled for any artist in this workshop
                                    for artist_id in artist_ids:
                                        if artist_id and artist_id not in [None, "", "TBA", "tba", "N/A", "n/a"]:
                                            notified_users = ReactionOperations.get_notified_users_of_artist(artist_id)
                                            
                                            # Check each user if they need a reminder
                                            for user_id in notified_users:
                                                if NotificationOperations.should_send_reminder(workshop_uuid, user_id):
                                                    # Send reminder notification
                                                    asyncio.run(self.send_workshop_notifications(artist_id, workshop, "reminder_24h"))
                                                    break  # Only send one reminder per workshop
                            except Exception as e:
                                print(f"Error checking workshop for reminder: {e}")
                                continue
                    
                except Exception as e:
                    print(f"Error in reminder notification scheduler: {e}")
                    import traceback
                    traceback.print_exc()
        
        # Start the watcher in a separate thread
        threading.Thread(target=workshop_notification_watcher, daemon=True).start()
        
        # Start the reminder scheduler in a separate thread
        threading.Thread(target=reminder_notification_scheduler, daemon=True).start()
    
    async def send_workshop_notifications(self, artist_id: str, workshop_data: dict, notification_type: str = "new_workshop"):
        """Send push notifications to users with notifications enabled when a new workshop is added."""
        try:
            workshop_uuid = workshop_data.get('uuid', '')
            if not workshop_uuid:
                print(f"Workshop UUID not found, skipping notification")
                return
                
            # Get all users who have notifications enabled for the artist
            notified_user_ids = ReactionOperations.get_notified_users_of_artist(artist_id)
            
            if not notified_user_ids:
                print(f"No users with notifications enabled found for artist {artist_id}")
                return
            
            # Log recent notification statistics for this artist
            recent_stats = NotificationOperations.get_recent_notification_stats(artist_id, days=7)
            print(f"📊 Recent notification stats for artist {artist_id}:")
            print(f"   - Total notifications in last 7 days: {recent_stats['total_notifications']}")
            print(f"   - Unique users notified: {recent_stats['unique_users_notified']}")
            print(f"   - Notification types: {recent_stats['notification_types']}")
            
            # Filter out users who have already received this specific notification
            users_to_notify = []
            for user_id in notified_user_ids:
                # Check if this specific workshop notification has been sent
                if not NotificationOperations.has_notification_been_sent(user_id, workshop_uuid, notification_type):
                    # For reminder notifications, always send regardless of recent notifications
                    # For other notifications, check if any notification for this artist has been sent in the last week
                    if notification_type == "reminder_24h":
                        users_to_notify.append(user_id)
                    elif not NotificationOperations.has_artist_notification_been_sent_recently(user_id, artist_id, days=7):
                        users_to_notify.append(user_id)
                    else:
                        print(f"Skipping notification for user {user_id} - already notified about artist {artist_id} within last 7 days")
                else:
                    print(f"Skipping notification for user {user_id} - already notified about workshop {workshop_uuid}")
            
            if not users_to_notify:
                print(f"All users have either been notified about workshop {workshop_uuid} or received artist {artist_id} notifications within the last week")
                return
            
            # Get device tokens for users to notify
            device_tokens = PushNotificationOperations.get_device_tokens(users_to_notify)
            
            if not device_tokens:
                print(f"No device tokens found for users to notify")
                return
            
            # Get artist name from database
            client = get_mongo_client()
            artist = client["discovery"]["artists_v2"].find_one({"artist_id": artist_id})
            artist_name = artist.get("artist_name", "Your favorite artist") if artist else "Your favorite artist"
            
            # Create notification content based on type
            if notification_type == "new_workshop":
                title = f"🎉 {artist_name} is back!"
                body = f"New workshop tickets are now available in Bengaluru! Book ASAP before they run out! 💃"
            elif notification_type == "schedule_change":
                title = f"📅 Schedule Update: {artist_name}"
                body = f"The workshop schedule has been updated. Check the new timings!"
            elif notification_type == "price_drop":
                title = f"💰 Price Drop Alert: {artist_name}"
                body = f"Great news! The workshop price has been reduced. Book now!"
            elif notification_type == "reopened":
                title = f"🎟️ Tickets Available Again: {artist_name}"
                body = f"Previously sold-out workshop now has tickets available!"
            elif notification_type == "reminder_24h":
                title = f"⏰ Workshop Tomorrow: {artist_name}"
                body = f"Don't forget! Your workshop is tomorrow. Get ready to dance! 🕺"
            else:
                title = f"Update: {artist_name}"
                body = f"There's an update about the workshop. Check it out!"
            
            # Data for deep linking
            notification_data = {
                'artist_id': artist_id,
                'workshop_id': workshop_uuid,
                'type': notification_type
            }
            
            print(f"Sending {notification_type} notification to {len(users_to_notify)} users (filtered from {len(notified_user_ids)} total):")
            print(f"Title: {title}")
            print(f"Body: {body}")
            print(f"Workshop UUID: {workshop_uuid}")
            print(f"Artist ID: {artist_id}")
            
            # Send APNs notifications to iOS devices
            ios_tokens = [token for token in device_tokens if token.get('platform') == 'ios']
            android_tokens = [token for token in device_tokens if token.get('platform') == 'android']
            
            success_count = 0
            total_sent = 0
            
            # Send to iOS devices using APNs
            if ios_tokens:
                print(f"Sending to {len(ios_tokens)} iOS devices...")
                for token_data in ios_tokens:
                    device_token = token_data.get('device_token')
                    user_id = token_data.get('user_id')
                    if device_token and user_id:
                        try:
                            success = await self.apns_service.send_notification(
                                device_token=device_token,
                                title=title,
                                body=body,
                                data=notification_data
                            )
                            total_sent += 1
                            if success:
                                success_count += 1
                                # Record that notification was sent
                                NotificationOperations.record_notification_sent(
                                    user_id=user_id,
                                    workshop_uuid=workshop_uuid,
                                    artist_id=artist_id,
                                    notification_type=notification_type,
                                    title=title,
                                    body=body
                                )
                            else:
                                # Mark token as inactive if send failed
                                PushNotificationOperations.deactivate_device_token(device_token)
                                print(f"Deactivated invalid device token: {device_token[:10]}...")
                        except Exception as e:
                            print(f"Error sending to iOS device {device_token[:10]}...: {e}")
            
            # For Android devices, you would typically use Firebase Cloud Messaging (FCM)
            if android_tokens:
                print(f"Android FCM notifications not implemented yet for {len(android_tokens)} devices")
            
            print(f"✅ Notification sending complete: {success_count}/{total_sent} successful")
            print(f"📊 Filtered out {len(notified_user_ids) - len(users_to_notify)} users due to recent notifications")
            
        except Exception as e:
            print(f"❌ Error sending workshop notifications: {str(e)}")
            import traceback
            traceback.print_exc()


# Global instances
notification_service = NotificationService()
apns_service = notification_service.apns_service


def start_workshop_notification_watcher():
    """Start the workshop notification watcher."""
    notification_service.start_workshop_notification_watcher()


async def send_workshop_notifications(artist_id: str, workshop_data: dict, notification_type: str = "new_workshop"):
    """Send workshop notifications."""
    await notification_service.send_workshop_notifications(artist_id, workshop_data, notification_type) 