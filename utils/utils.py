"""Utility functions for the Dance Workshop application.

This module provides utility functions for database operations, date/time
formatting, URL handling, and screenshot capture functionality.
"""
import uuid
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
import functools
import config
import time
import functools
import sys
from fastapi import FastAPI, Request
import threading
import queue

# Global variables for cache management
cache = {}
hot_reload_queue = queue.Queue()
hot_reload_lock = threading.Lock()
is_hot_reload_running = False

def generate_uuid():
    return str(uuid.uuid4())

def cache_response(expire: int = 3600):
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs):
            # Create a cache key that works even if request isn't available
            request = kwargs.get("request")
            if request:
                cache_key = f"{func.__name__}-{request.url.path}-{request.query_params}"
            else:
                # Use args and kwargs values to create a cache key
                args_str = "-".join(str(arg) for arg in args)
                kwargs_str = "-".join(f"{k}:{v}" for k, v in kwargs.items())
                cache_key = f"{func.__name__}-{args_str}-{kwargs_str}"

            # Check if we have a cached response
            if cache_key in cache and (time.time() - cache[cache_key]["time"]) < expire:
                return cache[cache_key]["data"]

            # Execute the function if no cache hit
            response = await func(*args, **kwargs)
            cache[cache_key] = {"data": response, "time": time.time()}
            return response

        return wrapper

    return decorator


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
                    print(
                        f"Attempt {attempt} failed with {e!r}. "
                        f"Retrying in {wait_time} seconds..."
                    )
                    time.sleep(wait_time)
                    # Exponential backoff
                    wait_time *= 2

        return wrapper

    return decorator


# Constants
class ImageConfig:
    """Configuration for image handling."""

    MAGIC_API_KEY = "cm6fgbo9y0001ib03xkjneiil"
    UPLOAD_ENDPOINT = "https://api.magicapi.dev/api/v1/magicapi/image-upload/upload"
    ALLOWED_MIME_TYPES = {"image/png", "image/jpeg", "image/gif"}
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


class BrowserConfig:
    """Configuration for browser automation."""

    WINDOW_WIDTH = 1920
    WINDOW_HEIGHT = 1080
    PAGE_LOAD_TIMEOUT = 10
    DESKTOP_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    CHROME_OPTIONS = [
        "--headless",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--disable-software-rasterizer",
        "--disable-web-security",
        "--disable-features=VizDisplayCompositor",
        "--force-device-scale-factor=1",
        "--hide-scrollbars",
    ]


class DatabaseConfig:
    """Configuration for database connections."""

    TIMEOUT_MS = 5000
    RETRY_WRITES = True
    W_CONCERN = "majority"


class DateTimeFormats:
    """Date and time format strings."""

    DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
    READABLE_FORMAT = "%-d %b %Y %-I:%M%p"
    TIME_FORMAT = "%I:%M %p"


# Database Operations
class DatabaseManager:
    """Database connection and operation management."""

    # Class variable to store the singleton instance
    _instance = None
    _client = None
    _lock = threading.Lock()

    @classmethod
    def get_mongo_client(cls, env=config.DEFAULT_ENV) -> MongoClient:
        """Get a MongoDB client instance with connection pooling.

        This method implements a thread-safe singleton pattern to maintain
        a single MongoDB client with connection pooling across the application.

        Args:
            env (str, optional): Environment to use. Defaults to config.DEFAULT_ENV.
                If None, tries to parse from command-line arguments.

        Returns:
            MongoDB client configured with application settings and connection pooling

        Raises:
            Exception: If connection fails
        """
        # Return existing client if available
        if cls._client is not None:
            return cls._client

        # Thread-safe creation of new client
        with cls._lock:
            # Double-check lock pattern
            if cls._client is not None:
                return cls._client

            try:
                # If no environment specified, try to parse from command-line
                if env is None:
                    # Use the parse_args method from config to determine environment
                    cfg = config.parse_args(sys.argv[0] if len(sys.argv) > 0 else None)
                else:
                    # If environment is explicitly specified, create config for that env
                    cfg = config.Config(env)

                # Connection pool settings
                pool_options = {
                    "maxPoolSize": 100,  # Maximum number of connections in the pool
                    "minPoolSize": 10,  # Minimum number of connections in the pool
                    "maxIdleTimeMS": 30000,  # Maximum time a connection can remain idle (30 seconds)
                    "waitQueueTimeoutMS": 2000,  # How long a thread will wait for a connection (2 seconds)
                    "connectTimeoutMS": DatabaseConfig.TIMEOUT_MS,
                    "retryWrites": DatabaseConfig.RETRY_WRITES,
                    "w": DatabaseConfig.W_CONCERN,
                }

                # Initialize MongoDB client with connection pooling
                cls._client = MongoClient(
                    cfg.mongodb_uri, server_api=ServerApi("1"), **pool_options
                )

                # Test the connection to verify it works
                cls._client.admin.command("ping")

                print("Successfully established MongoDB connection pool")
                return cls._client

            except Exception as e:
                cls._client = None  # Reset on failure
                raise Exception(f"Failed to connect to MongoDB: {str(e)}")

    @classmethod
    def close_connections(cls):
        """Close all connections in the MongoDB client pool."""
        if cls._client is not None:
            cls._client.close()
            cls._client = None
            print("MongoDB connection pool closed")


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
            year=int(time_details["year"]),
            month=int(time_details["month"]),
            day=int(time_details["day"]),
        )

        day = date_obj.day
        suffix = (
            "th" if 11 <= day <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
        )

        return date_obj.strftime(f"%d{suffix} %b (%a)")

    @staticmethod
    def get_formatted_date_without_day(time_details: Dict) -> Optional[str]:
        """Format date using datetime module.

        Args:
            time_details: Dictionary with day, month, and year.

        Returns:
            Formatted date string (e.g., "07th Feb Thu").
        """
        if time_details["day"] is None:
            return None
        if time_details["month"] is None:
            return None
        if time_details["year"] is None:
            return None
        date_obj = datetime(
            year=int(time_details["year"]),
            month=int(time_details["month"]),
            day=int(time_details["day"]),
        )

        day = date_obj.day
        suffix = (
            "th" if 11 <= day <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
        )

        return date_obj.strftime(f"%d{suffix} %b")

    @staticmethod
    def get_formatted_date_with_day(time_details: Dict) -> str:
        """Format date using datetime module.

        Args:
            time_details: Dictionary with day, month, and year.

        Returns:
            Formatted date string (e.g., "07th Feb Thu").
        """
        date_obj = datetime(
            year=int(time_details["year"]),
            month=int(time_details["month"]),
            day=int(time_details["day"]),
        )

        day = date_obj.day
        suffix = (
            "th" if 11 <= day <= 13 else {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")
        )

        return [date_obj.strftime(f"%d{suffix} %b (%a)"), date_obj.strftime(f"%A")]

    @staticmethod
    def get_formatted_time(time_details: Dict) -> str:
        """Format time range from time details dictionary.

        Args:
            time_details: Dictionary with start_time and end_time

        Returns:
            Formatted time range string (e.g., "6:00 PM - 7:30 PM")
        """
        start_time = time_details["start_time"]
        end_time = time_details["end_time"]
        if start_time is None or start_time == "":
            return "TBA"

        start_time, start_format = start_time.split(" ")
        start_time_hour = start_time.split(":")[0].lstrip("0")
        start_time_minute = start_time.split(":")[1].lstrip("0")
        start_time_str = (
            f"{start_time_hour}:{start_time_minute}"
            if start_time_minute
            else start_time_hour
        )

        if end_time is None or end_time == "":
            return f"{start_time_str} {start_format}"

        end_time, end_format = end_time.split(" ")
        end_time_hour = end_time.split(":")[0].lstrip("0")
        end_time_minute = end_time.split(":")[1].lstrip("0")
        end_time_str = (
            f"{end_time_hour}:{end_time_minute}" if end_time_minute else end_time_hour
        )

        if start_format == end_format:
            return f"{start_time_str}-{end_time_str} {start_format}"
        else:
            return f"{start_time_str} {start_format} - {end_time_str} {end_format}"

    @staticmethod
    def get_timestamp_epoch(time_details: Dict) -> int:
        """Calculate Unix timestamp (epoch) from time details.

        Args:
            time_details: Dictionary with day, month, year, and start_time

        Returns:
            Unix timestamp (seconds since epoch)
        """
        # Extract date components
        year = int(time_details["year"])
        month = int(time_details["month"])
        day = int(time_details["day"])

        # Parse start_time or default to midnight (12:00 AM)
        start_time = time_details.get("start_time")
        if not start_time:
            hour, minute = 0, 0  # 12:00 AM as default
        else:
            try:
                # Normalize the time string first to handle variations
                time_str = start_time.strip()

                # Try to parse time in 12-hour format with or without leading zeros
                # Example formats: "1:00 PM", "01:00 PM", "11:00 AM"
                if "AM" in time_str or "PM" in time_str:
                    # Convert to standard format with leading zeros if needed
                    time_parts = (
                        time_str.replace("AM", "").replace("PM", "").strip().split(":")
                    )
                    if len(time_parts[0]) == 1:
                        # Add leading zero if hour is single digit
                        time_str = f"0{time_str}"

                    # Now parse with standard 12-hour format
                    time_obj = datetime.strptime(time_str, "%I:%M %p")
                    hour, minute = time_obj.hour, time_obj.minute
                # Try 24-hour format (e.g., "18:00")
                else:
                    time_obj = datetime.strptime(time_str, "%H:%M")
                    hour, minute = time_obj.hour, time_obj.minute
            except ValueError as e:
                print(
                    f"Warning: Could not parse time '{start_time}': {e}. Using midnight."
                )
                # If all parsing fails, default to midnight
                hour, minute = 0, 0

        # Create datetime object and convert to timestamp
        dt = datetime(year, month, day, hour, minute)
        return int(dt.timestamp())

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
        """Capture full page screenshot of a URL in desktop view.

        Args:
            url: Website URL to capture
            output_file: Path to save the screenshot

        Returns:
            True if successful, False otherwise
        """
        service = Service(ChromeDriverManager().install())
        chrome_options = webdriver.ChromeOptions()

        # Add basic Chrome options
        for option in BrowserConfig.CHROME_OPTIONS:
            chrome_options.add_argument(option)
        
        # Force desktop user agent
        chrome_options.add_argument(f"--user-agent={BrowserConfig.DESKTOP_USER_AGENT}")
        
        # Set initial window size to desktop dimensions
        chrome_options.add_argument(f"--window-size={BrowserConfig.WINDOW_WIDTH},{BrowserConfig.WINDOW_HEIGHT}")
        
        # Additional options to ensure desktop view
        chrome_options.add_argument("--force-device-scale-factor=1")
        chrome_options.add_argument("--disable-mobile-emulation")

        driver = webdriver.Chrome(service=service, options=chrome_options)
        success = False

        try:
            # Set desktop window size before loading page
            driver.set_window_size(BrowserConfig.WINDOW_WIDTH, BrowserConfig.WINDOW_HEIGHT)
            
            # Load the page
            driver.get(url)
            WebDriverWait(driver, BrowserConfig.PAGE_LOAD_TIMEOUT).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )

            # Get page dimensions after loading
            total_width = driver.execute_script("return document.body.scrollWidth")
            total_height = driver.execute_script("return document.body.scrollHeight")
            
            # Ensure minimum desktop width for responsive sites
            final_width = max(total_width, BrowserConfig.WINDOW_WIDTH)
            final_height = max(total_height, BrowserConfig.WINDOW_HEIGHT)
            
            # Set final dimensions for full page capture
            driver.set_window_size(final_width, final_height)
            
            # Wait a moment for any responsive layout changes
            time.sleep(1)

            driver.save_screenshot(output_file)
            success = True
            # print(f"Screenshot captured: {final_width}x{final_height} pixels")
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
            "accept": "application/json",
            "x-magicapi-key": ImageConfig.MAGIC_API_KEY,
        }

        try:
            with open(screenshot_path, "rb") as file:
                files = {"filename": (screenshot_path, file, "image/png")}
                response = requests.post(
                    ImageConfig.UPLOAD_ENDPOINT, headers=headers, files=files
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
            # Add browser-like headers to avoid 403 Forbidden errors
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
            }
            response = requests.get(url, headers=headers, timeout=timeout)
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
                    if not href or href.startswith(
                        ("javascript:", "mailto:", "tel:", "#")
                    ):
                        continue

                    # Handle protocol-relative URLs (//example.com)
                    if href.startswith("//"):
                        href = f"https:{href}"

                    absolute_url = urljoin(base_url, href)
                    parsed_url = urlparse(absolute_url)

                    # Skip non-HTTP(S) protocols
                    if parsed_url.scheme not in ("http", "https"):
                        continue

                    # Normalize URL
                    normalized_url = parsed_url._replace(
                        fragment="",  # Remove fragments
                        params="",  # Remove params
                        query="",  # Remove query strings if needed
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
        content_type = response.headers.get("Content-Type", "").lower()
        if not content_type.startswith("image/"):
            return False

        # Optionally check content length if needed
        content_length = response.headers.get("Content-Length")
        if content_length and int(content_length) == 0:
            return False

        return True
    except Exception:
        return False


# Convenience functions
get_mongo_client = DatabaseManager.get_mongo_client
get_formatted_date = DateTimeFormatter.get_formatted_date
get_formatted_date_with_day = DateTimeFormatter.get_formatted_date_with_day
get_formatted_date_without_day = DateTimeFormatter.get_formatted_date_without_day
get_formatted_time = DateTimeFormatter.get_formatted_time
get_timestamp_epoch = DateTimeFormatter.get_timestamp_epoch
get_current_timestamp = DateTimeFormatter.get_current_timestamp
fetch_url = URLManager.fetch_url
extract_links = URLManager.extract_links
capture_screenshot = ScreenshotManager.capture_screenshot
upload_screenshot = ScreenshotManager.upload_screenshot
is_image_downloadable = is_image_downloadable


# --- Change Stream Cache Invalidation ---
def start_cache_invalidation_watcher():
    import config
    import threading
    import requests

    # Use the connection pool instead of creating a new connection
    client = DatabaseManager.get_mongo_client()
    db = client["discovery"]

    def process_hot_reload_queue():
        global is_hot_reload_running
        while True:
            try:
                # Wait for items in the queue
                hot_reload_queue.get()

                # If there are more items, clear them and just keep one
                while not hot_reload_queue.empty():
                    hot_reload_queue.get()

                with hot_reload_lock:
                    is_hot_reload_running = True
                    try:
                        # Call internal API endpoints to repopulate cache
                        artist_ids = list(set(db["artists_v2"].distinct("artist_id")))
                        studio_ids = list(set(db["studios"].distinct("studio_id")))

                        # Call internal api endpoints
                        endpoints = [
                            "http://localhost:8002/api/studios?version=v2",
                            "http://localhost:8002/api/workshops?version=v2",
                            "http://localhost:8002/api/artists?version=v2",
                        ]

                        for studio_id in studio_ids:
                            endpoints.append(
                                f"http://localhost:8002/api/workshops_by_studio/{studio_id}?version=v2"
                            )
                        for artist_id in artist_ids:
                            endpoints.append(
                                f"http://localhost:8002/api/workshops_by_artist/{artist_id}?version=v2"
                            )

                        for url in endpoints:
                            try:
                                requests.get(url, timeout=10)
                            except Exception as e:
                                print(f"Cache hot reload failed for {url}: {e}")

                        print("Cache hot reload completed")
                    except Exception as e:
                        print(f"Hot reload cache error: {e}")
                    finally:
                        is_hot_reload_running = False

            except Exception as e:
                print(f"Error in process_hot_reload_queue: {e}")
                is_hot_reload_running = False

    def watch_collection(collection):
        pipeline = [
            {
                "$match": {
                    "operationType": {"$in": ["insert", "update", "replace", "delete"]}
                }
            }
        ]
        try:
            with collection.watch(
                pipeline=pipeline, full_document="updateLookup"
            ) as stream:
                for change in stream:
                    print(
                        f"Change detected in {collection.name}: {change['operationType']}"
                    )
                    cache.clear()
                    # Add hot reload request to queue instead of starting immediately
                    hot_reload_queue.put(True)
        except Exception as e:
            print(f"Change stream watcher error for {collection.name}: {e}")

    def watch_changes():
        collections = ["studios", "artists_v2", "workshops_v2"]
        for coll_name in collections:
            coll = db[coll_name]
            threading.Thread(target=watch_collection, args=(coll,), daemon=True).start()

    # Start the queue processor thread
    threading.Thread(target=process_hot_reload_queue, daemon=True).start()

    # Start the change watcher threads
    threading.Thread(target=watch_changes, daemon=True).start()

    # Initial cache warmup
    hot_reload_queue.put(True)
