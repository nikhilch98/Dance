"""
Database operations for choreo_links collection with video support.

This module provides CRUD operations for the choreo_links collection,
including video status tracking and GridFS file references.

IMPORTANT: All processing/status operations filter by active workshops only.
Active workshops are defined as:
1. is_archived != True
2. event_type not in ["regulars"] 
3. Workshop date >= start of current week (Monday)

This matches the "All Workshops" API filtering logic.
"""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Set
from bson import ObjectId
from utils.utils import get_mongo_client


class ChoreoLinksOperations:
    """Database operations for choreo_links collection."""
    
    @staticmethod
    def get_collection():
        """Get the choreo_links collection."""
        client = get_mongo_client()
        return client["discovery"]["choreo_links"]
    
    @staticmethod
    def get_workshops_collection():
        """Get the workshops_v2 collection."""
        client = get_mongo_client()
        return client["discovery"]["workshops_v2"]
    
    @staticmethod
    def get_active_workshop_instagram_links() -> Set[str]:
        """
        Get all Instagram links from active workshops.
        
        Active workshops are defined as (matching "All Workshops" API logic):
        1. is_archived != True
        2. event_type not in ["regulars"]
        3. Workshop has at least one time_detail date >= start of current week
        
        Returns:
            Set of Instagram URLs from active workshops
        """
        workshops = ChoreoLinksOperations.get_workshops_collection()
        
        # Calculate start of current week (Monday)
        today = datetime.now().date()
        start_of_week = today - timedelta(days=today.weekday())
        
        # Find all non-archived, non-regular workshops with choreo_insta_link
        active_workshops_cursor = workshops.find(
            {
                "is_archived": {"$ne": True},
                "event_type": {"$nin": ["regulars"]},
                "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
            },
            {"choreo_insta_link": 1, "time_details": 1}  # Fetch link and time_details
        )
        
        active_links = set()
        
        for workshop in active_workshops_cursor:
            choreo_link = workshop.get("choreo_insta_link")
            if not choreo_link:
                continue
            
            # Check if any time_detail is from start of current week onwards
            time_details = workshop.get("time_details", [])
            for td in time_details:
                try:
                    workshop_date = datetime(
                        year=td.get("year"),
                        month=td.get("month"),
                        day=td.get("day"),
                    ).date()
                    
                    # Include if workshop date is >= start of current week
                    if workshop_date >= start_of_week:
                        active_links.add(choreo_link)
                        break  # No need to check other time_details
                except (TypeError, ValueError, KeyError):
                    continue
        
        return active_links
    
    @staticmethod
    def get_by_id(choreo_link_id: str) -> Optional[Dict[str, Any]]:
        """
        Get a choreo_link document by ID.
        
        Args:
            choreo_link_id: The document ID
            
        Returns:
            Document dict or None if not found
        """
        collection = ChoreoLinksOperations.get_collection()
        oid = ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id
        doc = collection.find_one({"_id": oid})
        if doc:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        return doc
    
    @staticmethod
    def get_by_instagram_url(instagram_url: str) -> Optional[Dict[str, Any]]:
        """
        Get a choreo_link document by Instagram URL.
        
        Args:
            instagram_url: The Instagram reel URL
            
        Returns:
            Document dict or None if not found
        """
        collection = ChoreoLinksOperations.get_collection()
        doc = collection.find_one({"choreo_insta_link": instagram_url})
        if doc:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        return doc
    
    @staticmethod
    def get_by_song_and_artist(song: str, artist_id_list: List[str]) -> Optional[Dict[str, Any]]:
        """
        Get a choreo_link document by song and artist list.
        
        Args:
            song: Song name
            artist_id_list: List of artist IDs
            
        Returns:
            Document dict or None if not found
        """
        collection = ChoreoLinksOperations.get_collection()
        doc = collection.find_one({
            "song": song,
            "artist_id_list": {"$all": artist_id_list}
        })
        if doc:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        return doc
    
    @staticmethod
    def update_video_status(
        choreo_link_id: str,
        status: str,
        gridfs_file_id: Optional[str] = None,
        file_size: Optional[int] = None,
        error: Optional[str] = None
    ) -> bool:
        """
        Update video status fields in a choreo_link document.
        
        Args:
            choreo_link_id: The document ID
            status: Video status (pending, processing, completed, failed)
            gridfs_file_id: GridFS file ID if video was stored
            file_size: Video file size in bytes
            error: Error message if status is failed
            
        Returns:
            True if update was successful
        """
        collection = ChoreoLinksOperations.get_collection()
        oid = ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id
        
        update_doc = {
            "video_status": status,
            "video_processed_at": datetime.utcnow()
        }
        
        if gridfs_file_id:
            update_doc["gridfs_file_id"] = ObjectId(gridfs_file_id) if isinstance(gridfs_file_id, str) else gridfs_file_id
        
        if file_size is not None:
            update_doc["video_file_size"] = file_size
        
        if error:
            update_doc["video_error"] = error
        else:
            update_doc["video_error"] = None
        
        result = collection.update_one(
            {"_id": oid},
            {"$set": update_doc}
        )
        
        return result.modified_count > 0
    
    @staticmethod
    def get_with_videos(
        limit: int = 100,
        offset: int = 0,
        include_pending: bool = False,
        active_only: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get choreo_links that have videos (completed status).
        
        Args:
            limit: Maximum number of documents to return
            offset: Number of documents to skip
            include_pending: Whether to include pending/processing videos
            active_only: Only return choreo_links for active workshops (default: True)
            
        Returns:
            List of choreo_link documents with video data
        """
        collection = ChoreoLinksOperations.get_collection()
        
        # Get active workshop Instagram links if filtering
        active_links = None
        if active_only:
            active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
            if not active_links:
                return []  # No active workshops with links
        
        if include_pending:
            query = {
                "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
            }
        else:
            query = {
                "video_status": "completed",
                "gridfs_file_id": {"$exists": True, "$ne": None}
            }
        
        # Filter by active workshop links
        if active_links:
            query["choreo_insta_link"] = {"$in": list(active_links)}
        
        docs = list(collection.find(query).skip(offset).limit(limit))
        
        # Convert ObjectIds to strings
        for doc in docs:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        
        return docs
    
    @staticmethod
    def get_unprocessed(limit: int = 50, active_only: bool = True) -> List[Dict[str, Any]]:
        """
        Get choreo_links that haven't been processed yet.
        Only returns links from active (non-archived) workshops by default.
        
        Args:
            limit: Maximum number of documents to return
            active_only: Only return choreo_links for active workshops (default: True)
            
        Returns:
            List of choreo_link documents
        """
        collection = ChoreoLinksOperations.get_collection()
        
        # Get active workshop Instagram links if filtering
        active_links = None
        if active_only:
            active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
            if not active_links:
                return []  # No active workshops with links
        
        query = {
            "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None},
            "$or": [
                {"video_status": {"$exists": False}},
                {"video_status": None},
                {"video_status": "pending"}
            ]
        }
        
        # Filter by active workshop links
        if active_links:
            query["choreo_insta_link"] = {"$in": list(active_links)}
        
        docs = list(collection.find(query).limit(limit))
        
        for doc in docs:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        
        return docs
    
    @staticmethod
    def get_failed(limit: int = 50, active_only: bool = True) -> List[Dict[str, Any]]:
        """
        Get choreo_links that failed processing (for retry).
        Only returns links from active (non-archived) workshops by default.
        
        Args:
            limit: Maximum number of documents to return
            active_only: Only return choreo_links for active workshops (default: True)
            
        Returns:
            List of choreo_link documents
        """
        collection = ChoreoLinksOperations.get_collection()
        
        # Get active workshop Instagram links if filtering
        active_links = None
        if active_only:
            active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
            if not active_links:
                return []  # No active workshops with links
        
        query = {
            "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None},
            "video_status": "failed"
        }
        
        # Filter by active workshop links
        if active_links:
            query["choreo_insta_link"] = {"$in": list(active_links)}
        
        docs = list(collection.find(query).limit(limit))
        
        for doc in docs:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        
        return docs
    
    @staticmethod
    def count_by_status(active_only: bool = True) -> Dict[str, int]:
        """
        Get counts of choreo_links by video status.
        Only counts links from active (non-archived) workshops by default.
        
        Args:
            active_only: Only count choreo_links for active workshops (default: True)
        
        Returns:
            Dict with status counts
        """
        collection = ChoreoLinksOperations.get_collection()
        
        # Get active workshop Instagram links if filtering
        match_stage = {
            "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
        }
        
        if active_only:
            active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
            if not active_links:
                return {
                    "unprocessed": 0,
                    "pending": 0,
                    "processing": 0,
                    "completed": 0,
                    "failed": 0,
                    "total": 0,
                    "active_workshops_with_links": 0
                }
            match_stage["choreo_insta_link"] = {"$in": list(active_links)}
        
        pipeline = [
            {"$match": match_stage},
            {
                "$group": {
                    "_id": {"$ifNull": ["$video_status", "unprocessed"]},
                    "count": {"$sum": 1}
                }
            }
        ]
        
        results = list(collection.aggregate(pipeline))
        
        # Convert to dict
        counts = {
            "unprocessed": 0,
            "pending": 0,
            "processing": 0,
            "completed": 0,
            "failed": 0,
            "total": 0
        }
        
        for r in results:
            status = r["_id"]
            count = r["count"]
            if status in counts:
                counts[status] = count
            counts["total"] += count
        
        # Add count of active workshops with links (for reference)
        if active_only:
            counts["active_workshops_with_links"] = len(ChoreoLinksOperations.get_active_workshop_instagram_links())
        
        return counts
    
    @staticmethod
    def reset_video_status(choreo_link_id: str) -> bool:
        """
        Reset video status to allow reprocessing.
        
        Args:
            choreo_link_id: The document ID
            
        Returns:
            True if reset was successful
        """
        collection = ChoreoLinksOperations.get_collection()
        oid = ObjectId(choreo_link_id) if isinstance(choreo_link_id, str) else choreo_link_id
        
        result = collection.update_one(
            {"_id": oid},
            {
                "$set": {
                    "video_status": "pending",
                    "video_error": None
                },
                "$unset": {
                    "gridfs_file_id": "",
                    "video_file_size": "",
                    "video_processed_at": ""
                }
            }
        )
        
        return result.modified_count > 0
    
    @staticmethod
    def get_all_with_instagram_links(active_only: bool = True) -> List[Dict[str, Any]]:
        """
        Get all choreo_links that have Instagram links.
        Only returns links from active (non-archived) workshops by default.
        
        Args:
            active_only: Only return choreo_links for active workshops (default: True)
        
        Returns:
            List of all choreo_link documents with Instagram links
        """
        collection = ChoreoLinksOperations.get_collection()
        
        query = {
            "choreo_insta_link": {"$exists": True, "$ne": "", "$ne": None}
        }
        
        # Filter by active workshop links
        if active_only:
            active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
            if not active_links:
                return []
            query["choreo_insta_link"] = {"$in": list(active_links)}
        
        docs = list(collection.find(query))
        
        for doc in docs:
            doc["_id"] = str(doc["_id"])
            if "gridfs_file_id" in doc and doc["gridfs_file_id"]:
                doc["gridfs_file_id"] = str(doc["gridfs_file_id"])
        
        return docs
    
    @staticmethod
    def is_link_in_active_workshop(instagram_url: str) -> bool:
        """
        Check if an Instagram URL is associated with an active workshop.
        
        Args:
            instagram_url: The Instagram reel URL
            
        Returns:
            True if the link is in an active workshop
        """
        workshops = ChoreoLinksOperations.get_workshops_collection()
        
        workshop = workshops.find_one({
            "is_archived": {"$ne": True},
            "choreo_insta_link": instagram_url
        })
        
        return workshop is not None