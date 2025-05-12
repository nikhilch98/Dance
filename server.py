"""FastAPI server for the Dance Workshop application.

This module provides the REST API endpoints for managing dance workshops,
artists, and studios. It includes features for workshop discovery, artist
profiles, and studio schedules.
"""

import asyncio
from datetime import datetime, timedelta, time
from typing import List, Dict, Optional
from collections import defaultdict
from bson import ObjectId
from fastapi import (
    FastAPI,
    HTTPException,
    Query,
    Response,
    Depends,
    Request,
    Cookie,
    Form,
    Body,
    Header,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, HttpUrl
import requests
import uvicorn
import hashlib
import base64
import secrets
import os
import tempfile
from openai import OpenAI
import config
import sys
from enum import Enum

from utils.utils import (
    get_mongo_client,
    get_formatted_date,
    get_formatted_date_with_day,
    get_formatted_time,
    get_timestamp_epoch,
    get_formatted_date_without_day,
    cache_response,
    start_cache_invalidation_watcher,
    DatabaseManager,
)


# API Models
class TimeDetails(BaseModel):
    """Time details for a workshop session."""

    day: int
    month: int
    year: int
    start_time: str
    end_time: Optional[str] = None

class WorkshopListItem(BaseModel):
    """Complete workshop information including all sessions."""

    uuid: str
    payment_link: HttpUrl
    studio_id: str
    studio_name: str
    updated_at: float
    by: Optional[str]
    song: Optional[str]
    pricing_info: Optional[str]
    timestamp_epoch: int
    artist_id: Optional[str]
    date: Optional[str]
    time: Optional[str]


class Artist(BaseModel):
    """Artist profile information."""

    id: str
    name: str
    image_url: Optional[HttpUrl]
    instagram_link: HttpUrl


class Studio(BaseModel):
    """Studio profile information."""

    id: str
    name: str
    image_url: Optional[HttpUrl]
    instagram_link: HttpUrl


class WorkshopSession(BaseModel):
    """Individual workshop session information."""

    date: str
    time: str
    song: Optional[str]
    studio_id: Optional[str]
    artist: Optional[str]
    artist_id: Optional[str]
    payment_link: HttpUrl
    pricing_info: Optional[str]
    timestamp_epoch: int


class DaySchedule(BaseModel):
    """Schedule of workshops for a specific day."""

    day: str
    workshops: List[WorkshopSession]


class CategorizedWorkshopResponse(BaseModel):
    """Response structure for workshops categorized by week."""

    this_week: List[DaySchedule]
    post_this_week: List[WorkshopSession]


# API Configuration
class APIConfig:
    """API configuration and version management."""

    SUPPORTED_VERSIONS = ["v2"]
    DEFAULT_VERSION = "v2"
    CORS_ORIGINS = ["*"]  # Allow all origins for development


# Initialize FastAPI app
app = FastAPI(
    title="Dance Workshop API",
    description="API for managing dance workshops, artists, and studios",
    version="2.0.0",
)

# Mount static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Security middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=APIConfig.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)


class EventDetails(BaseModel):
    mongo_id: str
    payment_link: str
    studio_id: str
    uuid_group: str
    uuid: str
    event_type: str
    artist_name: Optional[str]
    artist_id: Optional[str]
    song: Optional[str]
    pricing_info: str
    updated_at: float
    date_without_day: str
    date_with_day: str
    time_str: str
    timestamp_epoch: int
    time_year: Optional[int]
    time_month: Optional[int]
    time_day: Optional[int]
    time_day_full_string: Optional[str]

def format_workshop_data(workshop: dict) -> List[EventDetails]:
    """Process workshop data from the database."""
    event_details = []
    for time_details in workshop["time_details"]:
        if workshop["event_type"] not in ["workshop", "intensive"]:
            continue
        event_details.append(EventDetails(
            mongo_id=str(workshop["_id"]),
            payment_link=workshop["payment_link"],
            studio_id=workshop["studio_id"],
            uuid_group=workshop["uuid_group"],
            uuid=workshop["uuid"],
            event_type=workshop["event_type"],
            artist_name=workshop["by"],
            artist_id=workshop["artist_id"],
            song=workshop["song"],
            pricing_info=workshop["pricing_info"],
            updated_at=workshop["updated_at"],
            date_without_day=get_formatted_date_without_day(time_details),
            date_with_day=get_formatted_date_with_day(time_details)[0],
            time_str=get_formatted_time(time_details),
            timestamp_epoch=get_timestamp_epoch(time_details),
            time_year=time_details["year"],
            time_month=time_details["month"],
            time_day=time_details["day"],
            time_day_full_string=get_formatted_date_with_day(time_details)[1]
        ))
    return event_details

# Add startup event to initialize database connection pool and start cache invalidation
@app.on_event("startup")
async def startup_db_client():
    """Initialize database connection pool and start cache watcher on startup."""
    # Initialize database connection pool with a test query
    client = DatabaseManager.get_mongo_client()
    client.admin.command("ping")
    print("MongoDB connection pool initialized")

    # Start the cache invalidation watcher
    start_cache_invalidation_watcher()
    print("Cache invalidation watcher started")


# Dependency for version validation
def validate_version(version: str = Query(APIConfig.DEFAULT_VERSION)) -> str:
    """Validate API version parameter.

    Args:
        version: API version string

    Returns:
        Validated version string

    Raises:
        HTTPException: If version is not supported
    """
    if version not in APIConfig.SUPPORTED_VERSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported API version. Supported versions: {APIConfig.SUPPORTED_VERSIONS}",
        )
    return version


# Database operations
class DatabaseOperations:
    """Database operations for the application."""

    @staticmethod
    def get_workshops(studio_id: Optional[str] = None, event_type_blacklist: Optional[List[str]] = ["regulars"], sort_by_timestamp: bool = True, song_whitelist: Optional[List[str]] = [], artist_id_whitelist: Optional[List[str]] = []) -> List[EventDetails]:
        """Fetch all workshops from the database.

        Returns:
            List of workshops with formatted details
        """
        client = get_mongo_client()
        filter = {}
        if studio_id:
            filter["studio_id"] = studio_id
        if event_type_blacklist:
            filter["event_type"] = {"$nin": event_type_blacklist}
        if song_whitelist:
            filter["song"] = {"$in": song_whitelist}
        if artist_id_whitelist:
            filter["artist_id"] = {"$in": artist_id_whitelist}

        # Build a mapping from studio_id to studio_name
        workshops_cursor: List[EventDetails] = []
        for workshop in list(client["discovery"]["workshops_v2"].find(filter)):
            workshops_cursor += format_workshop_data(workshop)
        if sort_by_timestamp:
            workshops_cursor.sort(key=lambda x: x.timestamp_epoch)
        return workshops_cursor

    def get_all_workshops() -> List[WorkshopListItem]:
        """Fetch all workshops from the database."""
        client = get_mongo_client()
        studios = list(client["discovery"]["studios"].find({}))
        studios_map = {studio["studio_id"]: studio["studio_name"] for studio in studios}
        workshops =  [
            WorkshopListItem(
            uuid=workshop.uuid,
            payment_link=workshop.payment_link,
            studio_id=workshop.studio_id,
            studio_name=studios_map[workshop.studio_id],
            updated_at=workshop.updated_at,
            by=workshop.artist_name,
            song=workshop.song,
            pricing_info=workshop.pricing_info,
            timestamp_epoch=workshop.timestamp_epoch,
            artist_id=workshop.artist_id,
            date=workshop.date_with_day,
            time=workshop.time_str,
        )
            for workshop in DatabaseOperations.get_workshops(sort_by_timestamp=True)
        ]
        print(len( DatabaseOperations.get_workshops(sort_by_timestamp=True)))
        return workshops

    @staticmethod
    def get_studios() -> List[Studio]:
        """Fetch all active studios from the database.

        Returns:
            List of studios with active workshops
        """
        client = get_mongo_client()
        return [
            {
                "id": studio["studio_id"],
                "name": studio["studio_name"],
                "image_url": studio.get("image_url"),
                "instagram_link": studio["instagram_link"],
            }
            for studio in client["discovery"]["studios"].find({})
        ]

    @staticmethod
    def get_artists() -> List[Artist]:
        """Fetch all active artists from the database.

        Returns:
            List of artists with active workshops
        """
        client = get_mongo_client()
        artists_with_workshops = set(list(client["discovery"]["workshops_v2"].distinct("artist_id")))
        all_artists = list(client["discovery"]["artists_v2"].find({}))
        
        return [
            {
                "id": artist["artist_id"],
                "name": artist["artist_name"],
                "image_url": artist.get("image_url"),
                "instagram_link": artist["instagram_link"],
            }
            for artist in all_artists if artist["artist_id"] in artists_with_workshops
        ]

    @staticmethod
    def get_workshops_by_artist(artist_id: str) -> List[WorkshopSession]:
        """Fetch workshops for a specific artist.

        Args:
            artist_id: Unique identifier for the artist

        Returns:
            List of workshop sessions sorted by timestamp
        """
        client = get_mongo_client()
        workshops = []
        workshops_cursor: List[EventDetails] = DatabaseOperations.get_workshops(artist_id_whitelist=[artist_id])
        for entry in workshops_cursor:
            workshops.append(
                WorkshopSession(
                    date=entry.date_with_day,
                    time=entry.time_str,
                    song=entry.song,
                    studio_id=entry.studio_id,
                    artist_id=entry.artist_id,
                    artist=entry.artist_name,
                    payment_link=entry.payment_link,
                    pricing_info=entry.pricing_info,
                    timestamp_epoch=entry.timestamp_epoch,
                )
            )

        return sorted(workshops, key=lambda x: x.timestamp_epoch)

    @staticmethod
    def get_workshops_by_studio(studio_id: str) -> CategorizedWorkshopResponse:
        """Fetch workshops for a specific studio grouped by this week (daily) and post this week.

        Args:
            studio_id: Unique identifier for the studio

        Returns:
            Object containing 'this_week' (list of daily schedules) and 'post_this_week' workshops.
        """
        client = get_mongo_client()
        temp_this_week: List[EventDetails] = []
        temp_post_this_week: List[EventDetails] = []

        # Calculate current week boundaries (Monday to Sunday)
        today = datetime.now().date()
        start_of_week = today - timedelta(days=today.weekday())
        end_of_week = start_of_week + timedelta(days=6)

        workshops_cursor: List[EventDetails] = DatabaseOperations.get_workshops(studio_id=studio_id)

        for workshop in workshops_cursor:
            # Categorize by week using time_details
            try:
                workshop_date = datetime(
                    year=workshop.time_year,
                    month=workshop.time_month,
                    day=workshop.time_day,
                ).date()
            except KeyError as e:
                print(
                    f"Skipping session due to incomplete time_details: {e} in {workshop}"
                )
                continue

            if start_of_week <= workshop_date <= end_of_week:
                temp_this_week.append(workshop)
            elif workshop_date > end_of_week:
                temp_post_this_week.append(workshop)

        # Process 'this_week' workshops into daily structure
        this_week_by_day: Dict[str, List[EventDetails]] = {}
        for workshop in temp_this_week:
            # TODO: What happends if the day is not in the list? when day is not present , it is None
            weekday = workshop.time_day_full_string
            if weekday not in this_week_by_day:
                this_week_by_day[weekday] = []
            this_week_by_day[weekday].append(workshop)

        final_this_week = []
        days_order = [
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
        ]
        for day in days_order:
            if not this_week_by_day.get(day,[]):
                continue
            sorted_workshops_raw = sorted(
                this_week_by_day[day],
                key=lambda x: x.timestamp_epoch, 
            )
            final_this_week.append(
                DaySchedule(
                    day=day,
                    workshops=[WorkshopSession(
                        date=x.date_with_day,
                        time=x.time_str,
                        song=x.song,
                        studio_id=x.studio_id,
                        artist=x.artist_name,
                        artist_id=x.artist_id,
                        payment_link=x.payment_link,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                    ) for x in sorted_workshops_raw]
                )
            )

        # Sort 'post_this_week' workshops chronologically using timestamp_epoch

        sorted_post_this_week = [WorkshopSession(
                        date=x.date_with_day,
                        time=x.time_str,
                        song=x.song,
                        studio_id=x.studio_id,
                        artist=x.artist_name,
                        artist_id=x.artist_id,
                        payment_link=x.payment_link,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                    ) for x in sorted(
            temp_post_this_week,
            key=lambda x: x.timestamp_epoch, 
        )]
        return CategorizedWorkshopResponse(
            this_week=final_this_week, post_this_week=sorted_post_this_week
        )


# Web Routes
@app.get("/")
async def home(request: Request):
    """Serve the home page."""
    return templates.TemplateResponse("website/index.html", {"request": request})


# API Routes
@app.get("/api/workshops", response_model=List[WorkshopListItem])
@cache_response(expire=3600)
async def get_workshops(version: str = Depends(validate_version)):
    """Get all workshops.

    Args:
        version: API version

    Returns:
        List of all workshops
    """
    try:
        return DatabaseOperations.get_all_workshops()
    except Exception as e:
        # Return empty list if database is not available
        print(f"Database error: {str(e)}")
        return []


@app.get("/api/studios", response_model=List[Studio])
@cache_response(expire=3600)
async def get_studios(version: str = Depends(validate_version)):
    """Get all studios with active workshops.

    Args:
        version: API version

    Returns:
        List of studios
    """
    try:
        return DatabaseOperations.get_studios()
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@app.get("/api/artists", response_model=List[Artist])
@cache_response(expire=3600)
async def get_artists(version: str = Depends(validate_version)):
    """Get all artists with active workshops.

    Args:
        version: API version

    Returns:
        List of artists
    """
    try:
        return DatabaseOperations.get_artists()
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@app.get("/api/workshops_by_artist/{artist_id}", response_model=List[WorkshopSession])
@cache_response(expire=3600)
async def get_workshops_by_artist(
    artist_id: str, version: str = Depends(validate_version)
):
    """Get workshops for a specific artist.

    Args:
        artist_id: Artist's unique identifier
        version: API version

    Returns:
        List of workshop sessions
    """
    try:
        return DatabaseOperations.get_workshops_by_artist(artist_id)
    except Exception as e:
        print(f"Database error: {str(e)}")
        return []


@app.get(
    "/api/workshops_by_studio/{studio_id}", response_model=CategorizedWorkshopResponse
)
@cache_response(expire=3600)
async def get_workshops_by_studio(
    studio_id: str, version: str = Depends(validate_version)
):
    """Fetch workshops for a specific studio, categorized by current week (daily) and future."""
    try:
        # The method now returns the Pydantic model instance directly or raises an error
        workshops_data = DatabaseOperations.get_workshops_by_studio(studio_id)
        # The check for emptiness might need adjustment based on the new structure
        if not workshops_data.this_week and not workshops_data.post_this_week:
            # Return the categorized structure even if empty
            return CategorizedWorkshopResponse(this_week=[], post_this_week=[])
        return workshops_data
    except Exception as e:
        print(f"Error fetching workshops for studio {studio_id}: {e}")
        # Consider more specific error logging if possible
        import traceback

        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/proxy-image/")
@cache_response(expire=86400)  # Cache images for 24 hours
async def proxy_image(url: HttpUrl):
    """Proxy for fetching images to bypass CORS restrictions.

    Args:
        url: Image URL to fetch

    Returns:
        Image response

    Raises:
        HTTPException: If image fetch fails
    """
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/91.0.4472.124 Safari/537.36"
        )
    }

    try:
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()
        return Response(content=response.content, media_type="image/jpeg")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error fetching image: {str(e)}")


# --- Artists CRUD ---
@app.get("/admin/api/artists")
def admin_list_artists():
    client = get_mongo_client()
    return list(client["discovery"]["artists_v2"].find({}, {"_id": 0}).sort("artist_name", 1))


# --- New Admin APIs ---
class AssignArtistPayload(BaseModel):
    artist_id: str
    artist_name: str


@app.get("/admin/api/missing_artist_sessions")
def admin_get_missing_artist_sessions():
    client = get_mongo_client()
    missing_artist_sessions = []

    # Build a mapping from studio_id to studio_name
    studio_map = {
        s["studio_id"]: s["studio_name"] for s in client["discovery"]["studios"].find()
    }
    # Find workshops that have at least one detail with a missing artist_id

    workshops = DatabaseOperations.get_workshops(event_type_blacklist=["regulars"], sort_by_timestamp=True, song_whitelist=[], artist_id_whitelist=[None, "", "TBA", "tba", "N/A", "n/a"])
    for workshop in workshops:
        session_data = {
            "workshop_uuid": workshop.mongo_id,
            "date": workshop.date_without_day,
            "time": workshop.time_str,
            "song": workshop.song,
            "studio_name": studio_map[workshop.studio_id],
            "payment_link": workshop.payment_link,
            "original_by_field": workshop.artist_name,
            "timestamp_epoch": workshop.timestamp_epoch,
            "event_type": workshop.event_type,
        }
        missing_artist_sessions.append(session_data)

    # Sort by timestamp for consistency
    missing_artist_sessions.sort(key=lambda x: x["timestamp_epoch"])
    return missing_artist_sessions


@app.put("/admin/api/workshops/{workshop_uuid}/assign_artist")
def admin_assign_artist_to_session(
    workshop_uuid: str, payload: AssignArtistPayload = Body(...)
):
    client = get_mongo_client()

    result = client["discovery"]["workshops_v2"].update_one(
        {"_id": ObjectId(workshop_uuid)},
        {
            "$set": {
                "artist_id": payload.artist_id,
                "by": payload.artist_name,
            }
        },
    )

    if result.matched_count == 0:
        raise HTTPException(
            status_code=404, detail=f"Workshop with UUID {workshop_uuid} not found."
        )
    if result.modified_count == 0:
        # This could happen if the artist_id was already set or detail_index is out of bounds (though mongo might not error)
        # For simplicity, we'll consider it a success if matched, but ideally, check if modification actually happened as expected.
        pass

    return {
        "success": True,
        "message": f"Artist {payload.artist_name} assigned to workshop {workshop_uuid}.",
    }


@app.get("/admin", response_class=HTMLResponse)
async def admin_panel(request: Request):
    return templates.TemplateResponse(
        "website/admin_missing_artists.html", {"request": request}
    )


@app.get("/admin/api/missing_song_sessions")
def admin_get_missing_song_sessions():
    client = get_mongo_client()
    missing_song_sessions = []

    # Build a mapping from studio_id to studio_name
    studio_map = {
        s["studio_id"]: s["studio_name"] for s in client["discovery"]["studios"].find()
    }

    # Find workshops that have a missing song (null, empty, or 'TBA')

    workshops = DatabaseOperations.get_workshops(event_type_blacklist=["regulars"], sort_by_timestamp=True, song_whitelist=[None, "", "TBA", "tba", "N/A", "n/a"], artist_id_whitelist=[])

    for workshop in workshops:
        session_data = {
            "workshop_uuid": workshop.mongo_id,
            "date": workshop.date_without_day,
            "time": workshop.time_str,
            "song": workshop.song,
            "studio_name": studio_map[workshop.studio_id],
            "payment_link": workshop.payment_link,
            "original_by_field": workshop.artist_name,
            "timestamp_epoch": workshop.timestamp_epoch,
        }
        missing_song_sessions.append(session_data)

    # Sort by timestamp for consistency
    missing_song_sessions.sort(key=lambda x: x["timestamp_epoch"])
    return missing_song_sessions


class AssignSongPayload(BaseModel):
    song: str


@app.put("/admin/api/workshops/{workshop_uuid}/assign_song")
def admin_assign_song_to_session(
    workshop_uuid: str, payload: AssignSongPayload = Body(...)
):
    client = get_mongo_client()

    result = client["discovery"]["workshops_v2"].update_one(
        {"_id": ObjectId(workshop_uuid)},
        {"$set": {"song": payload.song}},
    )

    if result.matched_count == 0:
        raise HTTPException(
            status_code=404, detail=f"Workshop with UUID {workshop_uuid} not found."
        )
    # Consider it a success if matched

    return {
        "success": True,
        "message": f"Song '{payload.song}' assigned to workshop {workshop_uuid}.",
    }


# Add shutdown event handler to close database connections
@app.on_event("shutdown")
async def shutdown_db_client():
    """Close database connections when the application shuts down."""
    DatabaseManager.close_connections()
    print("Application shutdown: Database connections closed.")


# Define request model for the analysis endpoint
class AnalyzeRequest(BaseModel):
    link: HttpUrl
    ai_model: str # 'openai' or 'gemini'


# --- New AI Analyzer Web Route ---
@app.get("/ai", response_class=HTMLResponse)
async def ai_analyzer_page(request: Request):
    """Serve the AI analyzer page."""
    return templates.TemplateResponse("website/ai_analyzer.html", {"request": request})

# --- New AI Analyzer API Route ---
@app.post("/ai/analyze")
async def analyze_event_link(payload: AnalyzeRequest):
    """Takes a URL and AI model choice, screenshots it, and runs AI analysis."""
    # Use dev env for safety, adjust if needed. Use model from payload.
    # Ensure ai_model is valid before creating config
    if payload.ai_model not in ['openai', 'gemini']:
         raise HTTPException(status_code=400, detail="Invalid AI model specified in request.")
    cfg = config.Config(env="dev", ai_model=payload.ai_model)

    artists_data = get_artists_data_script(cfg) # Fetch latest artists data

    # Initialize the correct AI client based on selection
    try:
        if payload.ai_model == "openai":
            if not cfg.openai_api_key:
                 raise HTTPException(status_code=500, detail="OpenAI API key not configured.")
            ai_client = OpenAI(api_key=cfg.openai_api_key)
            # Use the specific model from config if available, else default
            model_version = getattr(cfg, 'openai_model_version', "gpt-4o-2024-11-20")
        elif payload.ai_model == "gemini":
            if not cfg.gemini_api_key:
                raise HTTPException(status_code=500, detail="Gemini API key not configured.")
            # Note: The Gemini client setup might differ based on your specific library usage
            # Assuming OpenAI library compatibility or adjust as needed
            ai_client = OpenAI(api_key=cfg.gemini_api_key, base_url=cfg.gemini_base_url)
            model_version = getattr(cfg, 'gemini_model_version', "gemini-2.5-flash-preview-04-17")
        # No else needed due to check above
    except Exception as e:
         # Catch potential errors during client initialization (e.g., invalid key format)
         print(f"Error initializing AI client: {e}")
         raise HTTPException(status_code=500, detail=f"Failed to initialize AI client: {e}")

    # Get mongo client safely
    mongo_client = None
    try:
        # Use the same environment as Config for consistency
        mongo_client = DatabaseManager.get_mongo_client(cfg.env)
        mongo_client.admin.command("ping") # Verify connection
    except Exception as e:
        print(f"Warning: Failed to get MongoDB client for /ai/analyze: {e}. Proceeding without DB context for EventProcessor.")
        # EventProcessor might not strictly need mongo_client for _analyze_with_ai

    # Initialize EventProcessor
    try:
        processor = EventProcessor(client=ai_client, artists=artists_data, mongo_client=mongo_client, cfg=cfg)
    except Exception as e:
         print(f"Error initializing EventProcessor: {e}")
         raise HTTPException(status_code=500, detail=f"Failed to initialize EventProcessor: {e}")

    # Create a temporary file for the screenshot
    screenshot_file = None
    try:
        # Use mkstemp for potentially safer temp file creation
        fd, screenshot_path = tempfile.mkstemp(suffix=".png", prefix="analyze_")
        os.close(fd) # Close the file descriptor immediately
        screenshot_file = screenshot_path # Keep track for cleanup

        print(f"Attempting screenshot for {payload.link} to {screenshot_path}")
        # Capture screenshot
        if not ScreenshotManager.capture_screenshot(str(payload.link), screenshot_path):
            # Add more detail to screenshot failure
            print(f"Screenshot capture failed for URL: {payload.link}")
            raise HTTPException(status_code=500, detail=f"Failed to capture screenshot for the provided link. Check if the URL is accessible and valid.")

        print(f"Screenshot captured. Analyzing with {payload.ai_model} model: {model_version}...")
        # Analyze screenshot
        # Use the internal _analyze_with_ai method which takes model_version
        analysis_result: Optional[EventSummary] = await asyncio.to_thread(
            processor._analyze_with_ai,
            screenshot_path, artists_data, model_version
        )
        # analysis_result: Optional[EventSummary] = processor._analyze_with_ai(
        #      screenshot_path, artists_data, model_version
        # )

        if analysis_result is None:
             print(f"AI analysis returned None for {payload.link}")
             raise HTTPException(status_code=500, detail="AI analysis failed or returned no result.")

        print("Analysis complete.")
        # Return the Pydantic model, FastAPI handles JSON conversion
        return analysis_result

    except HTTPException as http_exc:
        # Re-raise HTTP exceptions directly
        print(f"HTTPException during analysis: {http_exc.detail}")
        raise http_exc
    except Exception as e:
        print(f"Error during analysis for {payload.link}: {e}")
        import traceback
        traceback.print_exc()
        # Provide a more generic error message to the client
        raise HTTPException(status_code=500, detail="An unexpected error occurred during analysis.")
    finally:
        # Clean up the temporary screenshot file
        if screenshot_file and os.path.exists(screenshot_file):
            try:
                os.remove(screenshot_file)
                print(f"Cleaned up screenshot: {screenshot_file}")
            except Exception as e:
                # Log cleanup error but don't prevent response
                print(f"Error cleaning up screenshot {screenshot_file}: {e}")


if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8002,
        workers=4,  # Number of worker processes
        loop="uvloop",  # Use uvloop for better performance
        http="httptools",  # Use httptools for better performance
        reload=True,  # Enable auto-reload during development
        access_log=True,
        log_level="info",
        proxy_headers=True,
        forwarded_allow_ips="*",
    )
