"""Search database operations."""

from typing import List, Optional
from datetime import datetime
import re

from app.models.search import SearchUserResult, SearchArtistResult, SearchWorkshopResult
from utils.utils import get_mongo_client


class SearchOperations:
    """Database operations for search functionality."""
    
    @staticmethod
    def search_users(query: str, limit: int = 20) -> List[SearchUserResult]:
        """Search users by name.
        
        Args:
            query: Search query string
            limit: Maximum number of results to return
            
        Returns:
            List of user search results
        """
        if not query or len(query.strip()) < 2:
            return []
            
        client = get_mongo_client()
        
        # Create case-insensitive regex pattern
        pattern = re.compile(re.escape(query.strip()), re.IGNORECASE)
        
        # Search users with names (ignore users without names)
        users_cursor = client["dance_app"]["users"].find({
            "name": {
                "$exists": True,
                "$ne": None,
                "$ne": "",
                "$regex": pattern
            }
        }).limit(limit)
        
        results = []
        for user in users_cursor:
            # Get profile picture URL if exists
            profile_picture_url = None
            if user.get("profile_picture_id"):
                try:
                    profile_pic = client["dance_app"]["profile_pictures"].find_one({
                        "_id": user["profile_picture_id"]
                    })
                    if profile_pic:
                        profile_picture_url = f"https://nachna.com/api/profile-picture/{user['profile_picture_id']}"
                except Exception:
                    pass
            
            results.append(SearchUserResult(
                user_id=str(user["_id"]),
                name=user["name"],
                profile_picture_url=profile_picture_url,
                created_at=user.get("created_at", datetime.utcnow())
            ))
        
        return results
    
    @staticmethod
    def search_artists(query: str, limit: int = 20) -> List[SearchArtistResult]:
        """Search artists by name or username.
        
        Args:
            query: Search query string
            limit: Maximum number of results to return
            
        Returns:
            List of artist search results
        """
        if not query or len(query.strip()) < 2:
            return []
            
        client = get_mongo_client()
        
        # Create case-insensitive regex pattern
        pattern = re.compile(re.escape(query.strip()), re.IGNORECASE)
        
        # Search artists by name
        artists_cursor = client["discovery"]["artists_v2"].find({
            "$or": [
                {"artist_name": {"$regex": pattern}},
                {"artist_id": {"$regex": pattern}}
            ]
        }).limit(limit)
        
        results = []
        for artist in artists_cursor:
            results.append(SearchArtistResult(
                id=artist["artist_id"],
                name=artist["artist_name"],
                image_url=artist.get("image_url"),
                instagram_link=artist["instagram_link"]
            ))
        
        # Sort by name for consistent ordering
        return sorted(results, key=lambda x: x.name.lower())
    
    @staticmethod
    def search_workshops(query: str, limit: int = 20) -> List[SearchWorkshopResult]:
        """Search workshops by song name or artist name, sorted by time.
        
        Args:
            query: Search query string
            limit: Maximum number of results to return
            
        Returns:
            List of workshop search results sorted by timestamp
        """
        if not query or len(query.strip()) < 2:
            return []
            
        client = get_mongo_client()
        
        # Create case-insensitive regex pattern
        pattern = re.compile(re.escape(query.strip()), re.IGNORECASE)
        
        # Get all artists for name lookup
        artists_dict = {}
        for artist in client["discovery"]["artists_v2"].find():
            artists_dict[artist["artist_id"]] = artist["artist_name"]
        
        # Get all studios for name lookup
        studios_dict = {}
        for studio in client["discovery"]["studios_v2"].find():
            studios_dict[studio["studio_id"]] = studio["studio_name"]
        
        # Search workshops by song name or artist names
        workshops_cursor = client["discovery"]["workshops_v2"].find({
            "$or": [
                {"song": {"$regex": pattern}},
                {"by": {"$regex": pattern}}
            ]
        }).limit(limit * 2)  # Get more to account for filtering
        
        results = []
        for workshop in workshops_cursor:
            # Get artist names
            artist_names = []
            artist_id_list = workshop.get("artist_id_list", [])
            for artist_id in artist_id_list:
                if artist_id in artists_dict:
                    artist_names.append(artists_dict[artist_id])
            
            # If no artist names from list, use 'by' field
            if not artist_names and workshop.get("by"):
                artist_names = [workshop["by"]]
            
            # Get studio name
            studio_name = studios_dict.get(workshop.get("studio_id", ""), "Unknown Studio")
            
            # Process each time detail
            for time_detail in workshop.get("time_details", []):
                if not time_detail:
                    continue
                
                try:
                    # Format date and time
                    day = time_detail.get("day")
                    month = time_detail.get("month")
                    year = time_detail.get("year")
                    start_time = time_detail.get("start_time", "")
                    
                    if not all([day, month, year]):
                        continue
                    
                    # Create timestamp for sorting
                    workshop_datetime = datetime(year, month, day)
                    timestamp_epoch = int(workshop_datetime.timestamp())
                    
                    # Format date string
                    date_str = workshop_datetime.strftime("%d %b %Y")
                    
                    results.append(SearchWorkshopResult(
                        uuid=workshop["uuid"],
                        song=workshop.get("song"),
                        artist_names=artist_names,
                        studio_name=studio_name,
                        date=date_str,
                        time=start_time,
                        timestamp_epoch=timestamp_epoch,
                        payment_link=workshop["payment_link"],
                        pricing_info=workshop.get("pricing_info"),
                        event_type=workshop.get("event_type")
                    ))
                except Exception as e:
                    # Skip workshops with invalid time details
                    continue
        
        # Sort by timestamp (most recent first) and limit results
        results.sort(key=lambda x: x.timestamp_epoch, reverse=True)
        return results[:limit] 