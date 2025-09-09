"""Workshop API routes."""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import Response
import requests
import gzip
import io
from datetime import datetime, timedelta

from app.database.workshops import DatabaseOperations
from app.database.images import ImageDatabase
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


@router.get("/workshops", response_model=CategorizedWorkshopResponse)
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


@router.get("/studio/{studio_id}", response_model=Studio)
@cache_response(expire=3600) 
async def get_studio_by_id(studio_id: str):
    """Get a specific studio by ID."""
    try:
        studios = DatabaseOperations.get_studios()
        for studio in studios:
            if studio.get('id') == studio_id:
                return studio
        raise HTTPException(status_code=404, detail="Studio not found")
    except HTTPException:
        raise
    except Exception as e:
        print(f"Database error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


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

# Centralized image cache with expiration (60 minutes)
centralized_image_cache = {}
CACHE_EXPIRATION_MINUTES = 60

@router.get("/proxy-image/")
async def proxy_image(url: str, request: Request):
    """Proxy for fetching images to bypass CORS restrictions with gzip compression."""
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/91.0.4472.124 Safari/537.36"
        )
    }

    try:
        # Check if client supports gzip compression
        accept_encoding = request.headers.get("accept-encoding", "").lower()
        supports_gzip = "gzip" in accept_encoding
        
        # Create cache key with compression info
        cache_key = f"{url}:gzip={supports_gzip}"
        
        # Check if the image is already cached
        if cache_key in image_cache:
            cached_data = image_cache[cache_key]
            response_headers = {"Cache-Control": "public, max-age=3600"}
            if cached_data.get("is_compressed"):
                response_headers["Content-Encoding"] = "gzip"
            
            return Response(
                content=cached_data["data"], 
                media_type="image/jpeg",
                headers=response_headers
            )
        else:
            response = requests.get(url, headers=headers, stream=True)
            response.raise_for_status()
            data = response.content
            
            # Prepare response data and headers
            response_data = data
            response_headers = {"Cache-Control": "public, max-age=3600"}
            is_compressed = False
            
            # Apply gzip compression if supported and beneficial
            if supports_gzip and len(data) > 1024:  # Only compress if > 1KB
                try:
                    # Compress the image data
                    buffer = io.BytesIO()
                    with gzip.GzipFile(fileobj=buffer, mode='wb') as f:
                        f.write(data)
                    
                    compressed_data = buffer.getvalue()
                    
                    # Only use compressed data if it's actually smaller
                    if len(compressed_data) < len(data):
                        response_data = compressed_data
                        response_headers["Content-Encoding"] = "gzip"
                        is_compressed = True
                        
                except Exception as e:
                    # If compression fails, use original data
                    print(f"Gzip compression failed for proxy image {url}: {str(e)}")
            
            # Cache the processed data
            image_cache[cache_key] = {
                "data": response_data,
                "is_compressed": is_compressed
            }
            
            return Response(
                content=response_data, 
                media_type="image/jpeg",
                headers=response_headers
            )
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching image: {str(e)}")


@router.get("/image/{image_type}/{entity_id}")
async def get_centralized_image(image_type: str, entity_id: str, request: Request):
    """
    Get image from centralized image storage with caching and gzip compression.
    
    Args:
        image_type: Type of entity (studio, artist, user)
        entity_id: ID of the entity
        request: FastAPI request object to check Accept-Encoding
    """
    # Validate image type
    valid_types = ["studio", "artist", "user"]
    if image_type not in valid_types:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid image type. Must be one of: {', '.join(valid_types)}"
        )
    
    # Create cache key
    cache_key = f"{image_type}:{entity_id}"
    
    # Check if client supports gzip compression
    accept_encoding = request.headers.get("accept-encoding", "").lower()
    supports_gzip = "gzip" in accept_encoding
    
    # Create cache key with compression info
    cache_key_with_compression = f"{cache_key}:gzip={supports_gzip}"
    
    # Check cache first
    if cache_key_with_compression in centralized_image_cache:
        cached_data = centralized_image_cache[cache_key_with_compression]
        
        # Check if cache is still valid (60 minutes)
        if datetime.utcnow() < cached_data["expires_at"]:
            headers = {"Cache-Control": "public, max-age=3600"}
            if cached_data.get("is_compressed"):
                headers["Content-Encoding"] = "gzip"
            
            return Response(
                content=cached_data["data"],
                media_type=cached_data["content_type"],
                headers=headers
            )
        else:
            # Remove expired cache entry
            del centralized_image_cache[cache_key_with_compression]
    
    # Get image from database
    image_data = ImageDatabase.get_image(image_type, entity_id)
    
    if not image_data:
        raise HTTPException(status_code=404, detail="Image not found")
    
    # Prepare response data and headers
    response_data = image_data["data"]
    response_headers = {"Cache-Control": "public, max-age=3600"}
    is_compressed = False
    
    # Apply gzip compression if supported and beneficial
    if supports_gzip and len(image_data["data"]) > 1024:  # Only compress if > 1KB
        try:
            # Compress the image data
            buffer = io.BytesIO()
            with gzip.GzipFile(fileobj=buffer, mode='wb') as f:
                f.write(image_data["data"])
            
            compressed_data = buffer.getvalue()
            
            # Only use compressed data if it's actually smaller
            if len(compressed_data) < len(image_data["data"]):
                response_data = compressed_data
                response_headers["Content-Encoding"] = "gzip"
                is_compressed = True
                
        except Exception as e:
            # If compression fails, use original data
            print(f"Gzip compression failed for {cache_key}: {str(e)}")
    
    # Cache the processed data with expiration
    centralized_image_cache[cache_key_with_compression] = {
        "data": response_data,
        "content_type": image_data["content_type"],
        "is_compressed": is_compressed,
        "expires_at": datetime.utcnow() + timedelta(minutes=CACHE_EXPIRATION_MINUTES)
    }
    
    return Response(
        content=response_data,
        media_type=image_data["content_type"],
        headers=response_headers
    )


@router.get("/profile-picture/{user_id}")
async def get_profile_picture(user_id: str):
    """
    Serve profile picture from MongoDB.
    
    This endpoint maintains backward compatibility while using the new centralized image system.
    It first tries the new centralized collection, then falls back to the old collection.
    """
    try:
        # First try the new centralized image system
        image_data = ImageDatabase.get_image("user", user_id)
        
        if image_data:
            return Response(
                content=image_data["data"],
                media_type=image_data["content_type"],
                headers={
                    "Cache-Control": "public, max-age=3600",  # Cache for 1 hour
                }
            )
        
        # Fallback to old profile_pictures collection for backward compatibility
        from bson import ObjectId
        from utils.utils import get_mongo_client
        
        client = get_mongo_client()
        
        # Get profile picture from old collection
        picture_doc = client["dance_app"]["profile_pictures"].find_one(
            {"user_id": user_id}
        )
        
        if not picture_doc:
            raise HTTPException(
                status_code=404,
                detail="Profile picture not found"
            )
        
        # Optionally migrate to new system on access (background migration)
        try:
            ImageDatabase.store_image(
                data=picture_doc["image_data"],
                image_type="user",
                entity_id=user_id,
                content_type=picture_doc.get("content_type", "image/jpeg")
            )
            print(f"Auto-migrated profile picture for user {user_id}")
        except Exception as e:
            print(f"Auto-migration failed for user {user_id}: {str(e)}")
        
        # Return image data from old collection
        return Response(
            content=picture_doc["image_data"],
            media_type=picture_doc.get("content_type", "image/jpeg"),
            headers={
                "Cache-Control": "public, max-age=3600",  # Cache for 1 hour
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error retrieving profile picture: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error") 