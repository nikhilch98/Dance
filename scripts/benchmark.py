"""Benchmark script for measuring performance of populate scripts.

This module provides benchmarking functionality to measure and analyze
the performance of various components in the populate scripts.
"""

import time
import statistics
from dataclasses import dataclass
from typing import List, Dict, Any, Callable
import concurrent.futures
from functools import wraps
import json
from datetime import datetime

from tqdm import tqdm

from populate_artists import InstagramAPI, ArtistManager, Artist
from populate_workshops import WorkshopProcessor, StudioProcessor
from utils.utils import DatabaseManager, ScreenshotManager
from studios.dna import DnaStudio
from studios.dance_inn import DanceInnStudio
from studios.vins import VinsStudio
from studios.manifest import ManifestStudio


@dataclass
class BenchmarkResult:
    """Container for benchmark results."""

    component: str
    operation: str
    iterations: int
    times: List[float]
    success_rate: float
    errors: List[str]

    @property
    def avg_time(self) -> float:
        """Calculate average execution time."""
        return statistics.mean(self.times) if self.times else 0

    @property
    def min_time(self) -> float:
        """Get minimum execution time."""
        return min(self.times) if self.times else 0

    @property
    def max_time(self) -> float:
        """Get maximum execution time."""
        return max(self.times) if self.times else 0

    @property
    def std_dev(self) -> float:
        """Calculate standard deviation of execution times."""
        return statistics.stdev(self.times) if len(self.times) > 1 else 0

    def to_dict(self) -> Dict:
        """Convert result to dictionary format."""
        return {
            "component": self.component,
            "operation": self.operation,
            "iterations": self.iterations,
            "average_time": self.avg_time,
            "min_time": self.min_time,
            "max_time": self.max_time,
            "std_dev": self.std_dev,
            "success_rate": self.success_rate,
            "error_count": len(self.errors),
        }


class Benchmarker:
    """Benchmark runner and result analyzer."""

    def __init__(self, iterations: int = 5):
        """Initialize benchmarker.

        Args:
            iterations: Number of times to run each benchmark
        """
        self.iterations = iterations
        self.results: List[BenchmarkResult] = []

    def benchmark(self, component: str, operation: str) -> Callable:
        """Decorator for benchmarking functions.

        Args:
            component: Component name
            operation: Operation being benchmarked

        Returns:
            Decorated function
        """

        def decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(*args, **kwargs) -> Any:
                times = []
                errors = []
                successes = 0

                for _ in range(self.iterations):
                    try:
                        start = time.perf_counter()
                        result = func(*args, **kwargs)
                        end = time.perf_counter()
                        times.append(end - start)
                        successes += 1
                    except Exception as e:
                        errors.append(str(e))

                self.results.append(
                    BenchmarkResult(
                        component=component,
                        operation=operation,
                        iterations=self.iterations,
                        times=times,
                        success_rate=successes / self.iterations,
                        errors=errors,
                    )
                )
                return result

            return wrapper

        return decorator

    def save_results(self, filename: str = None) -> None:
        """Save benchmark results to file.

        Args:
            filename: Output filename (default: benchmark_results_{timestamp}.json)
        """
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"benchmark_results_{timestamp}.json"

        results = [result.to_dict() for result in self.results]

        with open(filename, "w") as f:
            json.dump(results, f, indent=2)


class ComponentBenchmarks:
    """Benchmark implementations for different components."""

    def __init__(self, benchmarker: Benchmarker):
        """Initialize component benchmarks.

        Args:
            benchmarker: Benchmarker instance
        """
        self.benchmarker = benchmarker
        self.db = DatabaseManager.get_mongo_client()

    @property
    def instagram_api(self) -> InstagramAPI:
        """Get Instagram API instance."""
        return InstagramAPI()

    @property
    def artist_manager(self) -> ArtistManager:
        """Get ArtistManager instance."""
        return ArtistManager()

    def run_artist_benchmarks(self) -> None:
        """Run benchmarks for artist-related operations."""
        print("\nRunning Artist Component Benchmarks...")

        # Instagram API
        self.benchmark_instagram_profile()

        # Artist Manager
        self.benchmark_artist_operations()

    def run_workshop_benchmarks(self) -> None:
        """Run benchmarks for workshop-related operations."""
        print("\nRunning Workshop Component Benchmarks...")

        # Screenshot operations
        self.benchmark_screenshot_operations()

        # Workshop processing
        self.benchmark_workshop_operations()

        # Studio operations
        self.benchmark_studio_operations()

    @benchmarker.benchmark("InstagramAPI", "fetch_profile")
    def benchmark_instagram_profile(self) -> None:
        """Benchmark Instagram profile fetching."""
        test_users = ["aadilkhann", "deepaktulsyan", "jaysharma_ruh"]
        for user in test_users:
            self.instagram_api.fetch_profile_picture_hd(user)

    @benchmarker.benchmark("ArtistManager", "database_operations")
    def benchmark_artist_operations(self) -> None:
        """Benchmark artist database operations."""
        test_artist = Artist("Test Artist", "test_handle")
        manager = self.artist_manager

        # Test various operations
        manager.get_existing_image(test_artist.instagram_id)
        manager.update_artist(test_artist)

    @benchmarker.benchmark("ScreenshotManager", "capture_and_upload")
    def benchmark_screenshot_operations(self) -> None:
        """Benchmark screenshot operations."""
        test_url = "https://www.example.com"
        test_path = "test_screenshot.png"

        ScreenshotManager.capture_screenshot(test_url, test_path)
        if os.path.exists(test_path):
            ScreenshotManager.upload_screenshot(test_path)
            os.remove(test_path)

    @benchmarker.benchmark("WorkshopProcessor", "process_link")
    def benchmark_workshop_operations(self) -> None:
        """Benchmark workshop processing operations."""
        processor = WorkshopProcessor(
            client=None, artists=[], mongo_client=self.db  # Mock for benchmark
        )

        test_links = [
            "https://www.example.com/workshop1",
            "https://www.example.com/workshop2",
        ]

        for link in test_links:
            processor.process_link(link, Mock())

    @benchmarker.benchmark("StudioProcessor", "scrape_links")
    def benchmark_studio_operations(self) -> None:
        """Benchmark studio operations."""
        studios = [
            DnaStudio(
                "https://www.example.com",
                "test_studio",
                "https://www.example.com/events/",
                max_depth=1,
            ),
            DanceInnStudio(
                "https://www.example.com",
                "test_studio",
                "https://www.example.com/events/",
                max_depth=1,
            ),
        ]

        for studio in studios:
            studio.scrape_links()


def main():
    """Main benchmark execution function."""
    print("Starting Performance Benchmarks...")

    # Initialize benchmarker
    benchmarker = Benchmarker(iterations=5)
    component_benchmarks = ComponentBenchmarks(benchmarker)

    # Run benchmarks
    component_benchmarks.run_artist_benchmarks()
    component_benchmarks.run_workshop_benchmarks()

    # Save results
    benchmarker.save_results()

    print("\nBenchmark Results Summary:")
    for result in benchmarker.results:
        print(f"\nComponent: {result.component}")
        print(f"Operation: {result.operation}")
        print(f"Average Time: {result.avg_time:.3f}s")
        print(f"Min Time: {result.min_time:.3f}s")
        print(f"Max Time: {result.max_time:.3f}s")
        print(f"Success Rate: {result.success_rate * 100:.1f}%")
        if result.errors:
            print(f"Errors: {len(result.errors)}")


if __name__ == "__main__":
    main()
