"""Vins Dance Co studio implementation for workshop link scraping.

This module provides the Vins Dance Co specific implementation of the base studio
crawler. It inherits from BaseStudio and uses Selenium for JavaScript-rendered content.
"""

import re
from typing import List

from utils.utils import fetch_url_with_selenium
from .base_studio import BaseStudio, StudioConfig


class VinsStudio(BaseStudio):
    """Vins Dance Co studio crawler implementation.

    This class uses Selenium to handle the JavaScript-rendered website content,
    as the Vins Dance Co website dynamically loads workshop links.
    """

    def __init__(
        self,
        start_url: str,
        studio_id: str,
        regex_match_link: str,
        max_depth: int = 3,
        max_workers: int = 5,
    ):
        """Initialize the Vins Dance Co studio crawler.

        Args:
            start_url: The initial URL to start crawling from
            studio_id: Unique identifier for the studio
            regex_match_link: Pattern to match valid workshop links
            max_depth: Maximum depth for crawling (default: 3)
            max_workers: Maximum number of concurrent workers (default: 5)
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
        """Scrape workshop links from the Vins Dance Co website using Selenium.

        This method overrides the base implementation to use Selenium for
        JavaScript-rendered content.

        Returns:
            List of workshop registration links
        """
        try:
            # Use Selenium to fetch the page (JavaScript-rendered)
            # Timeout of 30 seconds for page load
            url, html = fetch_url_with_selenium(self.config.start_url, timeout=30)
            
            if not html:
                print(f"No HTML content fetched for {self.config.studio_id}")
                return []
            
            # Extract event links matching the pattern
            pattern = re.escape(self.config.regex_match_link) + r'[^"\'\s>]+'
            event_links = re.findall(pattern, html)
            
            # Deduplicate and return
            unique_links = list(set(event_links))
            print(f"Found {len(unique_links)} workshop links for {self.config.studio_id}")
            return unique_links
            
        except Exception as e:
            print(f"Error scraping links for {self.config.studio_id}: {str(e)}")
            return []
