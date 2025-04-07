"""Optimizations for the populate scripts.

This module provides optimized versions of key components with improved
parallelization and performance enhancements.
"""

import asyncio
import aiohttp
import time
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from dataclasses import dataclass
from typing import List, Dict, Any, Optional, Set
from functools import partial

from motor.motor_asyncio import AsyncIOMotorClient
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from utils.utils import DatabaseManager, ScreenshotManager

@dataclass
class OptimizationConfig:
    """Configuration for optimization settings."""
    max_concurrent_requests: int = 10
    connection_timeout: int = 30
    max_retries: int = 3
    chunk_size: int = 1000
    process_pool_size: int = 4
    thread_pool_size: int = 8

class AsyncInstagramAPI:
    """Asynchronous Instagram API client."""

    def __init__(self, config: OptimizationConfig):
        """Initialize async Instagram client.
        
        Args:
            config: Optimization configuration
        """
        self.config = config
        self.session = None
        self.headers = {
            "x-ig-app-id": "936619743392459",
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/62.0.3202.94 Safari/537.36"
            ),
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept": "*/*"
        }

    async def __aenter__(self):
        """Create aiohttp session."""
        self.session = aiohttp.ClientSession(
            headers=self.headers,
            timeout=aiohttp.ClientTimeout(total=self.config.connection_timeout)
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Close aiohttp session."""
        if self.session:
            await self.session.close()

    async def fetch_profile_picture_hd(self, username: str) -> Optional[str]:
        """Fetch HD profile picture URL asynchronously.
        
        Args:
            username: Instagram username
            
        Returns:
            HD profile picture URL or None if fetch fails
        """
        url = f"https://i.instagram.com/api/v1/users/web_profile_info/?username={username}"
        
        for attempt in range(self.config.max_retries):
            try:
                async with self.session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data["data"]["user"]["profile_pic_url_hd"]
            except Exception as e:
                if attempt == self.config.max_retries - 1:
                    print(f"Failed to fetch data for {username} after {self.config.max_retries} attempts: {str(e)}")
            await asyncio.sleep(1)  # Rate limiting
        return None

class AsyncDatabaseManager:
    """Asynchronous database operations manager."""

    def __init__(self, config: OptimizationConfig):
        """Initialize async database manager.
        
        Args:
            config: Optimization configuration
        """
        self.config = config
        self.client = AsyncIOMotorClient()
        self.db = self.client.discovery

    async def bulk_update_artists(self, artists: List[Dict]) -> None:
        """Perform bulk artist updates asynchronously.
        
        Args:
            artists: List of artist data to update
        """
        operations = [
            {
                "update_one": {
                    "filter": {"artist_id": artist["artist_id"]},
                    "update": {"$set": artist},
                    "upsert": True
                }
            }
            for artist in artists
        ]
        
        # Process in chunks for better performance
        for i in range(0, len(operations), self.config.chunk_size):
            chunk = operations[i:i + self.config.chunk_size]
            await self.db.artists_v2.bulk_write(chunk, ordered=False)

    async def bulk_update_workshops(self, workshops: List[Dict]) -> None:
        """Perform bulk workshop updates asynchronously.
        
        Args:
            workshops: List of workshop data to update
        """
        operations = [
            {
                "update_one": {
                    "filter": {"uuid": workshop["uuid"]},
                    "update": {"$set": workshop},
                    "upsert": True
                }
            }
            for workshop in workshops
        ]
        
        for i in range(0, len(operations), self.config.chunk_size):
            chunk = operations[i:i + self.config.chunk_size]
            await self.db.workshops_v2.bulk_write(chunk, ordered=False)

class ParallelScreenshotManager:
    """Parallel screenshot capture and management."""

    def __init__(self, config: OptimizationConfig):
        """Initialize parallel screenshot manager.
        
        Args:
            config: Optimization configuration
        """
        self.config = config
        self.chrome_options = Options()
        for option in [
            '--headless',
            '--no-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--disable-software-rasterizer'
        ]:
            self.chrome_options.add_argument(option)

    def capture_screenshots_parallel(self, urls: List[str]) -> Dict[str, str]:
        """Capture multiple screenshots in parallel.
        
        Args:
            urls: List of URLs to capture
            
        Returns:
            Dictionary mapping URLs to screenshot paths
        """
        with ProcessPoolExecutor(max_workers=self.config.process_pool_size) as executor:
            futures = {
                executor.submit(
                    self._capture_single_screenshot,
                    url,
                    f"screenshots/{hash(url)}.png"
                ): url
                for url in urls
            }
            
            results = {}
            for future in futures:
                url = futures[future]
                try:
                    screenshot_path = future.result()
                    if screenshot_path:
                        results[url] = screenshot_path
                except Exception as e:
                    print(f"Failed to capture screenshot for {url}: {str(e)}")
            
            return results

    def _capture_single_screenshot(self, url: str, output_path: str) -> Optional[str]:
        """Capture single screenshot with optimized settings.
        
        Args:
            url: URL to capture
            output_path: Path to save screenshot
            
        Returns:
            Screenshot path if successful, None otherwise
        """
        driver = None
        try:
            driver = webdriver.Chrome(options=self.chrome_options)
            driver.set_window_size(1920, 1080)
            driver.get(url)
            
            # Wait for page load with timeout
            WebDriverWait(driver, 10).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )
            
            # Capture full page
            total_height = driver.execute_script("return document.body.scrollHeight")
            driver.set_window_size(1920, total_height)
            driver.save_screenshot(output_path)
            
            return output_path
        except Exception as e:
            print(f"Screenshot capture failed: {str(e)}")
            return None
        finally:
            if driver:
                driver.quit()

class AsyncWorkshopProcessor:
    """Asynchronous workshop processing system."""

    def __init__(
        self,
        config: OptimizationConfig,
        db_manager: AsyncDatabaseManager,
        screenshot_manager: ParallelScreenshotManager
    ):
        """Initialize async workshop processor.
        
        Args:
            config: Optimization configuration
            db_manager: Async database manager
            screenshot_manager: Parallel screenshot manager
        """
        self.config = config
        self.db_manager = db_manager
        self.screenshot_manager = screenshot_manager

    async def process_workshops_batch(self, links: Set[str], studio_id: str) -> None:
        """Process multiple workshops in parallel.
        
        Args:
            links: Set of workshop links to process
            studio_id: Studio identifier
        """
        # Capture screenshots in parallel
        screenshot_paths = self.screenshot_manager.capture_screenshots_parallel(links)
        
        # Process screenshots in parallel
        with ThreadPoolExecutor(max_workers=self.config.thread_pool_size) as executor:
            futures = []
            for url, path in screenshot_paths.items():
                futures.append(
                    executor.submit(
                        self._process_single_workshop,
                        url,
                        path,
                        studio_id
                    )
                )
            
            # Collect results
            workshops = []
            for future in futures:
                try:
                    result = future.result()
                    if result:
                        workshops.append(result)
                except Exception as e:
                    print(f"Workshop processing failed: {str(e)}")
            
            # Bulk update database
            if workshops:
                await self.db_manager.bulk_update_workshops(workshops)

    def _process_single_workshop(
        self,
        url: str,
        screenshot_path: str,
        studio_id: str
    ) -> Optional[Dict]:
        """Process single workshop with optimized settings.
        
        Args:
            url: Workshop URL
            screenshot_path: Path to workshop screenshot
            studio_id: Studio identifier
            
        Returns:
            Workshop data if successful, None otherwise
        """
        try:
            # Upload screenshot
            upload_result = ScreenshotManager.upload_screenshot(screenshot_path)
            if not upload_result or "url" not in upload_result:
                return None
            
            # Process with GPT (implementation depends on OpenAI client)
            # This would need to be adapted based on the specific GPT client being used
            
            return {
                "uuid": f"{studio_id}/{hash(url)}",
                "payment_link": url,
                "studio_id": studio_id,
                # Additional workshop details would be added here
                "updated_at": time.time()
            }
        except Exception as e:
            print(f"Workshop processing failed: {str(e)}")
            return None

# Usage example:
"""
async def main():
    config = OptimizationConfig()
    db_manager = AsyncDatabaseManager(config)
    screenshot_manager = ParallelScreenshotManager(config)
    processor = AsyncWorkshopProcessor(config, db_manager, screenshot_manager)
    
    async with AsyncInstagramAPI(config) as api:
        # Process artists
        usernames = ["user1", "user2", "user3"]
        tasks = [api.fetch_profile_picture_hd(username) for username in usernames]
        results = await asyncio.gather(*tasks)
        
        # Process workshops
        links = {"http://example.com/workshop1", "http://example.com/workshop2"}
        await processor.process_workshops_batch(links, "studio1")

if __name__ == "__main__":
    asyncio.run(main())
"""