"""Artist data population script for the Dance Workshop application.

This module handles fetching and updating artist information from Instagram
and storing it in the database. It includes functionality for profile picture
retrieval and data validation.
"""

import json
import os
import sys
import time
from dataclasses import dataclass
from typing import List, Optional, Dict

import requests
from tqdm import tqdm

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.utils import DatabaseManager

@dataclass
class Studio:
    """Artist information container."""
    studio_id: str
    name: str
    instagram_id: str
    image_url: Optional[str] = None
    
    @property
    def instagram_link(self) -> str:
        """Get studio's Instagram profile link."""
        return f"https://www.instagram.com/{self.instagram_id}/"

class InstagramAPI:
    """Instagram API interaction handler."""
    
    HEADERS = {
        "x-ig-app-id": "936619743392459",
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/62.0.3202.94 Safari/537.36"
        ),
        "Accept-Language": "en-US,en;q=0.9,ru;q=0.8",
        "Accept-Encoding": "gzip, deflate, br",
        "Accept": "*/*"
    }
    
    @classmethod
    def fetch_profile_picture_hd(cls, username: str) -> Optional[str]:
        """Fetch HD profile picture URL from Instagram.
        
        Args:
            username: Instagram username
            
        Returns:
            HD profile picture URL or None if fetch fails
        """
        try:
            response = requests.get(
                f"https://i.instagram.com/api/v1/users/web_profile_info/?username={username}",
                headers=cls.HEADERS,
                timeout=10
            )
            response.raise_for_status()
            data = response.json()
            return data["data"]["user"]["profile_pic_url_hd"]
        except Exception as e:
            print(f"Failed to fetch data for {username}. Error: {str(e)}")
            return None

class StudioManager:
    """Studio data management system."""
    
    def __init__(self):
        """Initialize the artist manager."""
        self.client = DatabaseManager.get_mongo_client()
        self.collection = self.client["discovery"]["studios_v2"]

    def update_studio(self, studio: Studio) -> None:
        """Update or insert studio information in database.
        
        Args:
            studio: Studio information to update
        """
        data = {
            "studio_id": studio.studio_id,
            "studio_name": studio.name,
            "instagram_link": studio.instagram_link,
        }
        
        # Only update image if we have a new one
        if studio.image_url:
            data["image_url"] = studio.image_url
            
        self.collection.update_one(
            {"studio_id": studio.studio_id},
            {"$set": data},
            upsert=True
        )

    def get_existing_image(self, studio_id: str) -> Optional[str]:
        """Get existing image URL for studio if any.
        
        Args:
            studio_id: Studio's Instagram ID
            
        Returns:
            Existing image URL or None
        """
        result = self.collection.find_one(
            {"studio_id": studio_id},
            {"image_url": 1}
        )
        return result.get("image_url") if result else None

def get_studios_list() -> List[Studio]:
    """Get list of studios to process.
    
    Returns:
        List of Studio objects with name and Instagram ID
    """
    return [
        Studio("dance.inn.bangalore","Dance Inn","dance.inn.bangalore"),
        Studio("vins.dance.co","Vins Dance Co","vinsdanceco"),
        Studio("dance_n_addiction","Dance N Addiction","dance_n_addiction"),
        Studio("manifestbytmn","Manifest By TMN","manifestbytmn"),
    ]

def is_image_downloadable(url: Optional[str]) -> bool:
    """Check if an image URL is downloadable.
    
    Args:
        url: URL of the image to check
        
    Returns:
        Boolean indicating if the image is downloadable
    """
    if not url:
        return False
    
    try:
        # Send a HEAD request to check the image without downloading the full content
        response = requests.head(url, timeout=10, allow_redirects=True)
        
        # Check if the request was successful
        if response.status_code != 200:
            return False
        
        # Check content type to ensure it's an image
        content_type = response.headers.get('Content-Type', '').lower()
        if not content_type.startswith('image/'):
            return False
        
        # Optionally check content length if needed
        content_length = response.headers.get('Content-Length')
        if content_length and int(content_length) == 0:
            return False
        
        return True
    except Exception:
        return False

def main():
    """Main execution function."""
    manager = StudioManager()
    studios = get_studios_list()
    
    with tqdm(studios, desc="Updating Studios", leave=False) as pbar:
        for studio in pbar:
            # Skip if image already exists
            if is_image_downloadable(manager.get_existing_image(studio.instagram_id)):
                continue
                
            # Fetch new profile picture
            pic_url = InstagramAPI.fetch_profile_picture_hd(studio.instagram_id)
            
            # Check if the image is downloadable before updating
            if pic_url:
                studio.image_url = pic_url
                
            # Update database
            manager.update_studio(studio)
            
            # Rate limiting
            time.sleep(1)

if __name__ == "__main__":
    main()
