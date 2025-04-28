"""Test suite for artist population functionality.

This module contains tests for the artist data population system,
including Instagram API interaction and database operations.
"""

import os
import sys
import unittest
from unittest.mock import Mock, patch

# Add parent directory to path for imports
sys.path.append(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)

from scripts.populate_artists import Artist, InstagramAPI, ArtistManager


class TestArtist(unittest.TestCase):
    """Test cases for Artist class."""

    def test_artist_creation(self):
        """Test artist object creation and properties."""
        artist = Artist("Test Artist", "test_handle")
        self.assertEqual(artist.name, "Test Artist")
        self.assertEqual(artist.instagram_id, "test_handle")
        self.assertIsNone(artist.image_url)

    def test_instagram_link(self):
        """Test Instagram link generation."""
        artist = Artist("Test Artist", "test_handle")
        expected_link = "https://www.instagram.com/test_handle/"
        self.assertEqual(artist.instagram_link, expected_link)


class TestInstagramAPI(unittest.TestCase):
    """Test cases for InstagramAPI class."""

    @patch("requests.get")
    def test_fetch_profile_picture_success(self, mock_get):
        """Test successful profile picture fetch."""
        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": {"user": {"profile_pic_url_hd": "https://example.com/pic.jpg"}}
        }
        mock_get.return_value = mock_response

        result = InstagramAPI.fetch_profile_picture_hd("test_user")
        self.assertEqual(result, "https://example.com/pic.jpg")
        mock_get.assert_called_once()

    @patch("requests.get")
    def test_fetch_profile_picture_failure(self, mock_get):
        """Test failed profile picture fetch."""
        # Mock failed response
        mock_get.side_effect = Exception("API Error")

        result = InstagramAPI.fetch_profile_picture_hd("test_user")
        self.assertIsNone(result)
        mock_get.assert_called_once()


class TestArtistManager(unittest.TestCase):
    """Test cases for ArtistManager class."""

    def setUp(self):
        """Set up test environment."""
        self.mock_db = Mock()
        self.mock_collection = Mock()

        # Setup patch for DatabaseManager
        self.db_patcher = patch("scripts.populate_artists.DatabaseManager")
        self.mock_db_manager = self.db_patcher.start()
        self.mock_db_manager.get_mongo_client.return_value = self.mock_db

        # Setup mock collection
        self.mock_db.__getitem__.return_value = {"artists_v2": self.mock_collection}

        self.manager = ArtistManager()

    def tearDown(self):
        """Clean up test environment."""
        self.db_patcher.stop()

    def test_update_artist_new(self):
        """Test updating a new artist."""
        artist = Artist("Test Artist", "test_handle", "https://example.com/pic.jpg")

        self.manager.update_artist(artist)

        self.mock_collection.update_one.assert_called_once_with(
            {"artist_id": "test_handle"},
            {
                "$set": {
                    "artist_id": "test_handle",
                    "artist_name": "Test Artist",
                    "instagram_link": "https://www.instagram.com/test_handle/",
                    "image_url": "https://example.com/pic.jpg",
                }
            },
            upsert=True,
        )

    def test_get_existing_image_found(self):
        """Test retrieving existing image URL."""
        self.mock_collection.find_one.return_value = {
            "image_url": "https://example.com/pic.jpg"
        }

        result = self.manager.get_existing_image("test_handle")
        self.assertEqual(result, "https://example.com/pic.jpg")

        self.mock_collection.find_one.assert_called_once_with(
            {"artist_id": "test_handle"}, {"image_url": 1}
        )

    def test_get_existing_image_not_found(self):
        """Test retrieving non-existent image URL."""
        self.mock_collection.find_one.return_value = None

        result = self.manager.get_existing_image("test_handle")
        self.assertIsNone(result)

        self.mock_collection.find_one.assert_called_once()


class TestArtistList(unittest.TestCase):
    """Test cases for artist list functionality."""

    def test_artists_list_structure(self):
        """Test structure of the artists list."""
        from scripts.populate_artists import get_artists_list

        artists = get_artists_list()
        self.assertTrue(len(artists) > 0)

        for artist in artists:
            self.assertIsInstance(artist, Artist)
            self.assertTrue(artist.name)
            self.assertTrue(artist.instagram_id)
            self.assertTrue(
                artist.instagram_link.startswith("https://www.instagram.com/")
            )


@patch("scripts.populate_artists.ArtistManager")
@patch("scripts.populate_artists.InstagramAPI")
def test_main_execution(mock_instagram_api, mock_artist_manager):
    """Test main execution flow."""
    from scripts.populate_artists import main

    # Setup mocks
    mock_manager = Mock()
    mock_artist_manager.return_value = mock_manager
    mock_manager.get_existing_image.return_value = None
    mock_instagram_api.fetch_profile_picture_hd.return_value = (
        "https://example.com/pic.jpg"
    )

    # Run main function
    main()

    # Verify execution
    mock_manager.get_existing_image.assert_called()
    mock_instagram_api.fetch_profile_picture_hd.assert_called()
    mock_manager.update_artist.assert_called()


if __name__ == "__main__":
    unittest.main()
