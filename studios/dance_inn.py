"""Dance Inn studio implementation for workshop link scraping.

This module provides the Dance Inn specific implementation of the base studio
crawler. It inherits from BaseStudio and uses the default scraping behavior.
"""

from typing import List

from utils import utils

from .base_studio import BaseStudio, StudioConfig

from bs4 import BeautifulSoup

class DanceInnStudio(BaseStudio):
    """Dance Inn studio crawler implementation.
    
    This class uses the default scraping behavior from BaseStudio as the
    standard crawling approach works well for the Dance Inn website structure.
    """

    def __init__(self, start_url: str, studio_id: str, regex_match_link: str,
                 max_depth: int = 3, max_workers: int = 5):
        """Initialize the Dance Inn studio crawler.

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
            max_workers=max_workers
        )
        super().__init__(config)

    def scrape_links(self) -> List[str]:
        """Scrape workshop links from the Dance Inn website.

        Returns:
            List of workshop registration links
        """
        _, response = utils.fetch_url(self.config.start_url)
        if not response:
            print(f"No links found for studio {self.config.studio_id}")
            return []

        soup = BeautifulSoup(response, "html.parser")
        links = [a_tag["href"] for a_tag in soup.find_all('a', href=True)]
        return self._filter_workshop_links(links)