#!/usr/bin/env python3
"""
Setup script for GridFS indexes.

This script creates necessary indexes for efficient video storage
and retrieval in MongoDB GridFS.

Usage:
    python scripts/setup_gridfs_indexes.py
"""
import sys
import os

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.utils import get_mongo_client


def setup_indexes():
    """Create necessary indexes for GridFS and choreo_links."""
    client = get_mongo_client()
    
    print("Setting up indexes...")
    
    # GridFS collections (in dance_app database)
    dance_app_db = client["dance_app"]
    
    # fs.files indexes
    fs_files = dance_app_db["fs.files"]
    
    # Index on metadata.choreo_link_id for quick lookups
    fs_files.create_index(
        "metadata.choreo_link_id",
        name="idx_choreo_link_id"
    )
    print("  ✅ Created index on fs.files.metadata.choreo_link_id")
    
    # Index on uploadDate for sorting
    fs_files.create_index(
        "uploadDate",
        name="idx_upload_date"
    )
    print("  ✅ Created index on fs.files.uploadDate")
    
    # choreo_links collection (in discovery database)
    discovery_db = client["discovery"]
    choreo_links = discovery_db["choreo_links"]
    
    # Index on video_status for processing queries
    choreo_links.create_index(
        "video_status",
        name="idx_video_status"
    )
    print("  ✅ Created index on choreo_links.video_status")
    
    # Compound index for unprocessed query optimization
    choreo_links.create_index(
        [("choreo_insta_link", 1), ("video_status", 1)],
        name="idx_insta_link_video_status"
    )
    print("  ✅ Created compound index on choreo_links.choreo_insta_link + video_status")
    
    # Index on gridfs_file_id for video lookups
    choreo_links.create_index(
        "gridfs_file_id",
        name="idx_gridfs_file_id",
        sparse=True  # Only index documents with this field
    )
    print("  ✅ Created sparse index on choreo_links.gridfs_file_id")
    
    # Index on song for filtering
    choreo_links.create_index(
        "song",
        name="idx_song"
    )
    print("  ✅ Created index on choreo_links.song")
    
    # Index on artist_id_list for filtering
    choreo_links.create_index(
        "artist_id_list",
        name="idx_artist_id_list"
    )
    print("  ✅ Created index on choreo_links.artist_id_list")
    
    print("\n✅ All indexes created successfully!")
    
    # Show index info
    print("\n=== Index Summary ===")
    
    print("\nfs.files indexes:")
    for idx in fs_files.list_indexes():
        print(f"  - {idx['name']}: {idx['key']}")
    
    print("\nchoreo_links indexes:")
    for idx in choreo_links.list_indexes():
        print(f"  - {idx['name']}: {idx['key']}")


if __name__ == "__main__":
    setup_indexes()
