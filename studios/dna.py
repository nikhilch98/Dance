"""DNA (Dance N Addiction) studio implementation for workshop link scraping.

This module provides the DNA specific implementation of the base studio
crawler. It inherits from BaseStudio and uses the default scraping behavior.
"""

from typing import List

from .base_studio import BaseStudio, StudioConfig

class DnaStudio(BaseStudio):
    """DNA (Dance N Addiction) studio crawler implementation.
    
    This class uses the default scraping behavior from BaseStudio as the
    standard crawling approach works well for the DNA website structure.
    """

    def __init__(self, start_url: str, studio_id: str, regex_match_link: str,
                 max_depth: int = 3, max_workers: int = 5):
        """Initialize the DNA studio crawler.

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
        """Scrape workshop links from the DNA website.

        Returns:
            List of workshop registration links
        """
        return super().scrape_links()