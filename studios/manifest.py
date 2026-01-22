"""Manifest studio implementation for workshop link scraping.

This module provides the Manifest specific implementation of the base studio
crawler. It uses Selenium to handle JavaScript-rendered content.
"""
import re
from typing import List
from .base_studio import BaseStudio, StudioConfig
from utils.utils import fetch_url_with_selenium, extract_links


class ManifestStudio(BaseStudio):
    """Manifest studio crawler implementation.

    This class uses Selenium to scrape JavaScript-rendered content from
    the Manifest website, as the site requires JavaScript execution.
    """

    def __init__(
        self,
        start_url: str,
        studio_id: str,
        regex_match_link: str,
        max_depth: int = 3,
        max_workers: int = 5,
    ):
        """Initialize the Manifest studio crawler.

        Args:
            start_url: The initial URL to start crawling from
            studio_id: Unique identifier for the studio
            regex_match_link: Pattern to match valid workshop links
            max_depth: Maximum depth for crawling (default: 3)
            max_workers: Maximum number of concurrent workers (default: 5, not used for Selenium)
        """
        config = StudioConfig(
            start_url=start_url,
            studio_id=studio_id,
            regex_match_link=regex_match_link,
            max_depth=max_depth,
            max_workers=max_workers,
        )
        super().__init__(config)

    def scrape_links(self) -> List[str]:
        """Scrape workshop links from the Manifest website using Selenium.

        This method overrides the base implementation to use Selenium for
        JavaScript-rendered content.

        Returns:
            List of workshop registration links
        """
        try:
            # Use Selenium to fetch the initial page (JavaScript-rendered)
            # Timeout of 30 seconds for page load
            url, html = fetch_url_with_selenium(self.config.start_url, timeout=30)
            
            if not html:
                print(f"Failed to fetch {self.config.start_url} with Selenium")
                return []

            links = re.findall(r'href="(/workshops/[^"]+)"', html)
            # Join with domain if needed (assuming relative URLs)
            base_url = re.match(r'(https?://[^/]+)', url)
            if base_url:
                links = [base_url.group(1) + link for link in links]
            return links
        except Exception as e:
            print(f"Error in scrape_links: {e}")
            return []
