"""Utility functions for the Dance Workshop application.

This module provides utility functions for database operations, date/time
formatting, URL handling, and screenshot capture functionality.
"""

from datetime import datetime
from io import BytesIO
from typing import Dict, Optional, Set, Tuple, Union
from urllib.parse import urljoin, urlparse
from pymongo.server_api import ServerApi
import requests
from bs4 import BeautifulSoup
from PIL import Image
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

import config
import time
import functools
import sys 

def retry(max_attempts=3, backoff_factor=1, exceptions=(Exception,)):
    """
    Decorator that retries a function if specific exceptions are raised.

    :param max_attempts: Number of total attempts before giving up.
    :param backoff_factor: Initial delay between retries, which will be
                           multiplied by 2 after each failed attempt.
    :param exceptions: A tuple of exception types to catch and retry upon.
    """
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            attempt = 0
            wait_time = backoff_factor

            while True:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    attempt += 1
                    if attempt >= max_attempts:
                        # Re-raise the last caught exception if we've hit the max attempts
                        raise
                    print(f"Attempt {attempt} failed with {e!r}. "
                          f"Retrying in {wait_time} seconds...")
                    time.sleep(wait_time)
                    # Exponential backoff
                    wait_time *= 2
        return wrapper
    return decorator

# Constants
class ImageConfig:
    """Configuration for image handling."""
    MAGIC_API_KEY = 'cm6fgbo9y0001ib03xkjneiil'
    UPLOAD_ENDPOINT = 'https://api.magicapi.dev/api/v1/magicapi/image-upload/upload'
    ALLOWED_MIME_TYPES = {'image/png', 'image/jpeg', 'image/gif'}
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

class BrowserConfig:
    """Configuration for browser automation."""
    WINDOW_WIDTH = 1920
    WINDOW_HEIGHT = 1080
    PAGE_LOAD_TIMEOUT = 10
    CHROME_OPTIONS = [
        '--headless',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer'
    ]

class DatabaseConfig:
    """Configuration for database connections."""
    TIMEOUT_MS = 5000
    RETRY_WRITES = True
    W_CONCERN = 'majority'

class DateTimeFormats:
    """Date and time format strings."""
    DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
    READABLE_FORMAT = "%-d %b %Y %-I:%M%p"
    TIME_FORMAT = "%I:%M %p"

# Database Operations
class DatabaseManager:
    """Database connection and operation management."""

    @staticmethod
    def get_mongo_client(env=None) -> MongoClient:
        """Get a MongoDB client instance.

        Args:
            env (str, optional): Environment to use. Defaults to None.
                If None, tries to parse from command-line arguments.

        Returns:
            MongoDB client configured with application settings

        Raises:
            Exception: If connection fails
        """
        try:
            # If no environment specified, try to parse from command-line
            if env is None:
                # Use the parse_args method from config to determine environment
                cfg = config.parse_args(sys.argv[0] if len(sys.argv) > 0 else None)
            else:
                # If environment is explicitly specified, create config for that env
                cfg = config.Config(env)

            # Use the MongoDB URI from the configuration
            client = MongoClient(
                cfg.mongodb_uri,
                server_api=ServerApi('1')
            )
            return client
        except Exception as e:
            raise Exception(f"Failed to connect to MongoDB: {str(e)}")

# Date and Time Operations
class DateTimeFormatter:
    """Date and time formatting utilities."""

    @staticmethod
    def convert_to_readable_format(timestamp: float) -> str:
        """Convert Unix timestamp to readable format with day suffix.

        Args:
            timestamp: Unix timestamp

        Returns:
            Formatted date string (e.g., "21st Mar 2024 2:30PM")
        """
        date_str = str(datetime.fromtimestamp(timestamp))
        dt = datetime.strptime(date_str, DateTimeFormats.DATE_FORMAT)
        readable_format = dt.strftime(DateTimeFormats.READABLE_FORMAT)
        
        day = dt.day
        if 4 <= day <= 20 or 24 <= day <= 30:
            suffix = "th"
        else:
            suffix = ["st", "nd", "rd"][day % 10 - 1]
        
        return f"{day}{suffix} {readable_format[2:]}"

    @staticmethod
    def get_formatted_date(time_details: Dict) -> str:
        """Format date using datetime module.

        Args:
            time_details: Dictionary with day, month, and year.

        Returns:
            Formatted date string (e.g., "07th Feb Thu").
        """
        date_obj = datetime(
            year=int(time_details['year']),
            month=int(time_details['month']),
            day=int(time_details['day'])
        )

        day = date_obj.day
        suffix = "th" if 11 <= day <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")

        return date_obj.strftime(f"%d{suffix} %b (%a)")
    
    @staticmethod
    def get_formatted_date_with_day(time_details: Dict) -> str:
        """Format date using datetime module.

        Args:
            time_details: Dictionary with day, month, and year.

        Returns:
            Formatted date string (e.g., "07th Feb Thu").
        """
        date_obj = datetime(
            year=int(time_details['year']),
            month=int(time_details['month']),
            day=int(time_details['day'])
        )

        day = date_obj.day
        suffix = "th" if 11 <= day <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")

        return [date_obj.strftime(f"%d{suffix} %b (%a)"), date_obj.strftime(f"%A")]

    @staticmethod
    def get_formatted_time(time_details: Dict) -> str:
        """Format time range from time details dictionary.

        Args:
            time_details: Dictionary with start_time and end_time

        Returns:
            Formatted time range string (e.g., "6:00 PM - 7:30 PM")
        """
        return f"{time_details['start_time']} - {time_details['end_time']}"

    @staticmethod
    def get_current_timestamp() -> float:
        """Get current timestamp.

        Returns:
            Current Unix timestamp
        """
        return datetime.now().timestamp()

# Screenshot and Image Operations
class ScreenshotManager:
    """Screenshot capture and management utilities."""

    @staticmethod
    @retry(max_attempts=5, backoff_factor=1)
    def capture_screenshot(url: str, output_file: str) -> bool:
        """Capture full page screenshot of a URL.

        Args:
            url: Website URL to capture
            output_file: Path to save the screenshot

        Returns:
            True if successful, False otherwise
        """
        service = Service(ChromeDriverManager().install())
        chrome_options = webdriver.ChromeOptions()
        
        for option in BrowserConfig.CHROME_OPTIONS:
            chrome_options.add_argument(option)

        driver = webdriver.Chrome(service=service, options=chrome_options)
        success = False

        try:
            driver.get(url)
            WebDriverWait(driver, BrowserConfig.PAGE_LOAD_TIMEOUT).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )

            total_width = driver.execute_script("return document.body.scrollWidth")
            total_height = driver.execute_script("return document.body.scrollHeight")
            driver.set_window_size(total_width, total_height)
            
            driver.save_screenshot(output_file)
            success = True
        except Exception as e:
            print(f"Screenshot capture failed: {str(e)}")
            success = False
        finally:
            driver.quit()
            return success

    @staticmethod
    def upload_screenshot(screenshot_path: str) -> Dict:
        """Upload screenshot to image hosting service.

        Args:
            screenshot_path: Path to screenshot file

        Returns:
            Response JSON from upload service

        Raises:
            Exception: If upload fails
        """
        headers = {
            'accept': 'application/json',
            'x-magicapi-key': ImageConfig.MAGIC_API_KEY
        }

        try:
            with open(screenshot_path, 'rb') as file:
                files = {
                    'filename': (screenshot_path, file, 'image/png')
                }
                response = requests.post(
                    ImageConfig.UPLOAD_ENDPOINT,
                    headers=headers,
                    files=files
                )
                response.raise_for_status()
                return response.json()
        except Exception as e:
            raise Exception(f"Screenshot upload failed: {str(e)}")

# URL Operations
class URLManager:
    """URL fetching and parsing utilities."""

    @staticmethod
    def fetch_url(url: str, timeout: int = 10) -> Tuple[str, Optional[str]]:
        """Fetch content from a URL.

        Args:
            url: URL to fetch
            timeout: Request timeout in seconds

        Returns:
            Tuple of (URL, content) where content may be None if fetch fails
        """
        try:
            response = requests.get(url, timeout=timeout)
            response.raise_for_status()
            return url, response.text
        except requests.RequestException as e:
            print(f"URL fetch failed: {str(e)}")
            return url, None

    @staticmethod
    def extract_links(html: str, base_url: str, domain: str) -> Set[str]:
        """Extract valid URLs from HTML content."""
        if not html or not base_url or not domain:
            return set()

        try:
            soup = BeautifulSoup(html, "html.parser")
            links = set()
            
            for a_tag in soup.find_all("a", href=True):
                try:
                    href = a_tag["href"].strip()
                    
                    # Skip empty links, javascript, mailto, tel
                    if not href or href.startswith(('javascript:', 'mailto:', 'tel:', '#')):
                        continue

                    # Handle protocol-relative URLs (//example.com)
                    if href.startswith('//'):
                        href = f'https:{href}'

                    absolute_url = urljoin(base_url, href)
                    parsed_url = urlparse(absolute_url)

                    # Skip non-HTTP(S) protocols
                    if parsed_url.scheme not in ('http', 'https'):
                        continue

                    # Normalize URL
                    normalized_url = parsed_url._replace(
                        fragment='',  # Remove fragments
                        params='',    # Remove params
                        query=''      # Remove query strings if needed
                    ).geturl()

                    if parsed_url.netloc == domain:
                        links.add(normalized_url)
                        
                except Exception as e:
                    # Log error and continue with next link
                    continue
                    
            return links
            
        except Exception as e:
            # Handle BeautifulSoup parsing errors
            return set()



# Image Utility Functions
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

# Convenience functions
get_mongo_client = DatabaseManager.get_mongo_client
get_formatted_date = DateTimeFormatter.get_formatted_date
get_formatted_date_with_day = DateTimeFormatter.get_formatted_date_with_day
get_formatted_time = DateTimeFormatter.get_formatted_time
get_current_timestamp = DateTimeFormatter.get_current_timestamp
fetch_url = URLManager.fetch_url
extract_links = URLManager.extract_links
capture_screenshot = ScreenshotManager.capture_screenshot
upload_screenshot = ScreenshotManager.upload_screenshot
is_image_downloadable = is_image_downloadable
