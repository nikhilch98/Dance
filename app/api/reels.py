"""
Reels API routes for video streaming and metadata.

This module provides endpoints for:
- Listing available reels with video data (matching All Workshops filtering)
- Streaming videos from GridFS with range request support
- Video metadata retrieval
- Admin endpoints for triggering video processing
"""
from fastapi import APIRouter, Depends, HTTPException, Header, Query, status
from fastapi.responses import StreamingResponse, Response
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from bson import ObjectId

from app.services.auth import verify_admin_user
from app.services.gridfs_service import GridFSService
from app.services.video_downloader import VideoDownloaderService
from app.database.choreo_links import ChoreoLinksOperations
from utils.utils import get_mongo_client


router = APIRouter()


# Response models
class ReelVideoResponse(BaseModel):
    """Response model for a reel video."""
    id: str  # choreo_link ID
    workshop_uuid: str
    instagram_url: Optional[str] = None
    song: Optional[str] = None
    artist_id_list: Optional[List[str]] = None
    artist_name: Optional[str] = None
    artist_image_urls: Optional[List[str]] = None
    studio_id: Optional[str] = None
    studio_name: Optional[str] = None
    date: Optional[str] = None
    time: Optional[str] = None
    timestamp_epoch: int = 0
    payment_link: Optional[str] = None
    payment_link_type: Optional[str] = None
    pricing_info: Optional[str] = None
    current_price: Optional[float] = None
    video_status: Optional[str] = None
    gridfs_file_id: Optional[str] = None
    video_file_size: Optional[int] = None
    video_url: Optional[str] = None
    has_video: bool = False


class ReelsListResponse(BaseModel):
    """Response model for listing reels."""
    reels: List[ReelVideoResponse]
    total: int
    has_more: bool


class VideoStatusResponse(BaseModel):
    """Response model for video processing status."""
    unprocessed: int
    pending: int
    processing: int
    completed: int
    failed: int
    total: int
    active_workshops_with_links: int = 0


class ProcessingResultResponse(BaseModel):
    """Response model for processing results."""
    processed: int
    succeeded: int
    failed: int


def _get_available_workshops_with_reels(video_only: bool = True) -> List[Dict[str, Any]]:
    """
    Get workshops that would appear in "All Workshops" section and have choreo_insta_link.
    Uses the same filtering logic as the All Workshops API.
    
    Args:
        video_only: Only return workshops with completed videos
        
    Returns:
        List of workshop documents with video status enriched
    """
    client = get_mongo_client()
    
    # Get workshops with same filter as All Workshops
    workshop_filter = {
        "is_archived": {"$ne": True},
        "event_type": {"$nin": ["regulars"]},
        "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
    }
    
    workshops = list(client["discovery"]["workshops_v2"].find(workshop_filter))
    
    # Calculate date boundaries (same as All Workshops)
    today = datetime.now().date()
    start_of_week = today - timedelta(days=today.weekday())
    
    # Get artists map for enrichment
    artists = list(client["discovery"]["artists_v2"].find({}))
    artists_map = {artist["artist_id"]: artist for artist in artists}
    
    # Get studios map
    studios = list(client["discovery"]["studios"].find({}))
    studios_map = {studio["studio_id"]: studio["studio_name"] for studio in studios}
    
    # Get choreo_links for video status
    choreo_links = list(client["discovery"]["choreo_links"].find({
        "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
    }))
    choreo_links_map = {cl["choreo_insta_link"]: cl for cl in choreo_links}
    
    available_reels = []
    
    for workshop in workshops:
        # Process each time_detail (workshop can have multiple dates)
        time_details = workshop.get("time_details", [])
        
        for td in time_details:
            try:
                workshop_date = datetime(
                    year=td.get("year"),
                    month=td.get("month"),
                    day=td.get("day"),
                ).date()
            except (TypeError, ValueError):
                continue
            
            # Only include workshops from start of current week onwards (same as All Workshops)
            if workshop_date < start_of_week:
                continue
            
            # Get video status from choreo_links
            choreo_insta_link = workshop.get("choreo_insta_link")
            choreo_link_doc = choreo_links_map.get(choreo_insta_link, {})
            video_status = choreo_link_doc.get("video_status")
            gridfs_file_id = choreo_link_doc.get("gridfs_file_id")
            has_video = video_status == "completed" and gridfs_file_id is not None
            
            # If video_only, skip workshops without completed videos
            if video_only and not has_video:
                continue
            
            # Get artist info
            artist_id_list = workshop.get("artist_id_list", [])
            artist_names = []
            artist_image_urls = []
            for aid in artist_id_list:
                artist = artists_map.get(aid)
                if artist:
                    artist_names.append(artist.get("artist_name", ""))
                    artist_image_urls.append(artist.get("image_url"))
            
            artist_name = " X ".join(artist_names) if artist_names else workshop.get("by")
            
            # Format date/time
            from utils.utils import get_formatted_date, get_formatted_time, get_timestamp_epoch
            formatted_date = get_formatted_date(td)
            formatted_time = get_formatted_time(td)
            timestamp_epoch = get_timestamp_epoch(td)
            
            # Get studio name
            studio_name = studios_map.get(workshop.get("studio_id"), workshop.get("studio_name", ""))
            
            # Calculate current price
            pricing_info = workshop.get("pricing_info", "")
            current_price = None
            if pricing_info:
                try:
                    from app.api.orders import calculate_current_price
                    current_price = calculate_current_price(pricing_info, workshop["uuid"])
                except Exception:
                    pass
            
            available_reels.append({
                "_id": choreo_link_doc.get("_id", ObjectId()),
                "workshop_uuid": workshop["uuid"],
                "choreo_insta_link": choreo_insta_link,
                "song": workshop.get("song"),
                "artist_id_list": artist_id_list,
                "artist_name": artist_name,
                "artist_image_urls": [url for url in artist_image_urls if url],
                "studio_id": workshop.get("studio_id"),
                "studio_name": studio_name,
                "date": formatted_date,
                "time": formatted_time,
                "timestamp_epoch": timestamp_epoch,
                "payment_link": workshop.get("payment_link"),
                "payment_link_type": workshop.get("payment_link_type"),
                "pricing_info": pricing_info,
                "current_price": current_price,
                "video_status": video_status,
                "gridfs_file_id": gridfs_file_id,
                "video_file_size": choreo_link_doc.get("video_file_size"),
                "has_video": has_video
            })
    
    # Sort by timestamp (earliest first, like All Workshops)
    available_reels.sort(key=lambda x: x.get("timestamp_epoch", 0))
    
    return available_reels


def _enrich_to_response(doc: Dict[str, Any], base_url: str = "https://nachna.com") -> ReelVideoResponse:
    """Convert enriched workshop doc to ReelVideoResponse."""
    choreo_link_id = str(doc.get("_id", ""))
    gridfs_file_id = doc.get("gridfs_file_id")
    has_video = doc.get("has_video", False)
    
    return ReelVideoResponse(
        id=choreo_link_id,
        workshop_uuid=doc.get("workshop_uuid", ""),
        instagram_url=doc.get("choreo_insta_link"),
        song=doc.get("song"),
        artist_id_list=doc.get("artist_id_list"),
        artist_name=doc.get("artist_name"),
        artist_image_urls=doc.get("artist_image_urls"),
        studio_id=doc.get("studio_id"),
        studio_name=doc.get("studio_name"),
        date=doc.get("date"),
        time=doc.get("time"),
        timestamp_epoch=doc.get("timestamp_epoch", 0),
        payment_link=doc.get("payment_link"),
        payment_link_type=doc.get("payment_link_type"),
        pricing_info=doc.get("pricing_info"),
        current_price=doc.get("current_price"),
        video_status=doc.get("video_status"),
        gridfs_file_id=str(gridfs_file_id) if gridfs_file_id else None,
        video_file_size=doc.get("video_file_size"),
        video_url=f"{base_url}/api/reels/video/{choreo_link_id}" if has_video else None,
        has_video=has_video
    )


# Public endpoints
@router.get("/videos", response_model=ReelsListResponse)
async def list_reels(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    video_only: bool = Query(default=True, description="Only return reels with completed videos")
):
    """
    List available reels with video metadata.
    
    Uses the same workshop filtering as "All Workshops" section:
    - Only non-archived workshops
    - Only workshops from current week onwards
    - Only workshops with choreo_insta_link
    
    By default, only returns reels with completed video processing.
    Set video_only=false to include all reels (even without processed videos).
    """
    # Get workshops using same logic as All Workshops
    all_reels = _get_available_workshops_with_reels(video_only=video_only)
    
    # Apply pagination
    total = len(all_reels)
    paginated = all_reels[offset:offset + limit + 1]
    has_more = len(paginated) > limit
    paginated = paginated[:limit]
    
    reels = [_enrich_to_response(doc) for doc in paginated]
    
    return ReelsListResponse(
        reels=reels,
        total=total,
        has_more=has_more
    )


@router.get("/video/{choreo_link_id}")
async def stream_video(
    choreo_link_id: str,
    range: Optional[str] = Header(None, alias="Range")
):
    """
    Stream video from GridFS with HTTP Range request support.
    
    Supports partial content requests for seeking in video players.
    """
    # Get the choreo_link document
    doc = ChoreoLinksOperations.get_by_id(choreo_link_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Check if video is ready
    if doc.get("video_status") != "completed" or not doc.get("gridfs_file_id"):
        raise HTTPException(status_code=404, detail="Video not yet available")
    
    # Get the video from GridFS
    gridfs_service = GridFSService()
    try:
        file_id = ObjectId(doc["gridfs_file_id"])
        grid_out = gridfs_service.get_file(file_id)
        if not grid_out:
            raise HTTPException(status_code=404, detail="Video file not found")
    except Exception as e:
        print(f"GridFS error: {e}")
        raise HTTPException(status_code=500, detail="Error retrieving video")
    
    file_size = grid_out.length
    content_type = grid_out.content_type or "video/mp4"
    
    # Handle range requests for seeking
    if range:
        try:
            range_spec = range.replace("bytes=", "")
            parts = range_spec.split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if parts[1] else file_size - 1
            
            if start >= file_size:
                raise HTTPException(status_code=416, detail="Range not satisfiable")
            
            end = min(end, file_size - 1)
            content_length = end - start + 1
            
            grid_out.seek(start)
            
            def generate_range():
                remaining = content_length
                while remaining > 0:
                    chunk_size = min(64 * 1024, remaining)
                    chunk = grid_out.read(chunk_size)
                    if not chunk:
                        break
                    remaining -= len(chunk)
                    yield chunk
            
            return StreamingResponse(
                generate_range(),
                status_code=206,
                media_type=content_type,
                headers={
                    "Content-Range": f"bytes {start}-{end}/{file_size}",
                    "Accept-Ranges": "bytes",
                    "Content-Length": str(content_length),
                }
            )
        except ValueError:
            pass  # Fall through to full file
    
    # Full file response
    def generate_full():
        while True:
            chunk = grid_out.read(64 * 1024)
            if not chunk:
                break
            yield chunk
    
    return StreamingResponse(
        generate_full(),
        media_type=content_type,
        headers={
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size),
        }
    )


@router.get("/video/{choreo_link_id}/metadata", response_model=ReelVideoResponse)
async def get_video_metadata(choreo_link_id: str):
    """Get metadata for a specific reel video."""
    doc = ChoreoLinksOperations.get_by_id(choreo_link_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Reel not found")
    
    # Get workshop info
    client = get_mongo_client()
    workshop = client["discovery"]["workshops_v2"].find_one({
        "choreo_insta_link": doc.get("choreo_insta_link")
    })
    
    if not workshop:
        raise HTTPException(status_code=404, detail="Workshop not found for this reel")
    
    # Build response with workshop data
    gridfs_file_id = doc.get("gridfs_file_id")
    has_video = doc.get("video_status") == "completed" and gridfs_file_id is not None
    
    # Get artist info
    artists_map = {}
    artists = list(client["discovery"]["artists_v2"].find({}))
    for a in artists:
        artists_map[a["artist_id"]] = a
    
    artist_id_list = workshop.get("artist_id_list", [])
    artist_names = []
    artist_image_urls = []
    for aid in artist_id_list:
        artist = artists_map.get(aid)
        if artist:
            artist_names.append(artist.get("artist_name", ""))
            artist_image_urls.append(artist.get("image_url"))
    
    artist_name = " X ".join(artist_names) if artist_names else workshop.get("by")
    
    return ReelVideoResponse(
        id=choreo_link_id,
        workshop_uuid=workshop["uuid"],
        instagram_url=doc.get("choreo_insta_link"),
        song=workshop.get("song"),
        artist_id_list=artist_id_list,
        artist_name=artist_name,
        artist_image_urls=[url for url in artist_image_urls if url],
        studio_id=workshop.get("studio_id"),
        studio_name=workshop.get("studio_name"),
        payment_link=workshop.get("payment_link"),
        payment_link_type=workshop.get("payment_link_type"),
        pricing_info=workshop.get("pricing_info"),
        video_status=doc.get("video_status"),
        gridfs_file_id=str(gridfs_file_id) if gridfs_file_id else None,
        video_file_size=doc.get("video_file_size"),
        video_url=f"https://nachna.com/api/reels/video/{choreo_link_id}" if has_video else None,
        has_video=has_video
    )


# Admin endpoints
@router.get("/status", response_model=VideoStatusResponse)
async def get_video_status(
    user_id: str = Depends(verify_admin_user)
):
    """Get video processing status counts (admin only)."""
    counts = ChoreoLinksOperations.count_by_status(active_only=True)
    return VideoStatusResponse(**counts)


@router.post("/process", response_model=ProcessingResultResponse)
async def trigger_video_processing(
    batch_size: int = Query(default=10, ge=1, le=50),
    include_retries: bool = Query(default=False),
    user_id: str = Depends(verify_admin_user)
):
    """Trigger batch video processing (admin only)."""
    downloader = VideoDownloaderService()
    result = downloader.process_batch(batch_size=batch_size, include_retries=include_retries)
    return ProcessingResultResponse(**result)


@router.post("/reset/{choreo_link_id}")
async def reset_video_status(
    choreo_link_id: str,
    user_id: str = Depends(verify_admin_user)
):
    """Reset video processing status for reprocessing (admin only)."""
    success = ChoreoLinksOperations.reset_video_status(choreo_link_id)
    if not success:
        raise HTTPException(status_code=404, detail="Choreo link not found")
    return {"message": "Video status reset successfully"}
