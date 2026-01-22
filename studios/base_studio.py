"""Base studio implementation for scraping dance workshop links.

This module provides an abstract base class that defines the common functionality
for scraping workshop links from different dance studio websites. It implements
a breadth-first crawling strategy with concurrent requests for better performance.
"""

from abc import ABC, abstractmethod
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import List, Set, Tuple, Dict, Optional
from urllib.parse import urlparse

from tqdm import tqdm

from utils.utils import fetch_url, extract_links


@dataclass
class StudioConfig:
    """Configuration for a dance studio website crawler.

    Attributes:
        start_url: The initial URL to start crawling from
        studio_id: Unique identifier for the studio
        regex_match_link: Pattern to match valid workshop links
        max_depth: Maximum depth for crawling (default: 3)
        max_workers: Maximum number of concurrent workers (default: 5)
    """

    start_url: str
    studio_id: str
    regex_match_link: str
    max_depth: int = 3
    max_workers: int = 5

    def validate(self) -> None:
        """Validates the configuration parameters.

        Raises:
            ValueError: If any configuration parameter is invalid
        """
        if not self.start_url:
            raise ValueError("start_url cannot be empty")
        if not self.studio_id:
            raise ValueError("studio_id cannot be empty")
        if not self.regex_match_link:
            raise ValueError("regex_match_link cannot be empty")
        if self.max_depth < 1:
            raise ValueError("max_depth must be at least 1")
        if self.max_workers < 1:
            raise ValueError("max_workers must be at least 1")


class BaseStudio(ABC):
    """Abstract base class for dance studio website crawlers.

    This class implements the core crawling functionality while allowing
    studio-specific implementations to override or extend the behavior
    as needed.
    """

    def __init__(self, config: StudioConfig):
        """Initialize the studio crawler with the given configuration.

        Args:
            config: Configuration parameters for the crawler

        Raises:
            ValueError: If the configuration is invalid
        """
        config.validate()
        self.config = config
        self._domain = urlparse(config.start_url).netloc

    def _process_html_response(
        self, html: str, url: str, depth: int, visited: Set[str], queue: deque
    ) -> None:
        """Process HTML response and extract new links to crawl.

        Args:
            html: The HTML content to process
            url: The URL the HTML was fetched from
            depth: Current crawl depth
            visited: Set of already visited URLs
            queue: Queue of URLs to crawl
        """
        if depth < self.config.max_depth:
            new_links = extract_links(html, url, self._domain)
            for link in new_links:
                if link not in visited:
                    visited.add(link)
                    queue.append((link, depth + 1))

    def _create_futures(
        self, queue: deque, size: int, executor: ThreadPoolExecutor
    ) -> Dict:
        """Create futures for concurrent URL fetching.

        Args:
            queue: Queue of URLs to process
            size: Number of URLs to process in this batch
            executor: ThreadPoolExecutor instance

        Returns:
            Dict mapping futures to their corresponding URLs
        """
        return {
            executor.submit(fetch_url, url): (url, depth)
            for url, depth in list(queue)[:size]
        }

    def _filter_workshop_links(self, successful_links: Set[str]) -> List[str]:
        """Filter links to only include valid workshop URLs.

        Args:
            successful_links: Set of all successfully crawled URLs

        Returns:
            List of URLs that match the workshop link pattern
        """

        return list(
            set(
                [
                    link.lower()
                    for link in successful_links
                    if link.startswith(self.config.regex_match_link)
                ]
            )
        )

    @abstractmethod
    def scrape_links(self) -> List[str]:
        """Scrape workshop links from the studio website.

        This method implements a breadth-first crawling strategy with concurrent
        requests for better performance. It can be overridden by studio-specific
        implementations if needed.

        Returns:
            List of workshop registration links

        Raises:
            Exception: If an error occurs during scraping
        """
        try:
            queue = deque([(self.config.start_url, 0)])
            visited = set([self.config.start_url])
            successful_links = set()

            while queue:
                current_level_size = len(queue)
                current_depth = queue[0][1]

                with ThreadPoolExecutor(
                    max_workers=self.config.max_workers
                ) as executor:
                    futures = self._create_futures(queue, current_level_size, executor)

                    with tqdm(
                        total=current_level_size,
                        desc=f"{self.config.studio_id} | Depth {current_depth}",
                        leave=False,
                    ) as pbar:
                        for future in as_completed(futures):
                            url, depth = futures[future]
                            queue.popleft()

                            try:
                                result = future.result()
                                if result and result[1]:  # Check if HTML content exists
                                    successful_links.add(url)
                                    self._process_html_response(
                                        result[1], url, depth, visited, queue
                                    )
                            except Exception as e:
                                print(f"Error processing {url}: {str(e)}")
                            finally:
                                pbar.update(1)
            return self._filter_workshop_links(successful_links)

        except Exception as e:
            print(f"Error scraping links for {self.config.studio_id}: {str(e)}")
            return []
