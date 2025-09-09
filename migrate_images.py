#!/usr/bin/env python3
"""
Image Migration Script

This script migrates all existing images from various sources into the new centralized image collection.
- Profile pictures from profile_pictures collection
- Studio images from external URLs
- Artist images from external URLs

Usage:
    python migrate_images.py [--dry-run] [--type TYPE]

Options:
    --dry-run: Show what would be migrated without actually doing it
    --type TYPE: Only migrate specific type (user, studio, artist)
"""

import argparse
import sys
import os

# Add app directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database.images import ImageMigration, ImageDatabase


def main():
    parser = argparse.ArgumentParser(description="Migrate images to centralized collection")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be migrated without doing it")
    parser.add_argument("--type", choices=["user", "studio", "artist"], help="Only migrate specific type")
    parser.add_argument("--stats", action="store_true", help="Show current image collection stats")
    
    args = parser.parse_args()
    
    if args.stats:
        print("Current image collection statistics:")
        stats = ImageDatabase.get_image_stats()
        print(f"Total images: {stats['total_count']}")
        print(f"Total size: {stats['total_size']:,} bytes ({stats['total_size'] / (1024*1024):.2f} MB)")
        print("\nBy type:")
        for img_type, type_stats in stats.get("by_type", {}).items():
            print(f"  {img_type}: {type_stats['count']} images, {type_stats['total_size']:,} bytes")
        return
    
    if args.dry_run:
        print("DRY RUN MODE - No actual migration will be performed")
        print("=" * 50)
    
    print("Starting image migration...")
    print(f"Target types: {args.type or 'all'}")
    print("=" * 50)
    
    if args.dry_run:
        # For dry run, just show what would be migrated
        if not args.type or args.type == "user":
            print("\n[DRY RUN] Would migrate profile pictures...")
            # Could add logic to count what would be migrated
            
        if not args.type or args.type == "studio":
            print("\n[DRY RUN] Would migrate studio images...")
            
        if not args.type or args.type == "artist":
            print("\n[DRY RUN] Would migrate artist images...")
        
        print("\nDry run complete. Use without --dry-run to perform actual migration.")
        return
    
    # Perform actual migration
    total_migrated = 0
    total_failed = 0
    
    try:
        if not args.type or args.type == "user":
            print("\n=== MIGRATING PROFILE PICTURES ===")
            migrated, failed = ImageMigration.migrate_profile_pictures()
            total_migrated += migrated
            total_failed += failed
        
        if not args.type or args.type == "studio":
            print("\n=== MIGRATING STUDIO IMAGES ===")
            migrated, failed = ImageMigration.migrate_studio_images()
            total_migrated += migrated
            total_failed += failed
        
        if not args.type or args.type == "artist":
            print("\n=== MIGRATING ARTIST IMAGES ===")
            migrated, failed = ImageMigration.migrate_artist_images()
            total_migrated += migrated
            total_failed += failed
        
        print("\n" + "=" * 50)
        print("MIGRATION SUMMARY")
        print("=" * 50)
        print(f"Total migrated: {total_migrated}")
        print(f"Total failed: {total_failed}")
        print(f"Success rate: {(total_migrated / (total_migrated + total_failed) * 100):.1f}%" if (total_migrated + total_failed) > 0 else "N/A")
        
        # Show final stats
        print("\nFinal collection statistics:")
        stats = ImageDatabase.get_image_stats()
        print(f"Total images: {stats['total_count']}")
        print(f"Total size: {stats['total_size']:,} bytes ({stats['total_size'] / (1024*1024):.2f} MB)")
        
        if total_migrated > 0:
            print(f"\n✅ Migration completed successfully!")
        else:
            print(f"\n⚠️ No images were migrated. Check logs for details.")
            
    except Exception as e:
        print(f"\n❌ Migration failed with error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()