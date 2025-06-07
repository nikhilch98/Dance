"""Admin API routes."""

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Body, UploadFile, File, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.services.auth import verify_admin_user
from app.models.admin import AssignArtistPayload, AssignSongPayload
from utils.utils import get_mongo_client
from app.database.reactions import ReactionOperations
from app.database.users import UserOperations
from app.database.notifications import NotificationOperations
from app.database.workshops import DatabaseOperations
from app.models.reactions import ReactionType, EntityType
from app.services.notifications import NotificationService
import json
import logging

router = APIRouter()
templates = Jinja2Templates(directory="templates")


# Additional models for new endpoints
class TestNotificationPayload(BaseModel):
    """Payload for sending test notifications."""
    artist_id: Optional[str] = None
    title: Optional[str] = "Test Notification"
    body: Optional[str] = "This is a test notification from Nachna admin."


@router.get("/api/artists")
def admin_list_artists(user_id: str = Depends(verify_admin_user)):
    """List all artists for admin."""
    client = get_mongo_client()
    return list(client["discovery"]["artists_v2"].find({}, {"_id": 0}).sort("artist_name", 1))


@router.get("/api/missing_artist_sessions")
def admin_get_missing_artist_sessions(user_id: str = Depends(verify_admin_user)):
    """Get workshops with missing artist assignments."""
    from bson import ObjectId
    
    client = get_mongo_client()
    missing_artist_sessions = []

    # Build a mapping from studio_id to studio_name
    studio_map = {
        s["studio_id"]: s["studio_name"] for s in client["discovery"]["studios"].find()
    }
    
    # Find workshops that have missing or empty artist_id_list
    workshops_cursor = client["discovery"]["workshops_v2"].find({
        "event_type": {"$nin": ["regulars"]},
        "$or": [
            {"artist_id_list": {"$exists": False}},
            {"artist_id_list": None},
            {"artist_id_list": []},
            {"artist_id_list": {"$in": [None, "", "TBA", "tba", "N/A", "n/a"]}}
        ]
    })

    for workshop in workshops_cursor:
        for time_detail in workshop.get("time_details", []):
            if not time_detail:
                continue
                
            # Create session data for each time detail
            session_data = {
                "workshop_uuid": str(workshop["_id"]),
                "date": f"{time_detail.get('year', '')}-{str(time_detail.get('month', '')).zfill(2)}-{str(time_detail.get('day', '')).zfill(2)}",
                "time": f"{time_detail.get('start_time', '')} - {time_detail.get('end_time', '')}" if time_detail.get('end_time') else time_detail.get('start_time', ''),
                "song": workshop.get("song"),
                "studio_name": studio_map.get(workshop["studio_id"], "Unknown Studio"),
                "payment_link": workshop.get("payment_link"),
                "original_by_field": workshop.get("by"),
                "timestamp_epoch": int(datetime(
                    year=time_detail.get('year', 2024),
                    month=time_detail.get('month', 1),
                    day=time_detail.get('day', 1)
                ).timestamp()) if all([time_detail.get('year'), time_detail.get('month'), time_detail.get('day')]) else 0,
                "event_type": workshop.get("event_type"),
            }
            missing_artist_sessions.append(session_data)

    # Sort by timestamp for consistency
    missing_artist_sessions.sort(key=lambda x: x["timestamp_epoch"])
    return missing_artist_sessions


@router.get("/api/missing_song_sessions")
def admin_get_missing_song_sessions(user_id: str = Depends(verify_admin_user)):
    """Get workshops with missing song assignments."""
    from bson import ObjectId
    
    client = get_mongo_client()
    missing_song_sessions = []

    # Build a mapping from studio_id to studio_name
    studio_map = {
        s["studio_id"]: s["studio_name"] for s in client["discovery"]["studios"].find()
    }
    
    # Find workshops that have missing or empty song field
    workshops_cursor = client["discovery"]["workshops_v2"].find({
        "event_type": {"$nin": ["regulars"]},
        "$or": [
            {"song": {"$exists": False}},
            {"song": None},
            {"song": ""},
            {"song": {"$in": ["TBA", "tba", "N/A", "n/a", "To be announced"]}}
        ]
    })

    for workshop in workshops_cursor:
        for time_detail in workshop.get("time_details", []):
            if not time_detail:
                continue
                
            # Create session data for each time detail
            session_data = {
                "workshop_uuid": str(workshop["_id"]),
                "date": f"{time_detail.get('year', '')}-{str(time_detail.get('month', '')).zfill(2)}-{str(time_detail.get('day', '')).zfill(2)}",
                "time": f"{time_detail.get('start_time', '')} - {time_detail.get('end_time', '')}" if time_detail.get('end_time') else time_detail.get('start_time', ''),
                "song": workshop.get("song"),
                "studio_name": studio_map.get(workshop["studio_id"], "Unknown Studio"),
                "payment_link": workshop.get("payment_link"),
                "original_by_field": workshop.get("by"),
                "timestamp_epoch": int(datetime(
                    year=time_detail.get('year', 2024),
                    month=time_detail.get('month', 1),
                    day=time_detail.get('day', 1)
                ).timestamp()) if all([time_detail.get('year'), time_detail.get('month'), time_detail.get('day')]) else 0,
                "event_type": workshop.get("event_type"),
            }
            missing_song_sessions.append(session_data)

    # Sort by timestamp for consistency
    missing_song_sessions.sort(key=lambda x: x["timestamp_epoch"])
    return missing_song_sessions


@router.get("", response_class=HTMLResponse)
async def admin_panel(request: Request, user_id: str = Depends(verify_admin_user)):
    """Serve admin panel."""
    return templates.TemplateResponse(
        "website/admin_missing_artists.html", {"request": request}
    )


@router.put("/api/workshops/{workshop_uuid}/assign_artist")
def admin_assign_artist_to_session(
    workshop_uuid: str, 
    payload: AssignArtistPayload = Body(...), 
    user_id: str = Depends(verify_admin_user)
):
    """Assign artists to a workshop session."""
    from bson import ObjectId
    
    client = get_mongo_client()

    # Join artist names with ' X ' separator
    combined_artist_names = " X ".join(payload.artist_name_list)

    result = client["discovery"]["workshops_v2"].update_one(
        {"_id": ObjectId(workshop_uuid)},
        {
            "$set": {
                "artist_id_list": payload.artist_id_list,
                "by": combined_artist_names,
            }
        },
    )

    if result.matched_count == 0:
        raise HTTPException(
            status_code=404, detail=f"Workshop with UUID {workshop_uuid} not found."
        )

    return {
        "success": True,
        "message": f"Artists {combined_artist_names} assigned to workshop {workshop_uuid}.",
    }


@router.put("/api/workshops/{workshop_uuid}/assign_song")
def admin_assign_song_to_session(
    workshop_uuid: str, 
    payload: AssignSongPayload = Body(...), 
    user_id: str = Depends(verify_admin_user)
):
    """Assign a song to a workshop session."""
    from bson import ObjectId
    
    client = get_mongo_client()

    result = client["discovery"]["workshops_v2"].update_one(
        {"_id": ObjectId(workshop_uuid)},
        {
            "$set": {
                "song": payload.song,
            }
        },
    )

    if result.matched_count == 0:
        raise HTTPException(
            status_code=404, detail=f"Workshop with UUID {workshop_uuid} not found."
        )

    return {
        "success": True,
        "message": f"Song '{payload.song}' assigned to workshop {workshop_uuid}.",
    }


@router.post("/api/send-test-notification")
async def admin_send_test_notification(
    payload: TestNotificationPayload = Body(...), 
    user_id: str = Depends(verify_admin_user)
):
    """Send a test notification to users following a specific artist or all users."""
    print(f"🔍 [ADMIN] Test notification request from user {user_id}")
    print(f"🔍 [ADMIN] Payload: artist_id={payload.artist_id}, title='{payload.title}', body='{payload.body}'")
    
    try:
        print("🔍 [ADMIN] Step 1: Importing required modules...")
        from app.services.notifications import NotificationService
        from app.database.reactions import ReactionOperations
        from app.database.notifications import PushNotificationOperations
        print("✅ [ADMIN] Modules imported successfully")
        
        print("🔍 [ADMIN] Step 2: Initializing notification service...")
        notification_service = NotificationService()
        print("✅ [ADMIN] NotificationService initialized")
        
        if payload.artist_id:
            print(f"🔍 [ADMIN] Step 3a: Getting users following artist {payload.artist_id}...")
            # Send to users following the specific artist
            try:
                notified_user_ids = ReactionOperations.get_notified_users_of_artist(payload.artist_id)
                print(f"✅ [ADMIN] Found {len(notified_user_ids) if notified_user_ids else 0} users following artist")
            except Exception as e:
                print(f"❌ [ADMIN] Error getting users following artist: {e}")
                raise
            
            if not notified_user_ids:
                print("⚠️ [ADMIN] No users found following the artist")
                return {
                    "success": False,
                    "message": f"No users found following artist {payload.artist_id} with notifications enabled."
                }
            
            print("🔍 [ADMIN] Step 3b: Getting artist name...")
            try:
                client = get_mongo_client()
                artist = client["discovery"]["artists_v2"].find_one({"artist_id": payload.artist_id})
                artist_name = artist.get("artist_name", "Unknown Artist") if artist else "Unknown Artist"
                print(f"✅ [ADMIN] Artist name: {artist_name}")
            except Exception as e:
                print(f"❌ [ADMIN] Error getting artist name: {e}")
                artist_name = "Unknown Artist"
            
            title = payload.title or f"Test from {artist_name}"
            body = payload.body or f"This is a test notification for followers of {artist_name}."
            
        else:
            print("🔍 [ADMIN] Step 3a: Getting all users with device tokens...")
            try:
                all_tokens = PushNotificationOperations.get_all_active_device_tokens()
                print(f"✅ [ADMIN] Found {len(all_tokens)} active device tokens")
                notified_user_ids = [token["user_id"] for token in all_tokens if token.get("user_id")]
                print(f"✅ [ADMIN] Extracted {len(notified_user_ids)} unique user IDs")
            except Exception as e:
                print(f"❌ [ADMIN] Error getting all active device tokens: {e}")
                raise
            
            if not notified_user_ids:
                print("⚠️ [ADMIN] No users with active device tokens found")
                return {
                    "success": False,
                    "message": "No users with active device tokens found."
                }
            
            title = payload.title or "Admin Test Notification"
            body = payload.body or "This is a test notification from Nachna admin."
        
        print(f"🔍 [ADMIN] Step 4: Getting device tokens for {len(notified_user_ids)} users...")
        try:
            device_tokens = PushNotificationOperations.get_device_tokens(notified_user_ids)
            print(f"✅ [ADMIN] Found {len(device_tokens)} device tokens")
        except Exception as e:
            print(f"❌ [ADMIN] Error getting device tokens: {e}")
            raise
        
        if not device_tokens:
            print("⚠️ [ADMIN] No device tokens found for target users")
            return {
                "success": False,
                "message": "No device tokens found for the target users."
            }
        
        print("🔍 [ADMIN] Step 5: Filtering iOS tokens...")
        ios_tokens = [token for token in device_tokens if token.get('platform') == 'ios']
        print(f"✅ [ADMIN] Found {len(ios_tokens)} iOS tokens out of {len(device_tokens)} total")
        
        success_count = 0
        total_sent = 0
        
        print(f"🔍 [ADMIN] Step 6: Sending notifications to {len(ios_tokens)} iOS devices...")
        print(f"🔍 [ADMIN] Notification title: '{title}'")
        print(f"🔍 [ADMIN] Notification body: '{body}'")
        
        # Send to iOS devices using APNs
        if ios_tokens:
            for i, token_data in enumerate(ios_tokens):
                device_token = token_data.get('device_token')
                if device_token:
                    print(f"🔍 [ADMIN] Sending to device {i+1}/{len(ios_tokens)}: {device_token[:10]}...")
                    try:
                        success = await notification_service.apns_service.send_notification(
                            device_token=device_token,
                            title=title,
                            body=body,
                            data={"type": "admin_test", "timestamp": str(datetime.now())}
                        )
                        total_sent += 1
                        if success:
                            success_count += 1
                            print(f"✅ [ADMIN] Successfully sent to device {i+1}")
                        else:
                            print(f"❌ [ADMIN] Failed to send to device {i+1}")
                    except Exception as e:
                        print(f"❌ [ADMIN] Error sending to iOS device {device_token[:10]}...: {e}")
                else:
                    print(f"⚠️ [ADMIN] Skipping token {i+1} - no device_token field")
        else:
            print("⚠️ [ADMIN] No iOS tokens to send to")
        
        print(f"✅ [ADMIN] Step 7: Notification sending complete")
        print(f"✅ [ADMIN] Results: {success_count}/{total_sent} successful sends")
        
        return {
            "success": True,
            "message": f"Test notification sent successfully to {success_count}/{total_sent} devices.",
            "details": {
                "total_users": len(notified_user_ids),
                "total_tokens": len(device_tokens),
                "ios_tokens": len(ios_tokens),
                "successful_sends": success_count,
                "total_attempts": total_sent
            }
        }
        
    except Exception as e:
        print(f"❌ [ADMIN] CRITICAL ERROR in send_test_notification: {e}")
        print(f"❌ [ADMIN] Error type: {type(e).__name__}")
        import traceback
        print(f"❌ [ADMIN] Traceback:\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send test notification: {str(e)}"
        ) 


@router.get("/api/app-insights")
async def get_app_insights(user_id: str = Depends(verify_admin_user)):
    """Get application insights and statistics."""
    try:
        # Get total distinct users
        total_users = UserOperations.get_total_user_count()
        
        # Get total distinct likes (user, artist combinations)
        total_likes = ReactionOperations.get_total_reaction_count(
            reaction_type=ReactionType.LIKE,
            entity_type=EntityType.ARTIST
        )
        
        # Get total distinct follows (user, artist combinations)
        total_follows = ReactionOperations.get_total_reaction_count(
            reaction_type=ReactionType.NOTIFY,
            entity_type=EntityType.ARTIST
        )
        
        # Get additional statistics
        total_workshops = DatabaseOperations.get_total_workshop_count()
        total_notifications_sent = NotificationOperations.get_total_notifications_sent()
        
        return {
            "success": True,
            "data": {
                "total_users": total_users,
                "total_likes": total_likes,
                "total_follows": total_follows,
                "total_workshops": total_workshops,
                "total_notifications_sent": total_notifications_sent,
                "last_updated": datetime.utcnow().isoformat()
            }
        }
        
    except Exception as e:
        logging.error(f"Error getting app insights: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get app insights: {str(e)}"
        )


@router.get("/api/workshops/missing-instagram-links")
async def get_workshops_missing_instagram_links(user_id: str = Depends(verify_admin_user)):
    """Get all workshops that are missing Instagram links."""
    try:
        client = get_mongo_client()
        
        # Find workshops where choreo_insta_link is None or empty
        workshops = list(client["discovery"]["workshops_v2"].find({
            "$or": [
                {"choreo_insta_link": None},
                {"choreo_insta_link": ""},
                {"choreo_insta_link": {"$exists": False}}
            ]
        }))
        
        # Enrich with artist Instagram links
        artist_map = {artist["artist_id"]: artist for artist in client["discovery"]["artists_v2"].find({}, {"_id": 0, "artist_id": 1, "instagram_link": 1})}
        result = []
        for workshop in workshops:
            # Get artist Instagram links
            artist_instagram_links = []
            artist_id_list = workshop.get("artist_id_list", [])
            
            if artist_id_list:
                for artist_id in artist_id_list:
                    if artist_id and artist_id not in [None, "", "TBA", "tba", "N/A", "n/a"]:
                        artist = artist_map.get(artist_id)
                        if artist and artist.get("instagram_link"):
                            artist_instagram_links.append(artist["instagram_link"])
            
            workshop_data = {
                "uuid": workshop.get("uuid"),
                "workshop_name": workshop.get("workshop_name"),
                "by": workshop.get("by"),
                "artist_id_list": artist_id_list,
                "artist_instagram_links": artist_instagram_links,
            }
            result.append(workshop_data)
        
        # Sort by created_at descending (newest first)
        result.sort(key=lambda x: x.get("uuid", ""), reverse=True)
        
        return result
        
    except Exception as e:
        logging.error(f"Error getting workshops missing Instagram links: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get workshops missing Instagram links: {str(e)}"
        )


class UpdateInstagramLinkPayload(BaseModel):
    """Payload for updating workshop Instagram link."""
    choreo_insta_link: str


@router.put("/api/workshops/{workshop_uuid}/instagram-link")
async def update_workshop_instagram_link(
    workshop_uuid: str,
    payload: UpdateInstagramLinkPayload = Body(...),
    user_id: str = Depends(verify_admin_user)
):
    """Update the Instagram link for a specific workshop."""
    try:
        client = get_mongo_client()
        
        # Validate that the workshop exists
        workshop = client["discovery"]["workshops_v2"].find_one({"uuid": workshop_uuid})
        if not workshop:
            raise HTTPException(
                status_code=404,
                detail=f"Workshop with UUID {workshop_uuid} not found."
            )
        
        # Update the Instagram link
        result = client["discovery"]["workshops_v2"].update_one(
            {"uuid": workshop_uuid},
            {
                "$set": {
                    "choreo_insta_link": payload.choreo_insta_link,
                    "updated_at": datetime.utcnow().isoformat()
                }
            }
        )
        
        if result.modified_count == 0:
            raise HTTPException(
                status_code=400,
                detail="Failed to update workshop Instagram link."
            )
        
        return {
            "success": True,
            "message": f"Instagram link updated successfully for workshop {workshop_uuid}.",
            "workshop_uuid": workshop_uuid,
            "choreo_insta_link": payload.choreo_insta_link
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error updating workshop Instagram link: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update workshop Instagram link: {str(e)}"
        ) 