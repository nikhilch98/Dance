"""FastAPI server for the Dance Workshop application.

This module provides the REST API endpoints for managing dance workshops,
artists, and studios. It includes features for workshop discovery, artist
profiles, and studio schedules.
"""

from datetime import datetime, timedelta, time
from typing import List, Dict, Optional
from collections import defaultdict
from fastapi import FastAPI, HTTPException, Query, Response, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, HttpUrl
import requests
import uvicorn

from utils.utils import get_mongo_client, get_formatted_date, get_formatted_date_with_day, get_formatted_time, get_timestamp_epoch

# API Models
class TimeDetails(BaseModel):
    """Time details for a workshop session."""
    day: int
    month: int
    year: int
    start_time: str
    end_time: Optional[str] = None

class WorkshopDetail(BaseModel):
    """Details of a specific workshop session."""
    time_details: TimeDetails
    by: Optional[str]
    song: Optional[str]
    pricing_info: Optional[str]
    timestamp_epoch: int
    artist_id: Optional[str]
    date: Optional[str]
    time: Optional[str]

class Workshop(BaseModel):
    """Complete workshop information including all sessions."""
    uuid: str
    payment_link: HttpUrl
    studio_id: str
    updated_at: float
    workshop_details: List[WorkshopDetail]

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
    SUPPORTED_VERSIONS = ['v2']
    DEFAULT_VERSION = 'v2'
    CORS_ORIGINS = ["*"]  # Allow all origins for development

# Initialize FastAPI app
app = FastAPI(
    title="Dance Workshop API",
    description="API for managing dance workshops, artists, and studios",
    version="2.0.0"
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
            detail=f"Unsupported API version. Supported versions: {APIConfig.SUPPORTED_VERSIONS}"
        )
    return version

# Database operations
class DatabaseOperations:
    """Database operations for the application."""

    @staticmethod
    def get_workshops() -> List[Workshop]:
        """Fetch all workshops from the database.
        
        Returns:
            List of workshops with formatted details
        """
        client = get_mongo_client()
        workshops = []
        
        for workshop in list(client["discovery"]["workshops_v2"].find()):
            formatted_details = [
                {

                    # "time_details": {
                    # "day": 27,
                    # "month": 4,
                    # "year": 2025,
                    # "start_time": "03:00 PM",
                    # "end_time": "05:00 PM"
                    # },
                    # "by": "Mohit Solanki",
                    # "song": "Ranjhana",
                    # "pricing_info": "Single Class : 900/\nBoth Classes : 1500/",
                    # "timestamp_epoch": 1745769000,
                    # "artist_id": "mohitsolanki11",
                    # "date": "27th Apr (Sun)",
                    # "time": "03:00 PM - 05:00 PM"
                    **detail,
                    "time_details": detail['time_details'],
                    "by": detail.get("by", ""),
                    "song": detail.get("song", ""),
                    "pricing_info": detail.get("pricing_info", ""),
                    "timestamp_epoch": get_timestamp_epoch(detail['time_details']),
                    "artist_id": detail.get("artist_id", ""),
                    "date": get_formatted_date(detail['time_details']),
                    "time": get_formatted_time(detail['time_details']),
                }
                for detail in workshop["workshop_details"]
            ]
            
            workshops.append({
                "_id": str(workshop["_id"]),
                "uuid": workshop["uuid"],
                "payment_link": workshop["payment_link"],
                "studio_id": workshop["studio_id"],
                "updated_at": workshop["updated_at"],
                "workshop_details": formatted_details
            })
        
        workshops.sort(key=lambda x: x["workshop_details"][0]["timestamp_epoch"])
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
                "instagram_link": studio["instagram_link"]
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
        pipeline = [
            {
                "$lookup": {
                    "from": "workshops_v2",
                    "let": {"artistId": "$artist_id"},
                    "pipeline": [
                        {
                            "$match": {
                                "$expr": {
                                    "$in": ["$$artistId", "$workshop_details.artist_id"]
                                }
                            }
                        }
                    ],
                    "as": "matchingWorkshops"
                }
            },
            {
                "$match": {"matchingWorkshops": {"$ne": []}}
            },
            {
                "$project": {
                    "_id": 0,
                    "artist_id": 1,
                    "artist_name": 1,
                    "image_url": 1,
                    "instagram_link": 1
                }
            }
        ]
        print(list(client["discovery"]["artists_v2"].aggregate([{
                "$lookup": {
                    "from": "workshops_v2",
                    "let": {"artistId": "$artist_id"},
                    "pipeline": [
                        {
                            "$match": {
                                "$expr": {
                                    "$in": ["$$artistId", "$workshop_details.artist_id"]
                                }
                            }
                        }
                    ],
                    "as": "matchingWorkshops"
                }
            }])))
        return [
            {
                "id": artist["artist_id"],
                "name": artist["artist_name"],
                "image_url": artist.get("image_url"),
                "instagram_link": artist["instagram_link"]
            }
            for artist in client["discovery"]["artists_v2"].aggregate(pipeline)
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
        
        for entry in client["discovery"]["workshops_v2"].find(
            {"workshop_details.artist_id": artist_id}
        ):
            for workshop in entry["workshop_details"]:
                if workshop.get("artist_id") == artist_id:
                    workshops.append({
                        "date": get_formatted_date(workshop['time_details']),
                        "time": get_formatted_time(workshop['time_details']),
                        "song": workshop["song"],
                        "studio_id": entry["studio_id"],
                        "artist_id": workshop["artist_id"],
                        "artist": workshop["by"],
                        "payment_link": entry["payment_link"],
                        "pricing_info": workshop["pricing_info"],
                        "timestamp_epoch": get_timestamp_epoch(workshop['time_details'])
                    })
        
        return sorted(workshops, key=lambda x: x["timestamp_epoch"])

    @staticmethod
    def get_workshops_by_studio(studio_id: str) -> CategorizedWorkshopResponse:
        """Fetch workshops for a specific studio grouped by this week (daily) and post this week.
        
        Args:
            studio_id: Unique identifier for the studio
        
        Returns:
            Object containing 'this_week' (list of daily schedules) and 'post_this_week' workshops.
        """
        client = get_mongo_client()
        temp_this_week = []
        temp_post_this_week = []

        # Calculate current week boundaries (Monday to Sunday)
        today = datetime.now().date()
        start_of_week = today - timedelta(days=today.weekday())
        end_of_week = start_of_week + timedelta(days=6)
        
        for workshop in client["discovery"]["workshops_v2"].find({"studio_id": studio_id}):
            for session in workshop["workshop_details"]:
                # Prepare workshop session data (shared part)
                session_data = {
                    "date": get_formatted_date(session['time_details']),
                    "time": get_formatted_time(session['time_details']),
                    "song": session.get("song"),
                    "studio_id": studio_id,
                    "artist": session.get("by"),
                    "artist_id": session.get("artist_id"),
                    "pricing_info": session.get("pricing_info"),
                    "payment_link": workshop["payment_link"],
                    "timestamp_epoch": get_timestamp_epoch(session['time_details']),
                    "time_details": session['time_details'] # Keep original details for weekday calculation
                }

                # Categorize by week using time_details
                try:
                    session_date = datetime(
                        year=session['time_details']['year'],
                        month=session['time_details']['month'],
                        day=session['time_details']['day']
                    ).date()
                except KeyError as e:
                    print(f"Skipping session due to incomplete time_details: {e} in {session}")
                    continue 
                
                if start_of_week <= session_date <= end_of_week:
                    temp_this_week.append(session_data)
                elif session_date > end_of_week:
                    temp_post_this_week.append(session_data)
        
        # Process 'this_week' workshops into daily structure
        this_week_by_day = defaultdict(list)
        for session in temp_this_week:
            weekday = get_formatted_date_with_day(session['time_details'])[1]
            this_week_by_day[weekday].append(session)

        final_this_week = []
        days_order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        for day in days_order:
            if this_week_by_day[day]:
                try:
                    # Sort within day by timestamp_epoch for more reliable sorting
                    sorted_workshops_raw = sorted(
                        this_week_by_day[day],
                        key=lambda x: x.get('timestamp_epoch', 0)  # Default to 0 if missing
                    )
                    sorted_workshops_cleaned = [
                        {k: v for k, v in session.items() if k != 'time_details'}
                        for session in sorted_workshops_raw
                    ]
                    final_this_week.append({"day": day, "workshops": sorted_workshops_cleaned})
                except Exception as e:
                     print(f"Warning: Could not sort workshops for {day}: {e}. Appending unsorted.")
                     unsorted_cleaned = [ {k: v for k, v in session.items() if k != 'time_details'} for session in this_week_by_day[day] ]
                     final_this_week.append({"day": day, "workshops": unsorted_cleaned })

        # Sort 'post_this_week' workshops chronologically using timestamp_epoch
        try:
            print("\nAttempting to sort post_this_week...") # DEBUG
            # Sort using timestamp_epoch which is much more reliable than parsing dates
            sorted_post_this_week_raw = sorted(
                temp_post_this_week,
                key=lambda x: x.get('timestamp_epoch', 0)  # Default to 0 if missing
            )
            print("Sorting successful.") # DEBUG
            # Clean the sorted list (remove time_details if needed)
            final_post_this_week = [
                {k: v for k, v in session.items() if k != 'time_details'}
                for session in sorted_post_this_week_raw
            ]
        except Exception as e: # Catch potential errors during sorting
            print(f"\nERROR: Could not sort post_this_week workshops: {e}.") # DEBUG
            # Return unsorted but cleaned data as a fallback
            final_post_this_week = [ {k: v for k, v in session.items() if k != 'time_details'} for session in temp_post_this_week ]


        return CategorizedWorkshopResponse(
            this_week=final_this_week,
            post_this_week=final_post_this_week
        )

# Web Routes
@app.get("/")
async def home(request: Request):
    """Serve the home page."""
    return templates.TemplateResponse("website/index.html", {"request": request})

@app.get("/all_workshops")
async def all_workshops(request: Request):
    """Serve the all workshops page."""
    return templates.TemplateResponse("website/all_workshops.html", {"request": request})

@app.get("/browse_by_artists")
async def browse_by_artists(request: Request):
    """Serve the browse by artists page."""
    return templates.TemplateResponse("website/browse_by_artists.html", {"request": request})

@app.get("/browse_by_studios")
async def browse_by_studios(request: Request):
    """Serve the browse by studios page."""
    return templates.TemplateResponse("website/browse_by_studios.html", {"request": request})

# API Routes
@app.get("/api/workshops", response_model=List[Workshop])
async def get_workshops(version: str = Depends(validate_version)):
    """Get all workshops.
    
    Args:
        version: API version
    
    Returns:
        List of all workshops
    """
    try:
        return DatabaseOperations.get_workshops()
    except Exception as e:
        # Return empty list if database is not available
        print(f"Database error: {str(e)}")
        return []

@app.get("/api/studios", response_model=List[Studio])
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
async def get_workshops_by_artist(
    artist_id: str,
    version: str = Depends(validate_version)
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

@app.get("/api/workshops_by_studio/{studio_id}", response_model=CategorizedWorkshopResponse)
async def get_workshops_by_studio(
    studio_id: str,
    version: str = Depends(validate_version)
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
        raise HTTPException(
            status_code=500,
            detail=f"Error fetching image: {str(e)}"
        )

if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8002,
        reload=True,
        workers=4
    )
