"""Artist data population script for the Dance Workshop application.

This module handles fetching and updating artist information from Instagram
and storing it in the database. It includes functionality for profile picture
retrieval and data validation.
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from typing import List, Optional, Dict

import requests
from tqdm import tqdm

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from utils.utils import DatabaseManager, is_image_downloadable


@dataclass
class Artist:
    """Artist information container."""

    name: str
    instagram_id: str
    image_url: Optional[str] = None

    @property
    def instagram_link(self) -> str:
        """Get artist's Instagram profile link."""
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
        "Accept": "*/*",
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
                timeout=10,
            )
            response.raise_for_status()
            data = response.json()
            return data["data"]["user"]["profile_pic_url_hd"]
        except Exception as e:
            print(f"Failed to fetch data for {username}. Error: {str(e)}")
            return None


class ArtistManager:
    """Artist data management system."""

    def __init__(self, env):
        """Initialize the artist manager."""
        self.client = DatabaseManager.get_mongo_client(env)
        self.collection = self.client["discovery"]["artists_v2"]

    def update_artist(self, artist: Artist) -> None:
        """Update or insert artist information in database.

        Args:
            artist: Artist information to update
        """
        data = {
            "artist_id": artist.instagram_id,
            "artist_name": artist.name,
            "instagram_link": artist.instagram_link,
        }

        # Only update image if we have a new one
        if artist.image_url:
            data["image_url"] = artist.image_url

        self.collection.update_one(
            {"artist_id": artist.instagram_id}, {"$set": data}, upsert=True
        )

    def get_existing_image(self, artist_id: str) -> Optional[str]:
        """Get existing image URL for artist if any.

        Args:
            artist_id: Artist's Instagram ID

        Returns:
            Existing image URL or None
        """
        result = self.collection.find_one({"artist_id": artist_id}, {"image_url": 1})
        return result.get("image_url") if result else None


def get_artists_list() -> List[Artist]:
    """Get list of artists to process.

    Returns:
        List of Artist objects with name and Instagram ID
    """
    return [
        Artist("Aashish Lama","aashish_lama01"),
        Artist("Punyakar Upadhyay","punyakar"),
        Artist("Divyam","div_yumyum"),
        Artist("Charles Edward", "charlesedward___"),
        Artist("Om Tharpe", "danceastic_om"),
        Artist("Upasana Madan", "upasanamadan"),
        Artist("Mannu Mehta", "mannumehta_"),
        Artist("Vikas Paudel", "vikas_paudel"),
        Artist("Vatsaal Vithalani", "vatsaalvithalani09"),
        Artist("Anvi Shetty", "anvishetty"),
        Artist("Sanu Priya", "dancewings2soul"),
        Artist("Radhika Warikoo", "dancewithrw"),
        Artist("Aadil Khan", "aadilkhann"),
        Artist("Mohit Solanki", "mohitsolanki11"),
        Artist("Enette D'souza", "enettedsouzadance"),
        Artist("Prakhar Saini", "saini.prakhar"),
        Artist("Jainil Mehta", "jainil_dreamtodance"),
        Artist("Rajat Bansal", "thatsilverdancinggirl"),
        Artist("Prakhar Shrivastava", "_.prakhar8"),
        Artist("Palak Shettiwar", "palak_shettiwar"),
        Artist("Aditya Tripathi", "adityatripathiii__"),
        Artist("Ajay Lama", "aka.lamaboi"),
        Artist("Ashish Dubey", "aashish.dubeyy"),
        Artist("Chiraj Gupta", "chirag_guptaaaa"),
        Artist("Deepak Tulsyan", "deepaktulsyan"),
        Artist("Jay Sharma", "jaysharma_ruh"),
        Artist("Jeevitha", "jeevitha_dna"),
        Artist("Jordan Yashazwi", "jordanyashazwi"),
        Artist("Junaid Sharif", "junaidsharrif"),
        Artist("Naeem Patel", "_naeempatel_"),
        Artist("Nanak Singh", "nanaksingh1030"),
        Artist("Niraj Pardeshi", "nirajpardeshi"),
        Artist("Noel Alexander", "alexander_noel_janam"),
        Artist("Pravin Agawane Ganesh", "pravinganeshagawane"),
        Artist("Sagar Tiruwa", "sagar_tiruwa"),
        Artist("Sarang Lokhande", "saranglokhande__"),
        Artist("Simran Jat", "simranjat_"),
        Artist("Twin Me Not (Antra & Aanchal)", "twinmenot"),
        Artist("Umesh Negi", "umeshnegi3"),
        Artist("Vidit Gaur", "vidit__gaur"),
        Artist("Vipul Devrani", "vipuldevrani"),
        Artist("Harjot Narang", "harjotnarang"),
        Artist("Shazeb Sheik", "shazebsheikh"),
        Artist("Sagar Chand", "sagar_chand78"),
        Artist("Siddhartha Dayani", "siddharthadayani"),
        Artist("Shehzaan Khan", "isshehzaannkhan"),
        Artist("Monjit Rajbongshi", "monjit_rajbongshiii"),
        Artist("Sagar Thakur", "sagar_thakur107"),
        Artist("Kunal Pal", "_kunaal_04"),
        Artist("Harsh Bhagchandani", "harshbhagchandani_"),
        Artist("Abhi Badarshahi", "abhi_badarshahi"),
        Artist("Harsh Kumar", "harshkumarofficiall"),
        Artist("Wehzan", "wehzan"),
        Artist("Yahvi", "yahvichavan"),
        Artist("Dev Narayan Gupta", "gurudev.ng"),
        Artist("Rudra Barve", "rudra.barve"),
        Artist("Nishi", "nish.i11"),
        Artist("Ankit Sati", "ankitsati"),
        Artist("Surya H", "surya_from_k_town_"),
        Artist("Prabhat Patro", "prabhat.patro"),
        Artist("Dherya kandari", "dheryakandari"),
        Artist("Thangaat Garba", "thangaatgarba"),
    ]


def parse_arguments():
    parser = argparse.ArgumentParser(description="Populate workshops data.")

    parser.add_argument(
        "--env",
        required=True,
        choices=["prod", "dev"],
        help="Set the environment (prod or dev)",
    )

    return parser.parse_args()


def main():
    """Main execution function."""
    # Parse command-line arguments
    args = parse_arguments()

    # Determine environment
    env = args.env
    manager = ArtistManager(env)
    artists = get_artists_list()

    with tqdm(artists, desc="Updating Artists", leave=False) as pbar:
        for artist in pbar:
            # Skip if image already exists
            if is_image_downloadable(manager.get_existing_image(artist.instagram_id)):
                continue

            # Fetch new profile picture
            pic_url = InstagramAPI.fetch_profile_picture_hd(artist.instagram_id)

            # Check if the image is downloadable before updating
            if pic_url:
                artist.image_url = pic_url

            # Update database
            manager.update_artist(artist)

            # Rate limiting
            time.sleep(1)


if __name__ == "__main__":
    main()
