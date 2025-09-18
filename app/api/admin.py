"""Admin API routes."""

from datetime import datetime
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, status, Body, UploadFile, File, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.services.auth import verify_admin_user
from app.models.admin import AssignArtistPayload, AssignSongPayload, CreateArtistPayload, QRVerificationRequest, QRVerificationResponse, MarkAttendanceRequest, MarkAttendanceResponse
from utils.utils import get_mongo_client
from app.database.reactions import ReactionOperations
from app.database.users import UserOperations
from app.database.notifications import NotificationOperations
from app.database.workshops import DatabaseOperations
from app.models.reactions import ReactionType, EntityType
from app.services.notifications import NotificationService
from app.services.qr_service import get_qr_service
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


@router.get("/artists")
def admin_list_artists(user_id: str = Depends(verify_admin_user)):
    """List all artists for admin."""
    client = get_mongo_client()
    return list(client["discovery"]["artists_v2"].find({}, {"_id": 0}).sort("artist_name", 1))


@router.post("/artist")
def admin_add_artist(
    payload: CreateArtistPayload = Body(...),
    user_id: str = Depends(verify_admin_user)
):
    """Add a new artist."""
    try:
        # Check if artist already exists
        client = get_mongo_client()
        existing_artist = client["discovery"]["artists_v2"].find_one({"artist_id": payload.artist_id})
        if existing_artist:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Artist with ID '{payload.artist_id}' already exists."
            )

        UserOperations.add_artist(
            artist_id=payload.artist_id,
            artist_name=payload.artist_name
        )
        return {
            "success": True,
            "message": "Artist added successfully.",
        }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error adding new artist: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add new artist: {str(e)}"
        )


@router.get("/missing_artist_sessions")
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
        "is_archived": {"$ne": True},
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
                "payment_link_type": workshop.get("payment_link_type"),
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


@router.get("/missing_song_sessions")
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
        "is_archived": {"$ne": True},
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
                "payment_link_type": workshop.get("payment_link_type"),
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


@router.put("/workshops/{workshop_uuid}/assign_artist")
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


@router.put("/workshops/{workshop_uuid}/assign_song")
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
                "song": payload.song.lower() if payload.song else None,
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


@router.post("/send-test-notification")
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


@router.get("/app-insights")
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


@router.get("/workshops/missing-instagram-links")
async def get_workshops_missing_instagram_links(user_id: str = Depends(verify_admin_user)):
    """Get all workshops that are missing Instagram links."""
    try:
        client = get_mongo_client()
        
        # Find workshops where choreo_insta_link is None or empty
        workshops = list(client["discovery"]["workshops_v2"].find({
            "is_archived": {"$ne": True},
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
                "workshop_id": str(workshop["_id"]),
                "workshop_name": workshop.get("workshop_name"),
                "song": workshop.get("song"),
                "by": workshop.get("by") if workshop.get("by") else "",
                "artist_id_list": artist_id_list,
                "artist_instagram_links": artist_instagram_links,
            }
            result.append(workshop_data)
        
        # Sort by created_at descending (newest first)
        result.sort(key=lambda x: x.get("by_sort_key", ""), reverse=True)
        
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


@router.put("/workshops/{workshop_id}/instagram-link")
async def update_workshop_instagram_link(
    workshop_id: str,
    payload: UpdateInstagramLinkPayload = Body(...),
    user_id: str = Depends(verify_admin_user)
):
    """Update the Instagram link for a specific workshop."""
    try:
        from bson import ObjectId
        client = get_mongo_client()
        
        # Validate that the workshop exists using MongoDB _id
        try:
            object_id = ObjectId(workshop_id)
        except Exception:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid workshop ID format: {workshop_id}"
            )
            
        workshop = client["discovery"]["workshops_v2"].find_one({"_id": object_id, "is_archived": {"$ne": True}})
        if not workshop:
            raise HTTPException(
                status_code=404,
                detail=f"Workshop with ID {workshop_id} not found."
            )
        
        # Update the Instagram link
        result = client["discovery"]["workshops_v2"].update_one(
            {"_id": object_id},
            {
                "$set": {
                    "choreo_insta_link": payload.choreo_insta_link,
                }
            }
        )
        client["discovery"]["choreo_links"].update_one(
            {"choreo_insta_link": payload.choreo_insta_link},
            {
                "$set": {
                    "choreo_insta_link": payload.choreo_insta_link,
                    "artist_id_list": workshop.get("artist_id_list", []),
                    "song": workshop.get("song", "").lower() if workshop.get("song") else "",
                }
            },
            upsert=True
        )
        
        if result.modified_count == 0:
            raise HTTPException(
                status_code=400,
                detail="Failed to update workshop Instagram link."
            )
        
        return {
            "success": True,
            "message": f"Instagram link updated successfully for workshop {workshop_id}.",
            "workshop_id": workshop_id,
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


@router.get("/workshop-registrations")
async def get_workshop_registrations(
    user_id: str = Depends(verify_admin_user),
    artist_filter: Optional[str] = None,
    song_filter: Optional[str] = None,
    search_term: Optional[str] = None
):
    """Get workshop registration details for admin."""
    try:
        client = get_mongo_client()
        db = client["dance_app"]
        discovery_db = client["discovery"]

        admin_user_details = db["users"].find_one({"_id": ObjectId(user_id)})
        admin_studios_list = admin_user_details.get("admin_studios_list", [])

        # Execute aggregation
        orders = list(db["orders"].find({"status":"paid"}))

        # Process the results to get artist names and workshop details
        registrations = []
        for order in orders:
            # Get artist names from artist_id_list
            workshop_uuid = order["workshop_uuids"][0]
            workshop = discovery_db["workshops_v2"].find_one({"uuid": workshop_uuid})
            if not ("all" in admin_studios_list or workshop["studio_id"] in admin_studios_list):
                continue
            registration = {
                "name": order.get("payment_gateway_details", {}).get("customer", {}).get("name", ""),
                "phone": order.get("payment_gateway_details", {}).get("customer", {}).get("contact", ""),
                "final_amount": order.get("amount", 0)/100,
                "artist_name": " X ".join(order.get("workshop_details", {}).get("artist_names", [])),
                "workshop_song": order.get("workshop_details", {}).get("title", "").replace(" - Workshop",""),
                "workshop_date": order.get("workshop_details", {}).get("date", ""),
                "workshop_time": order.get("workshop_details", {}).get("time", ""),
                "order_id": order.get("order_id", ""),
                "created_at": order.get("created_at", ""),
                "studio_name": order.get("workshop_details", {}).get("studio_name", "")
            }

            registrations.append(registration)

        # Apply filters
        filtered_registrations = registrations

        if artist_filter:
            filtered_registrations = [r for r in filtered_registrations if artist_filter.lower() in r["artist_name"].lower()]

        if song_filter:
            filtered_registrations = [r for r in filtered_registrations if song_filter.lower() in r["workshop_song"].lower()]

        if search_term:
            search_lower = search_term.lower()
            filtered_registrations = [r for r in filtered_registrations if
                search_lower in r["name"].lower() or
                search_lower in r["phone"]
            ]

        # Sort by creation date (newest first)
        filtered_registrations.sort(key=lambda x: x.get("created_at", ""), reverse=True)

        return {
            "success": True,
            "registrations": filtered_registrations,
            "total_count": len(filtered_registrations),
            "filters_applied": {
                "artist_filter": artist_filter,
                "song_filter": song_filter,
                "search_term": search_term
            }
        }

    except Exception as e:
        logging.exception(f"Error getting workshop registrations: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get workshop registrations: {str(e)}"
        ) 


@router.get("/artists/{artist_id}/choreo-links")
async def get_artist_choreo_links(
    artist_id: str,
    user_id: str = Depends(verify_admin_user)
):
    """Get all existing choreo links for a specific artist."""
    try:
        client = get_mongo_client()
        
        # Find all choreo links that include this artist
        choreo_links = list(client["discovery"]["choreo_links"].find({
            "artist_id_list": {"$in": [artist_id]}
        }, {
            "_id": 0,
            "choreo_insta_link": 1,
            "song": 1,
            "artist_id_list": 1
        }))
        
        # Remove duplicates and format for display
        unique_links = {}
        for link_data in choreo_links:
            url = link_data.get("choreo_insta_link", "")
            if url and url not in unique_links:
                unique_links[url] = {
                    "url": url,
                    "song": link_data.get("song", "").title() if link_data.get("song") else "Unknown Song",
                    "display_text": f"{link_data.get('song', 'Unknown Song').title() if link_data.get('song') else 'Unknown Song'} - {url}"
                }
        
        result = list(unique_links.values())
        result.sort(key=lambda x: x["song"])
        
        return {
            "success": True,
            "data": result,
            "count": len(result)
        }
        
    except Exception as e:
        logging.error(f"Error getting artist choreo links: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get artist choreo links: {str(e)}"
        )


@router.post("/verify-qr", response_model=QRVerificationResponse)
async def verify_qr_code(
    request: QRVerificationRequest,
    user_id: str = Depends(verify_admin_user)
):
    """Verify QR code authenticity and extract registration data."""
    try:
        qr_service = get_qr_service()
        verification_result = qr_service.verify_qr_code(request.qr_data)
        
        # Log the verification attempt
        logging.info(f"Admin {user_id} verified QR code - Valid: {verification_result.get('valid', False)}")
        
        if verification_result.get("valid"):
            # Log successful verification with order details
            registration_data = verification_result.get("registration_data", {})
            order_id = registration_data.get("order_id", "unknown")
            user_name = registration_data.get("registration", {}).get("user_name", "unknown")
            workshop_title = registration_data.get("workshop", {}).get("title", "unknown")
            
            logging.info(f"QR Verification Success - Order: {order_id}, User: {user_name}, Workshop: {workshop_title}")
        else:
            # Log verification failure
            error = verification_result.get("error", "unknown error")
            logging.warning(f"QR Verification Failed - Admin: {user_id}, Error: {error}")
        
        return QRVerificationResponse(**verification_result)

    except Exception as e:
        logging.error(f"Error verifying QR code: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify QR code: {str(e)}"
        )


@router.post("/mark-attendance", response_model=MarkAttendanceResponse)
async def mark_attendance(
    request: MarkAttendanceRequest,
    user_id: str = Depends(verify_admin_user)
):
    """Mark attendance for a workshop registration."""
    try:
        client = get_mongo_client()

        # Get admin user details to check studio permissions
        user = UserOperations.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Admin user not found"
            )

        admin_studios_list = user.get('admin_studios_list', [])
        if not admin_studios_list:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No studio access permissions configured"
            )

        # Find the order document
        order_collection = client["dance_app"]["orders"]
        order = order_collection.find_one({"order_id": request.order_id})

        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )

        # Check if attendance is already marked
        if order.get('attendance_marked', False):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Attendance has already been marked for this registration"
            )

        # Get workshop details to check studio permissions
        workshop_collection = client["discovery"]["workshops"]
        workshop_id = order.get('workshop_id')
        if not workshop_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workshop ID not found in order"
            )

        workshop = workshop_collection.find_one({"_id": ObjectId(workshop_id)})
        if not workshop:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workshop not found"
            )

        # Check studio permissions
        workshop_studio_id = workshop.get('studio_id')
        if not workshop_studio_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Studio ID not found in workshop"
            )

        # Check if admin has access to this studio
        has_access = False
        if "all" in admin_studios_list:
            has_access = True
        elif str(workshop_studio_id) in admin_studios_list:
            has_access = True

        if not has_access:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient studio permissions for this workshop"
            )

        # Mark attendance
        marked_at = datetime.utcnow()
        result = order_collection.update_one(
            {"order_id": request.order_id},
            {
                "$set": {
                    "attendance_marked": True,
                    "attendance_marked_at": marked_at,
                    "attendance_marked_by": user_id
                }
            }
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update attendance status"
            )

        # Log the attendance marking
        logging.info(f"Admin {user_id} marked attendance for order {request.order_id}, workshop {workshop_id}, studio {workshop_studio_id}")

        return MarkAttendanceResponse(
            success=True,
            message="Attendance marked successfully",
            order_id=request.order_id,
            marked_at=marked_at.isoformat()
        )

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error marking attendance: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to mark attendance: {str(e)}"
        ) 