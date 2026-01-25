#!/usr/bin/env python3
"""
Clear all processed choreo videos from the database.

This script will:
1. Find all choreo_links with video_status = 'completed'
2. Delete the associated GridFS files
3. Reset the video status fields (optional: to pending or completely remove)

Usage:
    python scripts/clear_processed_videos.py                    # Dry run (show what would be cleared)
    python scripts/clear_processed_videos.py --execute          # Clear all processed videos
    python scripts/clear_processed_videos.py --execute --all    # Include inactive workshops too
    python scripts/clear_processed_videos.py --execute --reset-to-pending  # Reset to pending instead of null
"""
import sys
import os
import argparse
from datetime import datetime

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from utils.utils import get_mongo_client
from app.services.gridfs_service import GridFSService
from app.database.choreo_links import ChoreoLinksOperations


def get_processed_videos(active_only: bool = True, include_failed: bool = False):
    """
    Get all processed video documents.

    Args:
        active_only: Only get videos for active workshops
        include_failed: Also include failed videos

    Returns:
        List of choreo_link documents with completed videos
    """
    client = get_mongo_client()
    choreo_links = client['discovery']['choreo_links']

    statuses = ['completed']
    if include_failed:
        statuses.append('failed')

    query = {
        'video_status': {'$in': statuses}
    }

    # Filter by active workshop links
    if active_only:
        active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
        if active_links:
            query['choreo_insta_link'] = {'$in': list(active_links)}
        else:
            # If no active links, return empty if active_only
            return []

    return list(choreo_links.find(query))


def clear_single_video(doc, reset_to_pending: bool = False):
    """
    Clear a single video from the database.

    Args:
        doc: The choreo_link document
        reset_to_pending: If True, set status to 'pending'; if False, set to None

    Returns:
        Tuple of (success, freed_bytes)
    """
    client = get_mongo_client()
    choreo_links = client['discovery']['choreo_links']

    doc_id = doc['_id']
    gridfs_file_id = doc.get('gridfs_file_id')
    file_size = doc.get('video_file_size', 0)

    # Delete GridFS file
    if gridfs_file_id:
        try:
            GridFSService.delete_video(str(gridfs_file_id))
            print(f"    Deleted GridFS file: {gridfs_file_id}")
        except Exception as e:
            print(f"    Warning: Could not delete GridFS file: {e}")

    # Reset document fields
    if reset_to_pending:
        update = {
            '$set': {
                'video_status': 'pending',
                'video_error': None,
                'video_file_size': None,
                'gridfs_file_id': None,
                'video_processed_at': None
            }
        }
    else:
        update = {
            '$unset': {
                'video_status': '',
                'video_error': '',
                'video_file_size': '',
                'gridfs_file_id': '',
                'video_processed_at': ''
            }
        }

    result = choreo_links.update_one({'_id': doc_id}, update)

    return result.modified_count > 0, file_size


def format_size(bytes_size):
    """Format bytes to human readable string."""
    if bytes_size < 1024:
        return f"{bytes_size} B"
    elif bytes_size < 1024 * 1024:
        return f"{bytes_size / 1024:.2f} KB"
    elif bytes_size < 1024 * 1024 * 1024:
        return f"{bytes_size / 1024 / 1024:.2f} MB"
    else:
        return f"{bytes_size / 1024 / 1024 / 1024:.2f} GB"


def get_status_counts():
    """Get current video status counts."""
    return ChoreoLinksOperations.count_by_status(active_only=False)


def main():
    parser = argparse.ArgumentParser(description='Clear processed choreo videos')
    parser.add_argument('--execute', action='store_true',
                        help='Actually execute the clearing (without this, it\'s a dry run)')
    parser.add_argument('--all', action='store_true',
                        help='Clear ALL processed videos, not just active workshops')
    parser.add_argument('--include-failed', action='store_true',
                        help='Also clear failed videos')
    parser.add_argument('--reset-to-pending', action='store_true',
                        help='Reset status to "pending" instead of removing fields')
    args = parser.parse_args()

    print("=" * 60)
    print("🗑️  CLEAR PROCESSED CHOREO VIDEOS")
    print("=" * 60)
    print(f"   Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    active_only = not args.all

    if active_only:
        print("\n📋 Scope: ACTIVE WORKSHOPS ONLY")
        print("   Use --all to include archived/inactive workshops")
    else:
        print("\n⚠️  Scope: ALL WORKSHOPS (including archived)")

    if args.include_failed:
        print("   Including: completed + failed videos")
    else:
        print("   Including: completed videos only")

    # Show current status counts
    print("\n📊 Current Video Status Counts (all workshops):")
    counts = get_status_counts()
    print(f"   Unprocessed: {counts.get('unprocessed', 0)}")
    print(f"   Pending:     {counts.get('pending', 0)}")
    print(f"   Processing:  {counts.get('processing', 0)}")
    print(f"   Completed:   {counts.get('completed', 0)}")
    print(f"   Failed:      {counts.get('failed', 0)}")
    print(f"   Total:       {counts.get('total', 0)}")

    # Get videos to clear
    videos = get_processed_videos(
        active_only=active_only,
        include_failed=args.include_failed
    )

    if not videos:
        print("\n✅ No processed videos found to clear.")
        return

    # Calculate totals
    total_size = sum(v.get('video_file_size', 0) for v in videos)

    print(f"\n🎯 Videos to clear: {len(videos)}")
    print(f"   Total storage to free: {format_size(total_size)}")

    if not args.execute:
        print("\n" + "=" * 60)
        print("🔍 DRY RUN - No changes made")
        print("=" * 60)
        print("\nVideos that would be cleared:")

        for i, v in enumerate(videos[:15], 1):
            size = format_size(v.get('video_file_size', 0))
            url = v.get('choreo_insta_link', 'N/A')
            song = v.get('song', 'Unknown')
            status = v.get('video_status', 'unknown')
            # Truncate URL for display
            if len(url) > 50:
                url = url[:47] + "..."
            print(f"  {i:3}. [{status:9}] {size:>10} - {song[:20]:20} - {url}")

        if len(videos) > 15:
            print(f"\n  ... and {len(videos) - 15} more videos")

        print("\n" + "-" * 60)
        print("To execute, run with --execute flag:")
        print("  python scripts/clear_processed_videos.py --execute")
        if not args.all:
            print("  python scripts/clear_processed_videos.py --execute --all  # Include all workshops")
        if args.reset_to_pending:
            print("\n  Status will be reset to 'pending' (--reset-to-pending)")
        else:
            print("\n  Video fields will be completely removed")
        return

    # Execute clearing
    print("\n" + "=" * 60)
    print("🚀 EXECUTING - Clearing processed videos...")
    print("=" * 60)

    cleared = 0
    failed = 0
    freed_bytes = 0

    for i, doc in enumerate(videos, 1):
        url = doc.get('choreo_insta_link', 'Unknown')
        song = doc.get('song', 'Unknown')
        size = doc.get('video_file_size', 0)

        print(f"\n[{i}/{len(videos)}] Clearing: {song[:30]}")
        print(f"    URL: {url[:60]}...")
        print(f"    Size: {format_size(size)}")

        success, freed = clear_single_video(doc, reset_to_pending=args.reset_to_pending)

        if success:
            cleared += 1
            freed_bytes += freed
            print(f"    ✅ Cleared successfully")
        else:
            failed += 1
            print(f"    ❌ Failed to clear")

    # Summary
    print("\n" + "=" * 60)
    print("📊 CLEARING COMPLETE")
    print("=" * 60)
    print(f"\n  Cleared:  {cleared}")
    print(f"  Failed:   {failed}")
    print(f"  Storage freed: {format_size(freed_bytes)}")

    if args.reset_to_pending:
        print(f"\n  Video status reset to: 'pending'")
    else:
        print(f"\n  Video fields: removed")

    # Show updated counts
    print("\n📊 Updated Video Status Counts (all workshops):")
    counts = get_status_counts()
    print(f"   Unprocessed: {counts.get('unprocessed', 0)}")
    print(f"   Pending:     {counts.get('pending', 0)}")
    print(f"   Processing:  {counts.get('processing', 0)}")
    print(f"   Completed:   {counts.get('completed', 0)}")
    print(f"   Failed:      {counts.get('failed', 0)}")
    print(f"   Total:       {counts.get('total', 0)}")


if __name__ == "__main__":
    main()
