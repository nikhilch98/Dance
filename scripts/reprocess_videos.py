#!/usr/bin/env python3
"""
Reprocess completed videos with new compression settings (CRF 30).

Only processes videos for active workshops (matching 'All Workshops' API):
1. is_archived != True
2. event_type NOT in ['regulars']
3. Workshop date >= start of current week (Monday)

This script will:
1. Find completed videos in choreo_links for active workshops
2. Delete the old GridFS files
3. Reset status to trigger reprocessing
4. Re-download and compress with new settings

Usage:
    python scripts/reprocess_videos.py              # Dry run (show what would happen)
    python scripts/reprocess_videos.py --execute   # Actually reprocess
    python scripts/reprocess_videos.py --execute --batch-size 5  # Process 5 at a time
"""
import sys
import os
import argparse
import time

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bson import ObjectId
from utils.utils import get_mongo_client
from app.services.gridfs_service import GridFSService
from app.services.video_downloader import VideoDownloaderService
from app.database.choreo_links import ChoreoLinksOperations


def get_completed_videos(active_only: bool = True):
    """Get completed video documents, optionally filtered by active workshops."""
    client = get_mongo_client()
    choreo_links = client['discovery']['choreo_links']
    
    query = {
        'video_status': 'completed',
        'gridfs_file_id': {'$exists': True, '$ne': None}
    }
    
    # Filter by active workshop links
    if active_only:
        active_links = ChoreoLinksOperations.get_active_workshop_instagram_links()
        if not active_links:
            return []
        query['choreo_insta_link'] = {'$in': list(active_links)}
    
    return list(choreo_links.find(query))


def calculate_potential_savings(videos):
    """Calculate potential storage savings."""
    total_current = sum(v.get('video_file_size', 0) for v in videos)
    # CRF 30 typically saves ~47% vs original Instagram videos
    estimated_new = total_current * 0.53  # Keep 53% of size
    savings = total_current - estimated_new
    return total_current, estimated_new, savings


def reset_video_for_reprocessing(doc, delete_gridfs=True):
    """Reset a video document for reprocessing."""
    client = get_mongo_client()
    choreo_links = client['discovery']['choreo_links']
    
    doc_id = doc['_id']
    gridfs_file_id = doc.get('gridfs_file_id')
    
    # Delete old GridFS file
    if delete_gridfs and gridfs_file_id:
        try:
            GridFSService.delete_video(str(gridfs_file_id))
            print(f"  ✓ Deleted old GridFS file: {gridfs_file_id}")
        except Exception as e:
            print(f"  ⚠ Could not delete GridFS file: {e}")
    
    # Reset status
    result = choreo_links.update_one(
        {'_id': doc_id},
        {'$set': {
            'video_status': 'pending',
            'video_file_size': None,
            'gridfs_file_id': None,
            'video_error': None,
            'video_processed_at': None
        }}
    )
    
    return result.modified_count > 0


def reprocess_single_video(doc, downloader):
    """Reprocess a single video."""
    url = doc.get('choreo_insta_link', 'Unknown')
    doc_id = doc['_id']
    old_size = doc.get('video_file_size', 0)
    
    print(f"\nProcessing: {url[:60]}...")
    print(f"  Old size: {old_size / 1024 / 1024:.2f} MB")
    
    # Reset for reprocessing
    if not reset_video_for_reprocessing(doc):
        print(f"  ✗ Failed to reset document")
        return False, 0, 0
    
    # Reprocess
    success = downloader.process_choreo_link(doc)
    
    if success:
        # Get new size
        client = get_mongo_client()
        choreo_links = client['discovery']['choreo_links']
        updated_doc = choreo_links.find_one({'_id': doc_id})
        new_size = updated_doc.get('video_file_size', 0)
        savings = old_size - new_size
        
        print(f"  New size: {new_size / 1024 / 1024:.2f} MB")
        print(f"  ✓ Saved: {savings / 1024 / 1024:.2f} MB ({savings / old_size * 100:.1f}%)")
        return True, old_size, new_size
    else:
        print(f"  ✗ Reprocessing failed")
        return False, old_size, 0


def main():
    parser = argparse.ArgumentParser(description='Reprocess videos with CRF 30 compression')
    parser.add_argument('--execute', action='store_true', help='Actually execute reprocessing')
    parser.add_argument('--batch-size', type=int, default=0, help='Process N videos (0 = all)')
    parser.add_argument('--delay', type=int, default=5, help='Delay between videos (seconds)')
    parser.add_argument('--all', action='store_true', help='Process ALL videos, not just active workshops')
    args = parser.parse_args()
    
    print("=" * 60)
    print("📹 VIDEO REPROCESSING TOOL (CRF 30)")
    print("=" * 60)
    
    active_only = not args.all
    
    if active_only:
        print("\n📋 Processing videos for ACTIVE WORKSHOPS ONLY")
        print("   Active Workshop Criteria:")
        print("     1. is_archived != True")
        print("     2. event_type NOT in ['regulars']")
        print("     3. Workshop date >= start of current week (Monday)")
        print("\n   Use --all to process ALL completed videos.")
    else:
        print("\n⚠️  Processing ALL completed videos (including archived)")
    
    # Get completed videos
    videos = get_completed_videos(active_only=active_only)
    
    if not videos:
        print("\nNo completed videos found to reprocess.")
        return
    
    # Calculate potential savings
    current_total, estimated_new, potential_savings = calculate_potential_savings(videos)
    
    print(f"\n📊 Current State:")
    print(f"   Videos to reprocess: {len(videos)}")
    print(f"   Current storage: {current_total / 1024 / 1024:.2f} MB")
    print(f"   Estimated after CRF 30: {estimated_new / 1024 / 1024:.2f} MB")
    print(f"   Potential savings: ~{potential_savings / 1024 / 1024:.2f} MB ({potential_savings / current_total * 100:.1f}%)")
    
    if not args.execute:
        print("\n" + "=" * 60)
        print("🔍 DRY RUN - No changes made")
        print("=" * 60)
        print("\nVideos that would be reprocessed:")
        for i, v in enumerate(videos[:10], 1):
            size = v.get('video_file_size', 0) / 1024 / 1024
            url = v.get('choreo_insta_link', 'N/A')[:50]
            print(f"  {i}. {size:.2f} MB - {url}...")
        
        if len(videos) > 10:
            print(f"  ... and {len(videos) - 10} more")
        
        print("\nRun with --execute to actually reprocess videos.")
        print("Example: python scripts/reprocess_videos.py --execute --batch-size 5")
        return
    
    # Execute reprocessing
    print("\n" + "=" * 60)
    print("🚀 EXECUTING REPROCESSING")
    print("=" * 60)
    
    downloader = VideoDownloaderService(optimize=True)
    
    to_process = videos[:args.batch_size] if args.batch_size > 0 else videos
    
    print(f"\nProcessing {len(to_process)} videos...")
    print(f"Delay between videos: {args.delay} seconds")
    
    total_old = 0
    total_new = 0
    succeeded = 0
    failed = 0
    
    for i, doc in enumerate(to_process, 1):
        print(f"\n[{i}/{len(to_process)}]", end="")
        
        success, old_size, new_size = reprocess_single_video(doc, downloader)
        
        if success:
            total_old += old_size
            total_new += new_size
            succeeded += 1
        else:
            failed += 1
        
        # Delay between downloads
        if i < len(to_process):
            print(f"\n  Waiting {args.delay}s before next video...")
            time.sleep(args.delay)
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 REPROCESSING COMPLETE")
    print("=" * 60)
    print(f"\n  Succeeded: {succeeded}")
    print(f"  Failed: {failed}")
    
    if succeeded > 0:
        savings = total_old - total_new
        print(f"\n  Storage before: {total_old / 1024 / 1024:.2f} MB")
        print(f"  Storage after:  {total_new / 1024 / 1024:.2f} MB")
        print(f"  Total saved:    {savings / 1024 / 1024:.2f} MB ({savings / total_old * 100:.1f}%)")


if __name__ == "__main__":
    main()
