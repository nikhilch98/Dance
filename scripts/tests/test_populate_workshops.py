"""Test suite for workshop population functionality.

This module contains tests for the workshop data population system,
including GPT analysis and database operations.
"""

import os
import sys
import unittest
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from scripts.populate_workshops import (
    TimeDetails,
    WorkshopDetails,
    WorkshopSummary,
    WorkshopProcessor,
    StudioProcessor,
    get_artists_data
)

class TestTimeDetails(unittest.TestCase):
    """Test cases for TimeDetails class."""

    def test_time_details_creation(self):
        """Test time details object creation."""
        details = TimeDetails(
            day=15,
            month=3,
            year=2024,
            start_time="2:00 PM",
            end_time="4:00 PM"
        )
        
        self.assertEqual(details.day, 15)
        self.assertEqual(details.month, 3)
        self.assertEqual(details.year, 2024)
        self.assertEqual(details.start_time, "2:00 PM")
        self.assertEqual(details.end_time, "4:00 PM")

class TestWorkshopDetails(unittest.TestCase):
    """Test cases for WorkshopDetails class."""

    def test_workshop_details_creation(self):
        """Test workshop details object creation."""
        time_details = TimeDetails(
            day=15,
            month=3,
            year=2024,
            start_time="2:00 PM",
            end_time="4:00 PM"
        )
        
        details = WorkshopDetails(
            time_details=time_details,
            by="Test Instructor",
            song="Test Song",
            pricing_info="₹500",
            timestamp_epoch=1234567890,
            artist_id="test_artist"
        )
        
        self.assertEqual(details.by, "Test Instructor")
        self.assertEqual(details.song, "Test Song")
        self.assertEqual(details.pricing_info, "₹500")
        self.assertEqual(details.timestamp_epoch, 1234567890)
        self.assertEqual(details.artist_id, "test_artist")

class TestWorkshopProcessor(unittest.TestCase):
    """Test cases for WorkshopProcessor class."""

    def setUp(self):
        """Set up test environment."""
        self.mock_openai = Mock()
        self.mock_mongo = Mock()
        self.artists = [
            {"artist_id": "test_artist", "artist_name": "Test Artist"}
        ]
        
        self.processor = WorkshopProcessor(
            self.mock_openai,
            self.artists,
            self.mock_mongo
        )

    @patch('scripts.populate_workshops.ScreenshotManager')
    def test_process_link_success(self, mock_screenshot_manager):
        """Test successful workshop link processing."""
        # Mock dependencies
        mock_screenshot_manager.capture_screenshot.return_value = True
        mock_screenshot_manager.upload_screenshot.return_value = {"url": "test_url"}
        
        mock_studio = Mock()
        mock_studio.studio_id = "test_studio"
        
        # Mock GPT response
        mock_response = Mock()
        mock_response.model_dump.return_value = {
            "is_workshop": True,
            "workshop_details": [{
                "time_details": {
                    "day": 15,
                    "month": 3,
                    "year": 2024,
                    "start_time": "2:00 PM",
                    "end_time": "4:00 PM"
                },
                "by": "Test Instructor",
                "song": "Test Song",
                "pricing_info": "₹500",
                "timestamp_epoch": 1234567890,
                "artist_id": "test_artist"
            }]
        }
        
        self.mock_openai.beta.chat.completions.parse.return_value.choices = [
            Mock(message=Mock(content=mock_response))
        ]
        
        # Execute
        self.processor.process_link("test_link", mock_studio, 1)
        
        # Verify
        mock_screenshot_manager.capture_screenshot.assert_called_once()
        mock_screenshot_manager.upload_screenshot.assert_called_once()
        self.mock_openai.beta.chat.completions.parse.assert_called_once()
        self.mock_mongo["discovery"]["workshops_v2"].update_one.assert_called_once()

    @patch('scripts.populate_workshops.ScreenshotManager')
    def test_process_link_not_workshop(self, mock_screenshot_manager):
        """Test processing of non-workshop link."""
        # Mock dependencies
        mock_screenshot_manager.capture_screenshot.return_value = True
        mock_screenshot_manager.upload_screenshot.return_value = {"url": "test_url"}
        
        mock_studio = Mock()
        mock_studio.studio_id = "test_studio"
        
        # Mock GPT response indicating not a workshop
        mock_response = Mock()
        mock_response.model_dump.return_value = {
            "is_workshop": False,
            "workshop_details": []
        }
        
        self.mock_openai.beta.chat.completions.parse.return_value.choices = [
            Mock(message=Mock(content=mock_response))
        ]
        
        # Execute
        self.processor.process_link("test_link", mock_studio, 1)
        
        # Verify
        self.mock_mongo["discovery"]["workshops_v2"].update_one.assert_not_called()

class TestStudioProcessor(unittest.TestCase):
    """Test cases for StudioProcessor class."""

    def setUp(self):
        """Set up test environment."""
        self.mock_openai = Mock()
        self.mock_mongo = Mock()
        self.artists = [
            {"artist_id": "test_artist", "artist_name": "Test Artist"}
        ]
        
        self.processor = StudioProcessor(
            self.mock_openai,
            self.artists,
            self.mock_mongo,
            version=1,
            position=0
        )

    def test_process_studio(self):
        """Test studio processing."""
        mock_studio = Mock()
        mock_studio.studio_id = "test_studio"
        mock_studio.scrape_links.return_value = ["link1", "link2"]
        
        # Execute
        self.processor.process_studio(mock_studio)
        
        # Verify
        mock_studio.scrape_links.assert_called_once()

@patch('scripts.populate_workshops.DatabaseManager')
def test_get_artists_data(mock_db_manager):
    """Test artist data retrieval."""
    # Mock database response
    mock_client = Mock()
    mock_db_manager.get_mongo_client.return_value = mock_client
    
    mock_collection = Mock()
    mock_client["discovery"]["artists_v2"] = mock_collection
    
    expected_artists = [
        {"artist_id": "test_artist", "artist_name": "Test Artist"}
    ]
    mock_collection.find.return_value = expected_artists
    
    # Execute
    result = get_artists_data()
    
    # Verify
    self.assertEqual(result, expected_artists)
    mock_collection.find.assert_called_once_with(
        {}, {"artist_id": 1, "artist_name": 1}
    )

if __name__ == '__main__':
    unittest.main()