#!/usr/bin/env python3
"""
Background processing script for downloading Instagram reels.

This script is designed to run as a cron job to process
unprocessed choreo_links and download their videos.

Usage:
    # Run normally (processes unprocessed links)
    python scripts/process_choreo_videos.py
    
    # Include failed links for retry
    python scripts/process_choreo_videos.py --include-retries
    
    # Process specific batch size
    python scripts/process_choreo_videos.py --batch-size 20
    
    # Show status only
    python scripts/process_choreo_videos.py --status

Cron example (run every hour):
    0 * * * * cd /path/to/Dance && python scripts/process_choreo_videos.py >> /var/log/choreo_videos.log 2>&1
"""
import argparse
import sys
import os
from datetime import datetime

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.video_downloader import VideoDownloaderService
from app.database.choreo_links import ChoreoLinksOperations


def print_status():
    """Print current video processing status for active workshops only."""
    counts = ChoreoLinksOperations.count_by_status(active_only=True)
    
    print("\n=== Video Processing Status (Active Workshops Only) ===")
    print(f"Active workshops with Instagram links: {counts.get('active_workshops_with_links', 'N/A')}")
    print(f"Choreo links to process: {counts['total']}")
    print(f"  Unprocessed: {counts['unprocessed']}")
    print(f"  Pending:     {counts['pending']}")
    print(f"  Processing:  {counts['processing']}")
    print(f"  Completed:   {counts['completed']}")
    print(f"  Failed:      {counts['failed']}")
    print("=" * 54)
    
    # Calculate completion percentage
    if counts['total'] > 0:
        completion = (counts['completed'] / counts['total']) * 100
        print(f"Completion: {completion:.1f}%")
    
    # Note about archived workshops
    print("\nNote: Only active (non-archived) workshops are included.")
    print()


def process_videos(batch_size: int, include_retries: bool, dry_run: bool = False):
    """Process a batch of videos."""
    print(f"\n[{datetime.now().isoformat()}] Starting video processing...")
    print(f"  Batch size: {batch_size}")
    print(f"  Include retries: {include_retries}")
    
    if dry_run:
        # Just show what would be processed
        unprocessed = ChoreoLinksOperations.get_unprocessed(limit=batch_size)
        print(f"\n  Would process {len(unprocessed)} unprocessed links")
        
        if include_retries:
            failed = ChoreoLinksOperations.get_failed(limit=batch_size - len(unprocessed))
            print(f"  Would retry {len(failed)} failed links")
        
        for doc in unprocessed[:5]:  # Show first 5
            print(f"    - {doc.get('song', 'Unknown')}: {doc.get('choreo_insta_link', 'N/A')[:50]}...")
        
        if len(unprocessed) > 5:
            print(f"    ... and {len(unprocessed) - 5} more")
        
        return
    
    # Actually process
    downloader = VideoDownloaderService()
    results = downloader.process_batch(
        batch_size=batch_size,
        include_retries=include_retries
    )
    
    print(f"\n  Results:")
    print(f"    Processed: {results['processed']}")
    print(f"    Succeeded: {results['succeeded']}")
    print(f"    Failed:    {results['failed']}")
    
    if results['processed'] > 0:
        success_rate = (results['succeeded'] / results['processed']) * 100
        print(f"    Success rate: {success_rate:.1f}%")
    
    print(f"\n[{datetime.now().isoformat()}] Processing complete.")


def main():
    parser = argparse.ArgumentParser(
        description="Process choreo_links to download Instagram videos"
    )
    parser.add_argument(
        "--batch-size", "-b",
        type=int,
        default=10,
        help="Number of videos to process (default: 10)"
    )
    parser.add_argument(
        "--include-retries", "-r",
        action="store_true",
        help="Include previously failed videos for retry"
    )
    parser.add_argument(
        "--status", "-s",
        action="store_true",
        help="Show processing status and exit"
    )
    parser.add_argument(
        "--dry-run", "-d",
        action="store_true",
        help="Show what would be processed without actually processing"
    )
    
    args = parser.parse_args()
    
    # Show status
    print_status()
    
    if args.status:
        return
    
    # Process videos
    process_videos(
        batch_size=args.batch_size,
        include_retries=args.include_retries,
        dry_run=args.dry_run
    )
    
    # Show updated status
    print_status()


if __name__ == "__main__":
    main()
