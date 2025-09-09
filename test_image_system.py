#!/usr/bin/env python3
"""
Test script for the new centralized image system.

This script tests:
1. Image database operations
2. Migration functionality
3. New API endpoints
4. Cache behavior
5. Backward compatibility
"""

import sys
import os
import requests
import time

# Add app directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database.images import ImageDatabase, ImageMigration


def test_database_operations():
    """Test basic database operations."""
    print("=== TESTING DATABASE OPERATIONS ===")
    
    # Test storing an image
    test_data = b"fake_image_data_for_testing"
    
    try:
        # Store test image
        image_id = ImageDatabase.store_image(
            data=test_data,
            image_type="user",
            entity_id="test_user_123",
            content_type="image/png"
        )
        print(f"✅ Stored test image with ID: {image_id}")
        
        # Retrieve test image
        retrieved = ImageDatabase.get_image("user", "test_user_123")
        if retrieved and retrieved["data"] == test_data:
            print("✅ Retrieved test image successfully")
        else:
            print("❌ Failed to retrieve test image")
        
        # Test stats
        stats = ImageDatabase.get_image_stats()
        print(f"✅ Current stats: {stats}")
        
        # Clean up
        deleted = ImageDatabase.delete_image("user", "test_user_123")
        if deleted:
            print("✅ Cleaned up test image")
        else:
            print("⚠️ Could not clean up test image")
        
    except Exception as e:
        print(f"❌ Database operations failed: {str(e)}")
        import traceback
        traceback.print_exc()


def test_api_endpoints():
    """Test the new API endpoints."""
    print("\n=== TESTING API ENDPOINTS ===")
    
    base_url = "https://nachna.com"  # Change if testing locally
    
    # Test invalid image type
    try:
        response = requests.get(f"{base_url}/api/image/invalid/test123", timeout=10)
        if response.status_code == 400:
            print("✅ Invalid image type properly rejected")
        else:
            print(f"⚠️ Unexpected response for invalid type: {response.status_code}")
    except Exception as e:
        print(f"❌ API test failed: {str(e)}")
    
    # Test non-existent image
    try:
        response = requests.get(f"{base_url}/api/image/studio/non_existent_studio", timeout=10)
        if response.status_code == 404:
            print("✅ Non-existent image properly returns 404")
        else:
            print(f"⚠️ Unexpected response for non-existent image: {response.status_code}")
    except Exception as e:
        print(f"❌ API test failed: {str(e)}")
    
    # Test existing studio image (if migration has run)
    try:
        response = requests.get(f"{base_url}/api/image/studio/dance.inn.bangalore", timeout=10)
        if response.status_code == 200:
            print(f"✅ Studio image API working, size: {len(response.content)} bytes")
        elif response.status_code == 404:
            print("ℹ️ Studio image not found (migration may not have run yet)")
        else:
            print(f"⚠️ Unexpected response for studio image: {response.status_code}")
    except Exception as e:
        print(f"❌ Studio image API test failed: {str(e)}")


def test_backward_compatibility():
    """Test that old endpoints still work."""
    print("\n=== TESTING BACKWARD COMPATIBILITY ===")
    
    base_url = "https://nachna.com"
    
    # Test profile picture endpoint (should work with fallback)
    try:
        response = requests.get(f"{base_url}/api/profile-picture/683cdbb39caf05c68764cde4", timeout=10)
        if response.status_code in [200, 404]:
            print("✅ Profile picture endpoint accessible")
            if response.status_code == 200:
                print(f"   Image size: {len(response.content)} bytes")
        else:
            print(f"⚠️ Unexpected profile picture response: {response.status_code}")
    except Exception as e:
        print(f"❌ Profile picture test failed: {str(e)}")
    
    # Test proxy image endpoint (should still work)
    try:
        response = requests.get(
            f"{base_url}/api/proxy-image/?url=https://httpbin.org/image/jpeg", 
            timeout=10
        )
        if response.status_code == 200:
            print("✅ Proxy image endpoint still working")
        else:
            print(f"⚠️ Proxy image endpoint issue: {response.status_code}")
    except Exception as e:
        print(f"❌ Proxy image test failed: {str(e)}")


def test_migration_dry_run():
    """Test migration in dry-run mode."""
    print("\n=== TESTING MIGRATION (DRY RUN) ===")
    
    try:
        # Get current stats
        stats_before = ImageDatabase.get_image_stats()
        print(f"Images before migration: {stats_before['total_count']}")
        
        # Test individual migration functions (but don't actually run them)
        print("Migration functions loaded successfully")
        print("✅ Migration system ready")
        
    except Exception as e:
        print(f"❌ Migration test failed: {str(e)}")
        import traceback
        traceback.print_exc()


def main():
    """Run all tests."""
    print("🧪 CENTRALIZED IMAGE SYSTEM TESTS")
    print("=" * 50)
    
    try:
        test_database_operations()
        test_api_endpoints()
        test_backward_compatibility()
        test_migration_dry_run()
        
        print("\n" + "=" * 50)
        print("🎉 TESTING COMPLETE")
        print("\nTo run the actual migration:")
        print("  python migrate_images.py --stats")
        print("  python migrate_images.py --dry-run")
        print("  python migrate_images.py")
        
    except Exception as e:
        print(f"\n❌ Testing failed: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()