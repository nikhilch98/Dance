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
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, HttpUrl, Field, validator
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
import jwt
from passlib.context import CryptContext
import re
from functools import wraps
import time as time_module
import logging
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored output
init(autoreset=True)

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

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Middleware for logging response times
async def log_response_time_middleware(request: Request, call_next):
    """Middleware to log response times for each request."""
    start_time = time_module.time()
    response = await call_next(request)
    process_time = time_module.time() - start_time
    
    # Format time - convert to ms if less than 1 second
    if process_time < 1.0:
        time_str = f"{process_time * 1000:.1f}ms"
    else:
        time_str = f"{process_time:.3f}s"
    
    # Color codes based on status code
    if 200 <= response.status_code < 300:
        status_color = Fore.GREEN
    elif 300 <= response.status_code < 400:
        status_color = Fore.YELLOW
    elif 400 <= response.status_code < 500:
        status_color = Fore.RED
    else:
        status_color = Fore.MAGENTA
    
    # Format the log message with colors
    log_message = (
        f"{Fore.CYAN}INFO{Style.RESET_ALL}:server:"
        f"{request.client.host}:{request.client.port} - "
        f'"{request.method} {request.url.path}{"?" + str(request.url.query) if request.url.query else ""} '
        f'HTTP/{request.scope.get("http_version", "1.1")}" '
        f"{status_color}{response.status_code}{Style.RESET_ALL} - "
        f"| {Fore.BLUE}{time_str}{Style.RESET_ALL}"
    )
    
    print(log_message)
    
    return response

# Security configuration
SECRET_KEY = "your-secret-key-here-change-in-production"  # Change this in production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30 * 24 * 60  # 30 days
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# Authentication Models
class UserRegistration(BaseModel):
    """User registration request model."""
    mobile_number: str = Field(..., pattern=r"^\+?[1-9]\d{1,14}$")
    password: str = Field(..., min_length=6)

class UserLogin(BaseModel):
    """User login request model."""
    mobile_number: str = Field(..., pattern=r"^\+?[1-9]\d{1,14}$")
    password: str

class ProfileUpdate(BaseModel):
    """Profile update request model."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    date_of_birth: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    gender: Optional[str] = Field(None, pattern=r"^(male|female|other)$")

class PasswordUpdate(BaseModel):
    """Password update request model."""
    current_password: str
    new_password: str = Field(..., min_length=6)

class UserProfile(BaseModel):
    """User profile response model."""
    user_id: str
    mobile_number: str
    name: Optional[str]
    date_of_birth: Optional[str]
    gender: Optional[str]
    profile_complete: bool
    is_admin: Optional[bool] = False
    created_at: datetime
    updated_at: datetime

class AuthResponse(BaseModel):
    """Authentication response model."""
    access_token: str
    token_type: str
    user: UserProfile

# Password hashing utilities
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify JWT token and return user info."""
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return user_id
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Authentication decorators
def user_authentication(func):
    """Decorator to require user authentication for API endpoints."""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        # Extract user_id from kwargs if it exists (injected by Depends(verify_token))
        user_id = kwargs.get('user_id')
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )
        return await func(*args, **kwargs)
    return wrapper

def admin_authentication(func):
    """Decorator to require admin authentication for API endpoints. Must be used with @user_authentication."""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        # Extract user_id from kwargs (should be injected by @user_authentication + Depends(verify_token))
        user_id = kwargs.get('user_id')
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )
        
        # Check if user is admin
        user = UserOperations.get_user_by_id(user_id)
        if not user or not user.get('is_admin', False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin access required"
            )
        
        return await func(*args, **kwargs)
    return wrapper

# Database operations for users
class UserOperations:
    """Database operations for user management."""
    
    @staticmethod
    def create_user(mobile_number: str, password: str) -> dict:
        """Create a new user."""
        client = get_mongo_client()
        
        # Check if user already exists
        existing_user = client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this mobile number already exists"
            )
        
        # Create new user
        user_data = {
            "mobile_number": mobile_number,
            "password_hash": get_password_hash(password),
            "name": None,
            "date_of_birth": None,
            "gender": None,
            "profile_complete": False,
            "is_admin": False,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }
        
        result = client["dance_app"]["users"].insert_one(user_data)
        user_data["_id"] = result.inserted_id
        return user_data
    
    @staticmethod
    def authenticate_user(mobile_number: str, password: str) -> Optional[dict]:
        """Authenticate user credentials."""
        client = get_mongo_client()
        user = client["dance_app"]["users"].find_one({"mobile_number": mobile_number})
        
        if not user or not verify_password(password, user["password_hash"]):
            return None
        return user
    
    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[dict]:
        """Get user by ID."""
        client = get_mongo_client()
        try:
            return client["dance_app"]["users"].find_one({"_id": ObjectId(user_id)})
        except Exception:
            return None
    
    @staticmethod
    def update_user_profile(user_id: str, profile_data: dict) -> bool:
        """Update user profile."""
        client = get_mongo_client()
        
        # Check if profile is complete
        profile_complete = all([
            profile_data.get("name"),
            profile_data.get("date_of_birth"),
            profile_data.get("gender")
        ])
        
        update_data = {
            **profile_data,
            "profile_complete": profile_complete,
            "updated_at": datetime.utcnow()
        }
        
        result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": update_data}
        )
        return result.modified_count > 0
    
    @staticmethod
    def update_user_password(user_id: str, new_password: str) -> bool:
        """Update user password."""
        client = get_mongo_client()
        
        result = client["dance_app"]["users"].update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "password_hash": get_password_hash(new_password),
                "updated_at": datetime.utcnow()
            }}
        )
        return result.modified_count > 0

def format_user_profile(user_data: dict) -> UserProfile:
    """Format user data to UserProfile model."""
    return UserProfile(
        user_id=str(user_data["_id"]),
        mobile_number=user_data["mobile_number"],
        name=user_data.get("name"),
        date_of_birth=user_data.get("date_of_birth"),
        gender=user_data.get("gender"),
        profile_complete=user_data.get("profile_complete", False),
        is_admin=user_data.get("is_admin", False),
        created_at=user_data["created_at"],
        updated_at=user_data["updated_at"]
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
    artist_id_list: Optional[List[str]] = []
    artist_image_urls: Optional[List[Optional[HttpUrl]]] = []
    date: Optional[str]
    time: Optional[str]
    event_type: Optional[str]


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
    artist_id_list: Optional[List[str]] = []
    payment_link: HttpUrl
    pricing_info: Optional[str]
    timestamp_epoch: int
    event_type: Optional[str]


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

# Add response time logging middleware
app.middleware("http")(log_response_time_middleware)


class EventDetails(BaseModel):
    mongo_id: str
    payment_link: str
    studio_id: str
    uuid_group: str
    uuid: str
    event_type: str
    artist_name: Optional[str]
    artist_id_list: Optional[List[str]] = []
    song: Optional[str]
    pricing_info: Optional[str]
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
        date_without_day = get_formatted_date_without_day(time_details)
        if date_without_day is None:
            print(f"Skipping workshop {workshop['uuid']} due to missing data in time_details", time_details)
            continue
            
        # Use artist_id_list directly
        artist_id_list = workshop.get("artist_id_list", [])
        
        event_details.append(EventDetails(
            mongo_id=str(workshop["_id"]),
            payment_link=workshop["payment_link"],
            studio_id=workshop["studio_id"],
            uuid_group=workshop["uuid_group"],
            uuid=workshop["uuid"],
            event_type=workshop["event_type"],
            artist_name=workshop["by"],
            artist_id_list=artist_id_list,
            song=workshop["song"],
            pricing_info=workshop["pricing_info"],
            updated_at=workshop["updated_at"],
            date_without_day=date_without_day,
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
            # Only use artist_id_list field
            filter["artist_id_list"] = {"$in": artist_id_whitelist}

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
        
        # Build a mapping from artist_id to artist image_url
        artists = list(client["discovery"]["artists_v2"].find({}))
        artists_map = {artist["artist_id"]: artist.get("image_url") for artist in artists}
        
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
            artist_id_list=workshop.artist_id_list,
            artist_image_urls=[artists_map.get(artist_id) for artist_id in workshop.artist_id_list] if workshop.artist_id_list else [],
            date=workshop.date_with_day,
            time=workshop.time_str,
            event_type=workshop.event_type,
        )
            for workshop in DatabaseOperations.get_workshops(sort_by_timestamp=True)
        ]
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
    def get_artists(has_workshops: Optional[bool] = None) -> List[Artist]:
        """Fetch all active artists from the database.

        Returns:
            List of artists with active workshops
        """
        client = get_mongo_client()
        # Get artists that appear in artist_id_list arrays
        artists_with_workshops = set()
        for workshop in client["discovery"]["workshops_v2"].find({}, {"artist_id_list": 1}):
            artist_list = workshop.get("artist_id_list", [])
            if artist_list:
                artists_with_workshops.update(artist_list)
        
        all_artists = list(client["discovery"]["artists_v2"].find({}))
        
        return sorted([
            {
                "id": artist["artist_id"],
                "name": artist["artist_name"],
                "image_url": artist.get("image_url"),
                "instagram_link": artist["instagram_link"],
            }
            for artist in all_artists if has_workshops is None or (has_workshops and artist["artist_id"] in artists_with_workshops) or (not has_workshops and artist["artist_id"] not in artists_with_workshops)
        ], key=lambda x: x["name"])

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
        
        # Find workshops where the artist_id is in the artist_id_list
        workshops_cursor = client["discovery"]["workshops_v2"].find({
            "artist_id_list": artist_id
        })
        
        for workshop in workshops_cursor:
            for time_detail in workshop.get("time_details", []):
                if not time_detail:
                    continue
                    
                workshops.append(
                    WorkshopSession(
                        date=get_formatted_date_with_day(time_detail)[0],
                        time=get_formatted_time(time_detail),
                        song=workshop.get("song"),
                        studio_id=workshop.get("studio_id"),
                        artist_id_list=workshop.get("artist_id_list", []),
                        artist=workshop.get("by"),
                        payment_link=workshop.get("payment_link"),
                        pricing_info=workshop.get("pricing_info"),
                        timestamp_epoch=get_timestamp_epoch(time_detail),
                        event_type=workshop.get("event_type"),
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
                        artist_id_list=x.artist_id_list,
                        payment_link=x.payment_link,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                        event_type=x.event_type,
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
                        artist_id_list=x.artist_id_list,
                        payment_link=x.payment_link,
                        pricing_info=x.pricing_info,
                        timestamp_epoch=x.timestamp_epoch,
                        event_type=x.event_type,
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
async def get_artists(version: str = Depends(validate_version), has_workshops: Optional[bool] = None):
    """Get all artists with active workshops.

    Args:
        version: API version
        has_workshops: If True, only return artists with active workshops. If False, only return artists without active workshops. If None, return all artists.
    Returns:
        List of artists
    """
    try:
        return DatabaseOperations.get_artists(has_workshops=has_workshops)
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


image_cache = {}

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


# Admin dependency function
def verify_admin_user(user_id: str = Depends(verify_token)):
    """Dependency function to verify admin user."""
    user = UserOperations.get_user_by_id(user_id)
    if not user or not user.get('is_admin', False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return user_id

@app.get("/admin/api/artists")
def admin_list_artists(user_id: str = Depends(verify_admin_user)):
    client = get_mongo_client()
    return list(client["discovery"]["artists_v2"].find({}, {"_id": 0}).sort("artist_name", 1))


# --- New Admin APIs ---
class AssignArtistPayload(BaseModel):
    artist_id_list: List[str]
    artist_name_list: List[str]


@app.get("/admin/api/missing_artist_sessions")
def admin_get_missing_artist_sessions(user_id: str = Depends(verify_admin_user)):
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


@app.put("/admin/api/workshops/{workshop_uuid}/assign_artist")
def admin_assign_artist_to_session(
    workshop_uuid: str, payload: AssignArtistPayload = Body(...), user_id: str = Depends(verify_admin_user)
):
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
    if result.modified_count == 0:
        # This could happen if the artist_id was already set or detail_index is out of bounds (though mongo might not error)
        # For simplicity, we'll consider it a success if matched, but ideally, check if modification actually happened as expected.
        pass

    return {
        "success": True,
        "message": f"Artists {combined_artist_names} assigned to workshop {workshop_uuid}.",
    }


@app.get("/admin", response_class=HTMLResponse)
async def admin_panel(request: Request, user_id: str = Depends(verify_admin_user)):
    return templates.TemplateResponse(
        "website/admin_missing_artists.html", {"request": request}
    )


@app.get("/admin/api/missing_song_sessions")
def admin_get_missing_song_sessions(user_id: str = Depends(verify_admin_user)):
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
    workshop_uuid: str, payload: AssignSongPayload = Body(...), user_id: str = Depends(verify_admin_user)
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


# Authentication API Routes
@app.post("/api/auth/register", response_model=AuthResponse)
async def register_user(user_data: UserRegistration):
    """Register a new user.
    
    Args:
        user_data: User registration data
        
    Returns:
        Authentication response with token and user profile
    """
    try:
        # Create user
        new_user = UserOperations.create_user(
            mobile_number=user_data.mobile_number,
            password=user_data.password
        )
        
        # Create access token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": str(new_user["_id"])},
            expires_delta=access_token_expires
        )
        
        # Format user profile
        user_profile = format_user_profile(new_user)
        
        return AuthResponse(
            access_token=access_token,
            token_type="bearer",
            user=user_profile
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Registration error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

@app.post("/api/auth/login", response_model=AuthResponse)
async def login_user(user_data: UserLogin):
    """Login user.
    
    Args:
        user_data: User login credentials
        
    Returns:
        Authentication response with token and user profile
    """
    # Authenticate user
    user = UserOperations.authenticate_user(
        mobile_number=user_data.mobile_number,
        password=user_data.password
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password"
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": str(user["_id"])},
        expires_delta=access_token_expires
    )
    
    # Format user profile
    user_profile = format_user_profile(user)
    
    return AuthResponse(
        access_token=access_token,
        token_type="bearer",
        user=user_profile
    )

@app.get("/api/auth/profile", response_model=UserProfile)
async def get_user_profile(user_id: str = Depends(verify_token)):
    """Get current user profile.
    
    Args:
        user_id: User ID from JWT token
        
    Returns:
        User profile information
    """
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return format_user_profile(user)

@app.put("/api/auth/profile", response_model=UserProfile)
async def update_user_profile(
    profile_data: ProfileUpdate,
    user_id: str = Depends(verify_token)
):
    """Update user profile.
    
    Args:
        profile_data: Profile update data
        user_id: User ID from JWT token
        
    Returns:
        Updated user profile
    """
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Prepare update data (only include non-None values)
    update_data = {}
    if profile_data.name is not None:
        update_data["name"] = profile_data.name
    if profile_data.date_of_birth is not None:
        update_data["date_of_birth"] = profile_data.date_of_birth
    if profile_data.gender is not None:
        update_data["gender"] = profile_data.gender
    
    # Update profile
    success = UserOperations.update_user_profile(user_id, update_data)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profile update failed"
        )
    
    # Return updated profile
    updated_user = UserOperations.get_user_by_id(user_id)
    return format_user_profile(updated_user)

@app.put("/api/auth/password")
async def update_user_password(
    password_data: PasswordUpdate,
    user_id: str = Depends(verify_token)
):
    """Update user password.
    
    Args:
        password_data: Password update data
        user_id: User ID from JWT token
        
    Returns:
        Success message
    """
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Verify current password
    if not verify_password(password_data.current_password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Update password
    success = UserOperations.update_user_password(user_id, password_data.new_password)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password update failed"
        )
    
    return {"message": "Password updated successfully"}

@app.get("/api/config")
async def get_config(user_id: str = Depends(verify_token)):
    """Get app configuration for authenticated user.
    
    Args:
        user_id: User ID from JWT token
        
    Returns:
        App configuration including user permissions
    """
    # Get current user
    user = UserOperations.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return {
        "is_admin": user.get("is_admin", False)
    }


if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8002,
        workers=4,  # Number of worker processes
        loop="uvloop",  # Use uvloop for better performance
        http="httptools",  # Use httptools for better performance
        reload=True,  # Enable auto-reload during development
        access_log=False,  # Disable default access logs to prevent duplication with our custom middleware
        log_level="info",
        proxy_headers=True,
        forwarded_allow_ips="*",
    )
