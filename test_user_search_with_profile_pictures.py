#!/usr/bin/env python3
"""
Test script to verify user search API returns profile pictures correctly
"""

import requests
import json
import sys
import time

def test_user_search_with_profile_pictures():
    """Test user search and verify profile picture functionality"""
    
    # API configuration
    base_url = "https://nachna.com/api"
    test_mobile = "9999999999"
    test_password = "test123"
    
    print("🔍 Testing User Search with Profile Pictures")
    print("=" * 50)
    
    try:
        # Step 1: Login to get auth token
        print("1. Logging in with test user...")
        login_response = requests.post(
            f"{base_url}/login",
            json={
                "mobile_number": test_mobile,
                "password": test_password
            },
            headers={
                "Content-Type": "application/json",
                "X-API-Version": "1.0"
            }
        )
        
        if login_response.status_code != 200:
            print(f"❌ Login failed: {login_response.status_code}")
            print(f"Response: {login_response.text}")
            return False
            
        login_data = login_response.json()
        auth_token = login_data.get("access_token")
        
        if not auth_token:
            print("❌ No auth token received")
            return False
            
        print("✅ Login successful")
        
        # Step 2: Test user search
        print("\n2. Testing user search...")
        
        # Test different search queries
        search_queries = ["test", "user", "admin", "a"]
        
        for query in search_queries:
            print(f"\n   🔍 Searching for: '{query}'")
            
            search_response = requests.get(
                f"{base_url}/search/users",
                params={"q": query, "limit": 10},
                headers={
                    "Authorization": f"Bearer {auth_token}",
                    "X-API-Version": "1.0"
                }
            )
            
            if search_response.status_code != 200:
                print(f"   ❌ Search failed: {search_response.status_code}")
                print(f"   Response: {search_response.text}")
                continue
                
            search_results = search_response.json()
            print(f"   ✅ Found {len(search_results)} users")
            
            # Analyze profile picture data
            users_with_pictures = 0
            users_without_pictures = 0
            
            for i, user in enumerate(search_results[:5]):  # Show first 5 results
                user_id = user.get("user_id", "N/A")
                name = user.get("name", "N/A")
                profile_picture_url = user.get("profile_picture_url")
                created_at = user.get("created_at", "N/A")
                
                if profile_picture_url:
                    users_with_pictures += 1
                    status = "🖼️  HAS PICTURE"
                else:
                    users_without_pictures += 1
                    status = "👤 NO PICTURE"
                    
                print(f"   User {i+1}: {name} - {status}")
                print(f"     ID: {user_id}")
                print(f"     Profile Picture: {profile_picture_url or 'None'}")
                print(f"     Created: {created_at}")
                print()
            
            print(f"   📊 Summary for '{query}':")
            print(f"     • Users with pictures: {users_with_pictures}")
            print(f"     • Users without pictures: {users_without_pictures}")
            print(f"     • Total users: {len(search_results)}")
            
        # Step 3: Test profile picture URL accessibility
        print("\n3. Testing profile picture URL accessibility...")
        
        # Get a user with profile picture
        search_response = requests.get(
            f"{base_url}/search/users",
            params={"q": "test", "limit": 20},
            headers={
                "Authorization": f"Bearer {auth_token}",
                "X-API-Version": "1.0"
            }
        )
        
        if search_response.status_code == 200:
            users = search_response.json()
            users_with_pictures = [u for u in users if u.get("profile_picture_url")]
            
            if users_with_pictures:
                test_user = users_with_pictures[0]
                picture_url = test_user["profile_picture_url"]
                
                print(f"   🧪 Testing URL: {picture_url}")
                
                # Test if profile picture URL is accessible
                try:
                    pic_response = requests.head(picture_url, timeout=10)
                    if pic_response.status_code == 200:
                        print(f"   ✅ Profile picture URL accessible (Status: {pic_response.status_code})")
                        content_type = pic_response.headers.get('content-type', 'Unknown')
                        print(f"   📄 Content-Type: {content_type}")
                    else:
                        print(f"   ❌ Profile picture URL not accessible (Status: {pic_response.status_code})")
                except requests.RequestException as e:
                    print(f"   ⚠️  Could not test profile picture URL: {e}")
            else:
                print("   ℹ️  No users with profile pictures found for testing")
        
        # Step 4: Test API response format
        print("\n4. Validating API response format...")
        
        search_response = requests.get(
            f"{base_url}/search/users",
            params={"q": "test", "limit": 1},
            headers={
                "Authorization": f"Bearer {auth_token}",
                "X-API-Version": "1.0"
            }
        )
        
        if search_response.status_code == 200:
            users = search_response.json()
            if users:
                user = users[0]
                expected_fields = ["user_id", "name", "profile_picture_url", "created_at"]
                
                print("   📋 Checking required fields:")
                for field in expected_fields:
                    if field in user:
                        print(f"   ✅ {field}: Present")
                    else:
                        print(f"   ❌ {field}: Missing")
                
                print(f"\n   📋 Sample user data:")
                print(f"   {json.dumps(user, indent=4, default=str)}")
            else:
                print("   ⚠️  No users found for format validation")
        
        print("\n🎉 User search profile picture test completed!")
        return True
        
    except requests.RequestException as e:
        print(f"❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    success = test_user_search_with_profile_pictures()
    sys.exit(0 if success else 1) 