"""Admin API routes."""

from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request

from app.services.auth import verify_admin_user
from app.models.admin import AssignArtistPayload, AssignSongPayload
from utils.utils import get_mongo_client

router = APIRouter()
templates = Jinja2Templates(directory="templates")


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