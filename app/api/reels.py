"""
Reels API routes for video streaming and metadata.

This module provides endpoints for:
- Listing available reels with video data
- Streaming videos from GridFS with range request support
- Video metadata retrieval
- Admin endpoints for triggering video processing
"""
from fastapi import APIRouter, Depends, HTTPException, Header, Query, status
from fastapi.responses import StreamingResponse, Response
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from bson import ObjectId

from app.services.auth import verify_admin_user, get_optional_user
from app.services.gridfs_service import GridFSService
from app.services.video_downloader import VideoDownloaderService
from app.database.choreo_links import ChoreoLinksOperations
from utils.utils import get_mongo_client


router = APIRouter()


# Response models
class ReelVideoResponse(BaseModel):
    """Response model for a reel video."""
    id: str  # choreo_link ID
    instagram_url: Optional[str] = None
    song: Optional[str] = None
    artist_id_list: Optional[List[str]] = None
    artist_name: Optional[str] = None
    studio_id: Optional[str] = None
    studio_name: Optional[str] = None
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
    active_workshops_with_links: Optional[int] = None  # Only present when active_only=True


class ProcessingResultResponse(BaseModel):
    """Response model for processing results."""
    processed: int
    succeeded: int
    failed: int


# Helper functions
def _enrich_choreo_link(doc: Dict[str, Any], base_url: str = "https://nachna.com") -> ReelVideoResponse:
    """Enrich a choreo_link document with computed fields."""
    choreo_link_id = str(doc.get("_id", doc.get("id", "")))
    gridfs_file_id = doc.get("gridfs_file_id")
    video_status = doc.get("video_status")
    has_video = video_status == "completed" and gridfs_file_id is not None
    
    # Get artist names from artist_id_list
    artist_name = None
    artist_id_list = doc.get("artist_id_list", [])
    if artist_id_list:
        try:
            client = get_mongo_client()
            artists_collection = client["discovery"]["artists_v2"]
            artists = list(artists_collection.find(
                {"artist_id": {"$in": artist_id_list}},
                {"artist_name": 1}
            ))
            artist_names = [a.get("artist_name") for a in artists if a.get("artist_name")]
            artist_name = ", ".join(artist_names) if artist_names else None
        except Exception:
            pass
    
    return ReelVideoResponse(
        id=choreo_link_id,
        instagram_url=doc.get("choreo_insta_link"),
        song=doc.get("song"),
        artist_id_list=artist_id_list,
        artist_name=artist_name,
        studio_id=doc.get("studio_id"),
        studio_name=doc.get("studio_name"),
        video_status=video_status,
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
    include_pending: bool = Query(default=False, description="Include videos that are pending/processing"),
    video_only: bool = Query(default=True, description="Only return reels with completed videos"),
    active_only: bool = Query(default=True, description="Only return reels from active (non-archived) workshops")
):
    """
    List available reels with video metadata.
    
    By default, only returns reels from active (non-archived) workshops with completed video processing.
    Set video_only=false to include all reels with Instagram links.
    Set include_pending=true to also show videos being processed.
    Set active_only=false to include reels from archived workshops (admin use).
    """
    if video_only and not include_pending:
        # Only completed videos
        docs = ChoreoLinksOperations.get_with_videos(limit=limit + 1, offset=offset, active_only=active_only)
    else:
        # All reels with Instagram links
        docs = ChoreoLinksOperations.get_with_videos(
            limit=limit + 1, 
            offset=offset, 
            include_pending=include_pending or not video_only,
            active_only=active_only
        )
    
    has_more = len(docs) > limit
    docs = docs[:limit]
    
    # Count total (for active workshops only)
    counts = ChoreoLinksOperations.count_by_status(active_only=active_only)
    total = counts["completed"] if video_only else counts["total"]
    
    reels = [_enrich_choreo_link(doc) for doc in docs]
    
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
    
    Supports seeking in video players by handling Range requests.
    Returns appropriate Content-Range headers for partial content.
    """
    # Get the choreo_link document
    doc = ChoreoLinksOperations.get_by_id(choreo_link_id)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reel not found"
        )
    
    gridfs_file_id = doc.get("gridfs_file_id")
    if not gridfs_file_id or doc.get("video_status") != "completed":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not available for this reel"
        )
    
    # Get file metadata
    metadata = GridFSService.get_video_metadata(gridfs_file_id)
    if not metadata:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video file not found in storage"
        )
    
    file_size = metadata["length"]
    content_type = metadata.get("content_type", "video/mp4")
    
    # Parse Range header
    start = 0
    end = file_size - 1
    
    if range:
        # Parse range header: "bytes=start-end"
        try:
            range_spec = range.replace("bytes=", "")
            if "-" in range_spec:
                parts = range_spec.split("-")
                if parts[0]:
                    start = int(parts[0])
                if parts[1]:
                    end = int(parts[1])
                else:
                    # If no end specified, stream to end
                    end = file_size - 1
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
                detail="Invalid range header"
            )
    
    # Validate range
    if start >= file_size or end >= file_size or start > end:
        raise HTTPException(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            detail=f"Range not satisfiable. File size: {file_size}"
        )
    
    content_length = end - start + 1
    
    # Stream the video
    def generate():
        try:
            for chunk in GridFSService.stream_video(gridfs_file_id, start=start, end=end):
                yield chunk
        except Exception as e:
            print(f"Error streaming video: {e}")
            raise
    
    # Return appropriate response based on whether range was requested
    if range:
        return StreamingResponse(
            generate(),
            status_code=status.HTTP_206_PARTIAL_CONTENT,
            media_type=content_type,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(content_length),
                "Cache-Control": "public, max-age=86400",  # Cache for 24 hours
            }
        )
    else:
        return StreamingResponse(
            generate(),
            media_type=content_type,
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Cache-Control": "public, max-age=86400",
            }
        )


@router.get("/video/{choreo_link_id}/metadata")
async def get_video_metadata(choreo_link_id: str):
    """Get metadata for a specific video."""
    doc = ChoreoLinksOperations.get_by_id(choreo_link_id)
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reel not found"
        )
    
    return _enrich_choreo_link(doc)


@router.get("/status", response_model=VideoStatusResponse)
async def get_video_status(
    active_only: bool = Query(default=True, description="Only count reels from active (non-archived) workshops")
):
    """
    Get video processing status counts.
    
    By default, only counts reels from active (non-archived) workshops.
    Set active_only=false to include reels from archived workshops.
    """
    counts = ChoreoLinksOperations.count_by_status(active_only=active_only)
    return VideoStatusResponse(**counts)


# Admin endpoints
@router.post("/process/{choreo_link_id}", response_model=dict)
async def process_single_video(
    choreo_link_id: str,
    user_id: str = Depends(verify_admin_user)
):
    """
    Trigger video processing for a single choreo_link.
    Admin only.
    """
    # Get the choreo_link document
    collection = ChoreoLinksOperations.get_collection()
    try:
        oid = ObjectId(choreo_link_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid choreo_link_id format"
        )
    
    doc = collection.find_one({"_id": oid})
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reel not found"
        )
    
    if not doc.get("choreo_insta_link"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No Instagram URL for this reel"
        )
    
    # Process the video
    downloader = VideoDownloaderService()
    success = downloader.process_choreo_link(doc)
    
    # Get updated document
    updated_doc = ChoreoLinksOperations.get_by_id(choreo_link_id)
    
    return {
        "success": success,
        "choreo_link_id": choreo_link_id,
        "video_status": updated_doc.get("video_status") if updated_doc else None,
        "error": updated_doc.get("video_error") if updated_doc else None
    }


@router.post("/process-batch", response_model=ProcessingResultResponse)
async def process_batch(
    batch_size: int = Query(default=10, ge=1, le=50),
    include_retries: bool = Query(default=False),
    user_id: str = Depends(verify_admin_user)
):
    """
    Trigger batch video processing.
    Admin only.
    
    This is a synchronous endpoint and may take a while to complete.
    For production use, prefer the background cron job.
    """
    downloader = VideoDownloaderService()
    results = downloader.process_batch(
        batch_size=batch_size,
        include_retries=include_retries
    )
    
    return ProcessingResultResponse(**results)


@router.post("/reset/{choreo_link_id}")
async def reset_video_status(
    choreo_link_id: str,
    user_id: str = Depends(verify_admin_user)
):
    """
    Reset video status to allow reprocessing.
    Admin only.
    """
    success = ChoreoLinksOperations.reset_video_status(choreo_link_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reel not found or could not be reset"
        )
    
    return {
        "success": True,
        "choreo_link_id": choreo_link_id,
        "message": "Video status reset to pending"
    }
