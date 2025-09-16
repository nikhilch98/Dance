"""
Database operations for centralized image storage.
"""
import base64
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from bson import ObjectId
from utils.utils import get_mongo_client
import requests
from fastapi import HTTPException


class ImageDatabase:
    """Database operations for centralized image storage."""
    
    @staticmethod
    def get_collection():
        """Get the images collection."""
        client = get_mongo_client()
        return client["dance_app"]["images"]
    
    @staticmethod
    def store_image(data: bytes, image_type: str, entity_id: str, content_type: str = "image/jpeg") -> str:
        """
        Store image data in the database.
        
        Args:
            data: Raw image data bytes
            image_type: Type of entity (studio, artist, user)
            entity_id: ID of the entity
            content_type: MIME type of the image
            
        Returns:
            str: The ObjectId of the stored image as string
        """
        collection = ImageDatabase.get_collection()
        
        # Check if image already exists for this entity
        existing = collection.find_one({
            "type": image_type,
            "entity_id": entity_id
        })
        
        image_doc = {
            "data": data,
            "type": image_type,
            "entity_id": entity_id,
            "content_type": content_type,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
            "size": len(data)
        }
        
        if existing:
            # Update existing image
            image_doc["created_at"] = existing.get("created_at", datetime.utcnow())
            result = collection.replace_one(
                {"_id": existing["_id"]}, 
                image_doc
            )
            return str(existing["_id"])
        else:
            # Insert new image
            result = collection.insert_one(image_doc)
            return str(result.inserted_id)
    
    @staticmethod
    def get_image(image_type: str, entity_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve image data from database.
        
        Args:
            image_type: Type of entity (studio, artist, user)
            entity_id: ID of the entity
            
        Returns:
            Dict with image data, content_type, etc. or None if not found
        """
        collection = ImageDatabase.get_collection()
        
        image_doc = collection.find_one({
            "type": image_type,
            "entity_id": entity_id
        })
        
        if image_doc:
            return {
                "data": image_doc["data"],
                "content_type": image_doc.get("content_type", "image/jpeg"),
                "created_at": image_doc.get("created_at"),
                "updated_at": image_doc.get("updated_at"),
                "size": image_doc.get("size", len(image_doc["data"]))
            }
        
        return None
    
    @staticmethod
    def delete_image(image_type: str, entity_id: str) -> bool:
        """
        Delete image from database.
        
        Args:
            image_type: Type of entity (studio, artist, user)
            entity_id: ID of the entity
            
        Returns:
            bool: True if deleted, False if not found
        """
        collection = ImageDatabase.get_collection()
        
        result = collection.delete_one({
            "type": image_type,
            "entity_id": entity_id
        })
        
        return result.deleted_count > 0
    
    @staticmethod
    def list_images(image_type: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """
        List images in database.
        
        Args:
            image_type: Optional filter by type
            limit: Maximum number of results
            
        Returns:
            List of image metadata (without data field)
        """
        collection = ImageDatabase.get_collection()
        
        query = {}
        if image_type:
            query["type"] = image_type
        
        cursor = collection.find(
            query,
            {"data": 0}  # Exclude large data field
        ).limit(limit)
        
        results = []
        for doc in cursor:
            doc["_id"] = str(doc["_id"])
            results.append(doc)
        
        return results
    
    @staticmethod
    def get_image_stats() -> Dict[str, Any]:
        """
        Get statistics about stored images.
        
        Returns:
            Dict with counts by type and total size
        """
        collection = ImageDatabase.get_collection()
        
        pipeline = [
            {
                "$group": {
                    "_id": "$type",
                    "count": {"$sum": 1},
                    "total_size": {"$sum": "$size"}
                }
            }
        ]
        
        results = list(collection.aggregate(pipeline))
        
        stats = {
            "total_count": 0,
            "total_size": 0,
            "by_type": {}
        }
        
        for result in results:
            image_type = result["_id"]
            count = result["count"]
            size = result.get("total_size", 0)
            
            stats["by_type"][image_type] = {
                "count": count,
                "total_size": size
            }
            stats["total_count"] += count
            stats["total_size"] += size
        
        return stats


class ImageMigration:
    """Helper class for migrating existing images to the new collection."""
    
    @staticmethod
    def fetch_and_store_image_from_url(url: str, image_type: str, entity_id: str) -> Optional[str]:
        """
        Fetch image from URL and store in database.
        
        Args:
            url: Image URL to fetch
            image_type: Type of entity (studio, artist, user) 
            entity_id: ID of the entity
            
        Returns:
            str: ObjectId of stored image or None if failed
        """
        try:
            headers = {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/91.0.4472.124 Safari/537.36"
                )
            }
            
            response = requests.get(url, headers=headers, timeout=30)
            response.raise_for_status()
            
            content_type = response.headers.get('content-type', 'image/jpeg')
            if not content_type.startswith('image/'):
                content_type = 'image/jpeg'
            
            return ImageDatabase.store_image(
                data=response.content,
                image_type=image_type,
                entity_id=entity_id,
                content_type=content_type
            )
            
        except Exception as e:
            print(f"Failed to fetch and store image from {url}: {str(e)}")
            return None
    
    @staticmethod
    def migrate_profile_pictures():
        """Migrate existing profile pictures to new collection."""
        client = get_mongo_client()
        profile_pictures = client["dance_app"]["profile_pictures"]
        
        migrated_count = 0
        failed_count = 0
        
        print("Migrating profile pictures...")
        
        for profile_doc in profile_pictures.find({}):
            try:
                user_id = profile_doc["user_id"]
                image_data = profile_doc["image_data"]
                content_type = profile_doc.get("content_type", "image/jpeg")
                
                ImageDatabase.store_image(
                    data=image_data,
                    image_type="user",
                    entity_id=user_id,
                    content_type=content_type
                )
                
                migrated_count += 1
                print(f"Migrated profile picture for user {user_id}")
                
            except Exception as e:
                print(f"Failed to migrate profile picture: {str(e)}")
                failed_count += 1
        
        print(f"Profile picture migration complete: {migrated_count} migrated, {failed_count} failed")
        return migrated_count, failed_count
    
    @staticmethod
    def migrate_studio_images():
        """Migrate studio images from URLs to new collection."""
        from app.database.workshops import DatabaseOperations
        
        migrated_count = 0
        failed_count = 0
        
        print("Migrating studio images...")
        
        studios = DatabaseOperations.get_studios()
        
        for studio in studios:
            try:
                studio_id = studio["id"]
                image_url = studio.get("image_url")
                
                if image_url:
                    result = ImageMigration.fetch_and_store_image_from_url(
                        url=image_url,
                        image_type="studio",
                        entity_id=studio_id
                    )
                    
                    if result:
                        migrated_count += 1
                        print(f"Migrated studio image for {studio_id}")
                    else:
                        failed_count += 1
                        print(f"Failed to migrate studio image for {studio_id}")
                else:
                    print(f"No image URL for studio {studio_id}")
                    
            except Exception as e:
                print(f"Failed to migrate studio image: {str(e)}")
                failed_count += 1
        
        print(f"Studio image migration complete: {migrated_count} migrated, {failed_count} failed")
        return migrated_count, failed_count
    
    @staticmethod
    def migrate_artist_images(artist_id_list: Optional[str] = None):
        """Migrate artist images from URLs to new collection."""
        from app.database.workshops import DatabaseOperations
        
        migrated_count = 0
        failed_count = 0
        
        print("Migrating artist images...")
        
        artists = DatabaseOperations.get_artists()
        
        for artist in artists:
            try:
                if artist_id_list and artist["id"] not in artist_id_list:
                    continue
                artist_id = artist["id"]
                image_url = artist.get("image_url")
                
                if image_url:
                    result = ImageMigration.fetch_and_store_image_from_url(
                        url=image_url,
                        image_type="artist", 
                        entity_id=artist_id
                    )
                    
                    if result:
                        migrated_count += 1
                        print(f"Migrated artist image for {artist_id}")
                    else:
                        failed_count += 1
                        print(f"Failed to migrate artist image for {artist_id}")
                else:
                    print(f"No image URL for artist {artist_id}")
                    
            except Exception as e:
                print(f"Failed to migrate artist image: {str(e)}")
                failed_count += 1
        
        print(f"Artist image migration complete: {migrated_count} migrated, {failed_count} failed")
        return migrated_count, failed_count
    
    @staticmethod
    def run_full_migration():
        """Run complete migration of all existing images."""
        print("Starting full image migration...")
        
        # Create index for performance
        collection = ImageDatabase.get_collection()
        collection.create_index([("type", 1), ("entity_id", 1)], unique=True)
        
        total_migrated = 0
        total_failed = 0
        
        # Migrate profile pictures
        migrated, failed = ImageMigration.migrate_profile_pictures()
        total_migrated += migrated
        total_failed += failed
        
        # Migrate studio images
        migrated, failed = ImageMigration.migrate_studio_images()
        total_migrated += migrated
        total_failed += failed
        
        # Migrate artist images  
        migrated, failed = ImageMigration.migrate_artist_images()
        total_migrated += migrated
        total_failed += failed
        
        print(f"\n=== MIGRATION COMPLETE ===")
        print(f"Total migrated: {total_migrated}")
        print(f"Total failed: {total_failed}")
        print(f"Collection stats: {ImageDatabase.get_image_stats()}")
        
        return total_migrated, total_failed