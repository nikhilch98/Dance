"""Search database operations."""

from typing import List, Optional
from datetime import datetime
import re

from app.database.workshops import DatabaseOperations
from app.models.search import SearchUserResult, SearchArtistResult, SearchWorkshopResult
from app.models.workshops import WorkshopListItem
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
    def search_workshops(query: str) -> List[WorkshopListItem]:
        """Search workshops by song name or artist name, sorted by time.
        
        Args:
            query: Search query string
            limit: Maximum number of results to return
            
        Returns:
            List of workshop search results sorted by timestamp
        """
        if not query or len(query.strip()) < 2:
            return []
            
        return DatabaseOperations.get_all_workshops(search_query=query)