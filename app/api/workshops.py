"""Workshop API routes."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
import requests

from app.database.workshops import DatabaseOperations
from app.models.workshops import (
    WorkshopListItem,
    Artist,
    Studio,
    WorkshopSession,
    CategorizedWorkshopResponse,
)
from app.middleware.version import validate_version
from utils.utils import cache_response

router = APIRouter()


@router.get("/workshops", response_model=List[WorkshopListItem])
@cache_response(expire=3600)
async def get_workshops():
    """Fetch all workshops, categorized by current week (daily) and future."""
    try:
        workshops_data = DatabaseOperations.get_all_workshops_categorized()
        if not workshops_data.this_week and not workshops_data.post_this_week:
            return CategorizedWorkshopResponse(this_week=[], post_this_week=[])
        return workshops_data
    except Exception as e:
        print(f"Error fetching all workshops: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/studios", response_model=List[Studio])
@cache_response(expire=3600)
async def get_studios():
    """Get all studios with active workshops."""
    try:
        return DatabaseOperations.get_studios()
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@router.get("/artists", response_model=List[Artist])
@cache_response(expire=3600)
async def get_artists(has_workshops: Optional[bool] = None):
    """Get all artists with active workshops."""
    try:
        return DatabaseOperations.get_artists(has_workshops=has_workshops)
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@router.get("/workshops_by_artist/{artist_id}", response_model=List[WorkshopSession])
@cache_response(expire=3600)
async def get_workshops_by_artist(
    artist_id: str,
):
    """Get workshops for a specific artist."""
    try:
        return DatabaseOperations.get_workshops_by_artist(artist_id)
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@router.get("/workshops_by_studio/{studio_id}", response_model=CategorizedWorkshopResponse)
@cache_response(expire=3600)
async def get_workshops_by_studio(
    studio_id: str,
):
    """Fetch workshops for a specific studio, categorized by current week (daily) and future."""
    try:
        workshops_data = DatabaseOperations.get_all_workshops_categorized(studio_id)
        if not workshops_data.this_week and not workshops_data.post_this_week:
            return CategorizedWorkshopResponse(this_week=[], post_this_week=[])
        return workshops_data
    except Exception as e:
        print(f"Error fetching workshops for studio {studio_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Internal server error")


# Image cache for proxy
image_cache = {}

@router.get("/proxy-image/")
async def proxy_image(url: str):
    """Proxy for fetching images to bypass CORS restrictions."""
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/91.0.4472.124 Safari/537.36"
        )
    }

    try:
        # Check if the image is already cached
        if url in image_cache:
            data = image_cache[url]
        else:
            response = requests.get(url, headers=headers, stream=True)
            response.raise_for_status()
            data = response.content
            image_cache[url] = data
        return Response(content=data, media_type="image/jpeg")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching image: {str(e)}")


@router.get("/profile-picture/{picture_id}")
async def get_profile_picture(picture_id: str):
    """Serve profile picture from MongoDB."""
    try:
        from bson import ObjectId
        from utils.utils import get_mongo_client
        
        client = get_mongo_client()
        
        # Get profile picture from MongoDB
        picture_doc = client["dance_app"]["profile_pictures"].find_one(
            {"_id": ObjectId(picture_id)}
        )
        
        if not picture_doc:
            raise HTTPException(
                status_code=404,
                detail="Profile picture not found"
            )
        
        # Return image data
        return Response(
            content=picture_doc["image_data"],
            media_type=picture_doc.get("content_type", "image/jpeg"),
            headers={
                "Cache-Control": "public, max-age=86400",  # Cache for 24 hours
                "Content-Disposition": f'inline; filename="{picture_doc.get("filename", "profile.jpg")}"'
            }
        )
        
    except Exception as e:
        print(f"Error serving profile picture: {str(e)}")
        raise HTTPException(
            status_code=404,
            detail="Profile picture not found"
        ) 