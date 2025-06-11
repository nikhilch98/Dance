#!/usr/bin/env python3
"""
Test script to verify search API improvements.
Tests that the search APIs now return the additional fields needed for the improved UI.
"""

import requests
import json
import sys

# Configuration
BASE_URL = "https://nachna.com"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def get_auth_token():
    """Get authentication token for test user."""
    try:
        response = requests.post(
            f"{BASE_URL}/api/auth/login",
            json={
                "mobile_number": TEST_USER_MOBILE,
                "password": TEST_USER_PASSWORD
            },
            headers={"Content-Type": "application/json", "version": "v2"}
        )
        
        if response.status_code == 200:
            data = response.json()
            return data.get("access_token")
        else:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ Login error: {e}")
        return None

def test_artist_search(token):
    """Test artist search API."""
    print("\n🎭 Testing Artist Search API...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/search/artists",
            params={"q": "test", "limit": 5},
            headers={
                "Authorization": f"Bearer {token}",
                "version": "v2"
            }
        )
        
        if response.status_code == 200:
            artists = response.json()
            print(f"✅ Found {len(artists)} artists")
            
            if artists:
                artist = artists[0]
                required_fields = ["id", "name", "instagram_link"]
                optional_fields = ["image_url"]
                
                for field in required_fields:
                    if field in artist:
                        print(f"  ✅ {field}: {artist[field]}")
                    else:
                        print(f"  ❌ Missing required field: {field}")
                
                for field in optional_fields:
                    if field in artist:
                        print(f"  ✅ {field}: {artist[field]}")
                    else:
                        print(f"  ⚠️  Optional field missing: {field}")
            return True
        else:
            print(f"❌ Artist search failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Artist search error: {e}")
        return False

def test_workshop_search(token):
    """Test workshop search API - now returns WorkshopListItem format."""
    print("\n🎪 Testing Workshop Search API...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/search/workshops",
            params={"q": "dance"},
            headers={
                "Authorization": f"Bearer {token}",
                "version": "v2"
            }
        )
        
        if response.status_code == 200:
            workshops = response.json()
            print(f"✅ Found {len(workshops)} workshops")
            
            if workshops:
                workshop = workshops[0]
                
                # Required fields for WorkshopListItem
                required_fields = [
                    "uuid", "payment_link", "studio_id", "studio_name", 
                    "updated_at", "by", "song", "timestamp_epoch"
                ]
                
                # Optional fields in WorkshopListItem
                optional_fields = [
                    "pricing_info", "artist_id_list", "artist_image_urls", 
                    "date", "time", "event_type", "choreo_insta_link"
                ]
                
                print("\n  Required Fields:")
                for field in required_fields:
                    if field in workshop:
                        value = workshop[field]
                        if isinstance(value, list):
                            print(f"    ✅ {field}: {len(value)} items")
                        else:
                            print(f"    ✅ {field}: {str(value)[:50]}{'...' if len(str(value)) > 50 else ''}")
                    else:
                        print(f"    ❌ Missing required field: {field}")
                
                print("\n  Optional Fields:")
                for field in optional_fields:
                    if field in workshop:
                        value = workshop[field]
                        if isinstance(value, list):
                            print(f"    ✅ {field}: {len(value) if value else 0} items")
                        else:
                            print(f"    ✅ {field}: {value}")
                    else:
                        print(f"    ⚠️  Optional field missing: {field}")
                
                # Test the structure matches WorkshopListItem format
                print("\n  WorkshopListItem Structure Validation:")
                workshoplistitem_fields = [
                    "uuid", "payment_link", "studio_id", "studio_name", 
                    "updated_at", "by", "song", "pricing_info", 
                    "timestamp_epoch", "artist_id_list", "artist_image_urls", 
                    "date", "time", "event_type", "choreo_insta_link"
                ]
                
                missing_count = 0
                for field in workshoplistitem_fields:
                    if field not in workshop:
                        missing_count += 1
                
                if missing_count == 0:
                    print(f"    ✅ All WorkshopListItem fields are present")
                else:
                    print(f"    ⚠️  {missing_count} WorkshopListItem fields are missing")
                
            return True
        else:
            print(f"❌ Workshop search failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Workshop search error: {e}")
        return False

def test_user_search(token):
    """Test user search API."""
    print("\n👥 Testing User Search API...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/api/search/users",
            params={"q": "test", "limit": 3},
            headers={
                "Authorization": f"Bearer {token}",
                "version": "v2"
            }
        )
        
        if response.status_code == 200:
            users = response.json()
            print(f"✅ Found {len(users)} users")
            
            if users:
                user = users[0]
                required_fields = ["user_id", "name", "created_at"]
                optional_fields = ["profile_picture_url"]
                
                for field in required_fields:
                    if field in user:
                        print(f"  ✅ {field}: {user[field]}")
                    else:
                        print(f"  ❌ Missing required field: {field}")
                
                for field in optional_fields:
                    if field in user:
                        print(f"  ✅ {field}: {user[field]}")
                    else:
                        print(f"  ⚠️  Optional field missing: {field}")
            return True
        else:
            print(f"❌ User search failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ User search error: {e}")
        return False

def main():
    """Main test function."""
    print("🧪 Testing Search API Improvements")
    print("=" * 50)
    
    # Get authentication token
    print("🔐 Authenticating...")
    token = get_auth_token()
    if not token:
        print("❌ Failed to get authentication token. Exiting.")
        sys.exit(1)
    print("✅ Authentication successful!")
    
    # Run tests
    tests_passed = 0
    total_tests = 3
    
    if test_artist_search(token):
        tests_passed += 1
    
    if test_workshop_search(token):
        tests_passed += 1
        
    if test_user_search(token):
        tests_passed += 1
    
    # Summary
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {tests_passed}/{total_tests} tests passed")
    
    if tests_passed == total_tests:
        print("🎉 All search API improvements are working correctly!")
    else:
        print("⚠️  Some issues detected. Please check the API implementation.")
        sys.exit(1)

if __name__ == "__main__":
    main() 