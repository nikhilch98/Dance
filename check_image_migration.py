#!/usr/bin/env python3
"""
Check studio image migration status and run migration if needed.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.images import ImageDatabase, ImageMigration
from app.database.workshops import DatabaseOperations
import requests

def check_migration_status():
    """Check which studio images are migrated and which are not."""
    print("=== Studio Image Migration Status ===\n")
    
    # Get all studios
    studios = DatabaseOperations.get_studios()
    print(f"Found {len(studios)} studios total\n")
    
    migrated_count = 0
    not_migrated_count = 0
    no_image_url_count = 0
    
    print("Studio Migration Status:")
    print("-" * 80)
    
    for studio in studios:
        studio_id = studio.get('id')
        studio_name = studio.get('name', 'Unknown')
        image_url = studio.get('image_url')
        
        # Check if image exists in centralized storage
        centralized_image = ImageDatabase.get_image("studio", studio_id)
        
        status_icon = "✅" if centralized_image else "❌"
        has_url_icon = "🔗" if image_url else "🚫"
        
        print(f"{status_icon} {studio_id:<25} | {studio_name:<30} | {has_url_icon}")
        
        if centralized_image:
            migrated_count += 1
        elif image_url:
            not_migrated_count += 1
        else:
            no_image_url_count += 1
    
    print("-" * 80)
    print(f"📊 Summary:")
    print(f"   ✅ Migrated: {migrated_count}")
    print(f"   ❌ Not migrated (has URL): {not_migrated_count}")
    print(f"   🚫 No image URL: {no_image_url_count}")
    print(f"   📋 Total: {len(studios)}")
    
    return migrated_count, not_migrated_count, no_image_url_count

def test_centralized_api():
    """Test the centralized image API with some studio IDs."""
    print("\n=== Testing Centralized Image API ===\n")
    
    studios = DatabaseOperations.get_studios()
    test_studios = studios[:5]  # Test first 5 studios
    
    for studio in test_studios:
        studio_id = studio.get('id')
        studio_name = studio.get('name', 'Unknown')
        
        try:
            url = f"https://nachna.com/api/image/studio/{studio_id}"
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                content_type = response.headers.get('content-type', 'unknown')
                content_length = len(response.content)
                print(f"✅ {studio_id:<25} | {studio_name:<30} | {content_type} ({content_length} bytes)")
            elif response.status_code == 404:
                print(f"❌ {studio_id:<25} | {studio_name:<30} | Not found (404)")
            else:
                print(f"⚠️  {studio_id:<25} | {studio_name:<30} | HTTP {response.status_code}")
                
        except Exception as e:
            print(f"💥 {studio_id:<25} | {studio_name:<30} | Error: {str(e)}")

def run_migration():
    """Run the studio image migration."""
    print("\n=== Running Studio Image Migration ===\n")
    
    # Run migration
    migrated, failed = ImageMigration.migrate_studio_images()
    
    print(f"\n📊 Migration Results:")
    print(f"   ✅ Successfully migrated: {migrated}")
    print(f"   ❌ Failed migrations: {failed}")
    
    return migrated, failed

def main():
    """Main function."""
    try:
        # Check current migration status
        migrated, not_migrated, no_url = check_migration_status()
        
        # Test centralized API
        test_centralized_api()
        
        # Ask if user wants to run migration
        if not_migrated > 0:
            print(f"\n🔄 Found {not_migrated} studio images that need migration.")
            response = input("Do you want to run the migration now? (y/n): ").strip().lower()
            
            if response == 'y':
                run_migration()
                print("\n🔄 Re-checking migration status after migration:")
                check_migration_status()
            else:
                print("Migration skipped.")
        else:
            print("\n✅ All studio images with URLs are already migrated!")
            
    except Exception as e:
        print(f"💥 Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())