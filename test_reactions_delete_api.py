#!/usr/bin/env python3
"""
Test script for the reactions delete API endpoint.
Tests the unlike/unfollow functionality.
"""

import requests
import json
import time

# Test configuration
BASE_URL = "https://nachna.com/api"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def test_reactions_delete_api():
    """Test the reactions delete API endpoints."""
    print("🧪 Testing Reactions Delete API")
    print("=" * 50)
    
    # Step 1: Login to get auth token
    print("1. Logging in...")
    login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "mobile_number": TEST_USER_MOBILE,
        "password": TEST_USER_PASSWORD
    })
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code}")
        print(f"Response: {login_response.text}")
        return
    
    login_data = login_response.json()
    if "access_token" not in login_data:
        print(f"❌ Login failed: {login_data}")
        return
    
    token = login_data["access_token"]
    user_id = login_data["user"]["user_id"]
    print(f"✅ Login successful, user_id: {user_id}")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Step 2: Get available artists
    print("\n2. Getting available artists...")
    artists_response = requests.get(f"{BASE_URL}/artists", headers=headers)
    
    if artists_response.status_code != 200:
        print(f"❌ Failed to get artists: {artists_response.status_code}")
        return
    
    artists = artists_response.json()
    if not artists or not isinstance(artists, list):
        print(f"❌ No artists found: {artists}")
        return
    if not artists:
        print("❌ No artists available for testing")
        return
    
    test_artist = artists[0]
    artist_id = test_artist["id"]
    artist_name = test_artist["name"]
    print(f"✅ Using test artist: {artist_name} (ID: {artist_id})")
    
    # Step 3: Create a LIKE reaction first
    print(f"\n3. Creating LIKE reaction for artist {artist_name}...")
    like_payload = {
        "entity_id": artist_id,
        "entity_type": "ARTIST",
        "reaction": "LIKE"
    }
    
    like_response = requests.post(f"{BASE_URL}/reactions", headers=headers, json=like_payload)
    print(f"Like response status: {like_response.status_code}")
    print(f"Like response: {like_response.text}")
    
    if like_response.status_code == 200:
        like_data = like_response.json()
        if like_data.get("success"):
            print(f"✅ LIKE reaction created successfully")
        else:
            print(f"⚠️ LIKE reaction response: {like_data}")
    else:
        print(f"⚠️ LIKE reaction failed, but continuing with test...")
    
    time.sleep(1)  # Brief pause
    
    # Step 4: Test DELETE by entity (new endpoint)
    print(f"\n4. Testing DELETE by entity endpoint...")
    delete_by_entity_response = requests.delete(
        f"{BASE_URL}/reactions/by-entity",
        headers=headers,
        params={
            "entity_id": artist_id,
            "entity_type": "ARTIST",
            "reaction_type": "LIKE"
        }
    )
    
    print(f"Delete by entity status: {delete_by_entity_response.status_code}")
    print(f"Delete by entity response: {delete_by_entity_response.text}")
    
    if delete_by_entity_response.status_code == 200:
        print(f"✅ DELETE by entity successful")
    else:
        print(f"❌ DELETE by entity failed")
    
    time.sleep(1)  # Brief pause
    
    # Step 5: Create a NOTIFY reaction
    print(f"\n5. Creating NOTIFY reaction for artist {artist_name}...")
    notify_payload = {
        "entity_id": artist_id,
        "entity_type": "ARTIST",
        "reaction": "NOTIFY"
    }
    
    notify_response = requests.post(f"{BASE_URL}/reactions", headers=headers, json=notify_payload)
    print(f"Notify response status: {notify_response.status_code}")
    print(f"Notify response: {notify_response.text}")
    
    if notify_response.status_code == 200:
        notify_data = notify_response.json()
        if notify_data.get("success"):
            print(f"✅ NOTIFY reaction created successfully")
        else:
            print(f"⚠️ NOTIFY reaction response: {notify_data}")
    else:
        print(f"⚠️ NOTIFY reaction failed, but continuing with test...")
    
    time.sleep(1)  # Brief pause
    
    # Step 6: Test DELETE by entity for NOTIFY
    print(f"\n6. Testing DELETE NOTIFY by entity endpoint...")
    delete_notify_response = requests.delete(
        f"{BASE_URL}/reactions/by-entity",
        headers=headers,
        params={
            "entity_id": artist_id,
            "entity_type": "ARTIST",
            "reaction_type": "NOTIFY"
        }
    )
    
    print(f"Delete notify status: {delete_notify_response.status_code}")
    print(f"Delete notify response: {delete_notify_response.text}")
    
    if delete_notify_response.status_code == 200:
        print(f"✅ DELETE NOTIFY by entity successful")
    else:
        print(f"❌ DELETE NOTIFY by entity failed")
    
    # Step 7: Check user reactions to verify deletions
    print(f"\n7. Checking user reactions after deletions...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code == 200:
        user_reactions_data = user_reactions_response.json()
        # Check if it's a direct response or wrapped in success/data
        if isinstance(user_reactions_data, dict) and "liked_artists" in user_reactions_data:
            # Direct response format
            liked_artists = user_reactions_data.get("liked_artists", [])
            notified_artists = user_reactions_data.get("notified_artists", [])
        elif user_reactions_data.get("success"):
            # Wrapped response format
            data = user_reactions_data["data"]
            liked_artists = data.get("liked_artists", [])
            notified_artists = data.get("notified_artists", [])
                else:
            print(f"❌ Unexpected user reactions format: {user_reactions_data}")
            return
            
        print(f"📊 Current user reactions:")
        print(f"   Liked artists: {len(liked_artists)} - {liked_artists}")
        print(f"   Notified artists: {len(notified_artists)} - {notified_artists}")
            
            # Check if our test artist was properly removed
            if artist_id not in liked_artists:
                print(f"✅ LIKE deletion verified - artist {artist_id} not in liked list")
            else:
                print(f"❌ LIKE deletion failed - artist {artist_id} still in liked list")
                
            if artist_id not in notified_artists:
                print(f"✅ NOTIFY deletion verified - artist {artist_id} not in notified list")
            else:
                print(f"❌ NOTIFY deletion failed - artist {artist_id} still in notified list")
        else:
            print(f"❌ Failed to get user reactions: {user_reactions_data}")
    else:
        print(f"❌ Failed to get user reactions: {user_reactions_response.status_code}")
    
    # Step 8: Test old DELETE endpoint (by reaction_id)
    print(f"\n8. Testing old DELETE endpoint (by reaction_id)...")
    
    # First create a reaction to get an ID
    test_payload = {
        "entity_id": artist_id,
        "entity_type": "ARTIST",
        "reaction": "LIKE"
    }
    
    create_response = requests.post(f"{BASE_URL}/reactions", headers=headers, json=test_payload)
    if create_response.status_code == 200:
        create_data = create_response.json()
        if create_data.get("success") and "data" in create_data:
            reaction_id = create_data["data"].get("reaction_id")
            if reaction_id:
                print(f"✅ Created test reaction with ID: {reaction_id}")
                
                # Now try to delete it using the old endpoint
                old_delete_payload = {
                    "reaction_id": reaction_id
                }
                
                old_delete_response = requests.delete(f"{BASE_URL}/reactions", headers=headers, json=old_delete_payload)
                print(f"Old delete status: {old_delete_response.status_code}")
                print(f"Old delete response: {old_delete_response.text}")
                
                if old_delete_response.status_code == 200:
                    print(f"✅ Old DELETE endpoint working")
                else:
                    print(f"❌ Old DELETE endpoint failed")
            else:
                print(f"⚠️ No reaction_id in response: {create_data}")
        else:
            print(f"⚠️ Failed to create test reaction: {create_data}")
    else:
        print(f"⚠️ Failed to create test reaction: {create_response.status_code}")
    
    print(f"\n🏁 Reactions Delete API Test Complete!")

if __name__ == "__main__":
    test_reactions_delete_api() 