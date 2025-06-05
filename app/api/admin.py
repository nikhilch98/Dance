"""Admin API routes."""

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request
from pydantic import BaseModel
from typing import Optional

from app.services.auth import verify_admin_user
from app.models.admin import AssignArtistPayload, AssignSongPayload
from utils.utils import get_mongo_client

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
    try:
        from app.services.notifications import NotificationService
        from app.database.reactions import ReactionOperations
        from app.database.push_notifications import PushNotificationOperations
        
        notification_service = NotificationService()
        
        if payload.artist_id:
            # Send to users following the specific artist
            notified_user_ids = ReactionOperations.get_notified_users_of_artist(payload.artist_id)
            
            if not notified_user_ids:
                return {
                    "success": False,
                    "message": f"No users found following artist {payload.artist_id} with notifications enabled."
                }
            
            # Get artist name
            client = get_mongo_client()
            artist = client["discovery"]["artists_v2"].find_one({"artist_id": payload.artist_id})
            artist_name = artist.get("artist_name", "Unknown Artist") if artist else "Unknown Artist"
            
            title = payload.title or f"Test from {artist_name}"
            body = payload.body or f"This is a test notification for followers of {artist_name}."
            
        else:
            # Send to all users with device tokens
            all_tokens = PushNotificationOperations.get_all_active_device_tokens()
            notified_user_ids = [token["user_id"] for token in all_tokens if token.get("user_id")]
            
            if not notified_user_ids:
                return {
                    "success": False,
                    "message": "No users with active device tokens found."
                }
            
            title = payload.title or "Admin Test Notification"
            body = payload.body or "This is a test notification from Nachna admin."
        
        # Get device tokens for the users
        device_tokens = PushNotificationOperations.get_device_tokens(notified_user_ids)
        
        if not device_tokens:
            return {
                "success": False,
                "message": "No device tokens found for the target users."
            }
        
        # Send notifications
        ios_tokens = [token for token in device_tokens if token.get('platform') == 'ios']
        
        success_count = 0
        total_sent = 0
        
        # Send to iOS devices using APNs
        if ios_tokens:
            for token_data in ios_tokens:
                device_token = token_data.get('device_token')
                if device_token:
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
                    except Exception as e:
                        print(f"Error sending to iOS device {device_token[:10]}...: {e}")
        
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
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send test notification: {str(e)}"
        ) 