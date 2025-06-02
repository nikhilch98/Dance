#!/usr/bin/env python3
"""
Test script for the updated reaction system functionality.
Tests artist-only reactions with soft delete and both LIKE and NOTIFY reactions.
"""
import requests
import json

BASE_URL = "https://nachna.com/api"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def test_reaction_system():
    """Test the complete reaction system workflow with artist-only reactions."""
    print("🧪 Testing Updated Reaction System...")
    
    # Step 1: Login to get auth token
    print("\n1. Logging in as test user...")
    login_response = requests.post(f"{BASE_URL}/auth/login", json={
        "mobile_number": TEST_USER_MOBILE,
        "password": TEST_USER_PASSWORD
    })
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.text}")
        return False
    
    auth_data = login_response.json()
    token = auth_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    print("✅ Login successful")
    
    # Step 2: Get an artist ID
    print("\n2. Getting artists list...")
    artists_response = requests.get(f"{BASE_URL}/artists", headers=headers)
    
    if artists_response.status_code != 200:
        print(f"❌ Failed to get artists: {artists_response.text}")
        return False
    
    artists = artists_response.json()
    if not artists:
        print("❌ No artists found")
        return False
    
    test_artist = artists[0]
    artist_id = test_artist["id"]
    artist_name = test_artist["name"]
    
    print(f"✅ Using test artist: {artist_name} (ID: {artist_id})")
    
    # Step 3: Test creating a LIKE reaction
    print("\n3. Creating LIKE reaction...")
    like_response = requests.post(f"{BASE_URL}/reactions", 
        headers=headers,
        json={
            "entity_id": artist_id,
            "entity_type": "ARTIST", 
            "reaction": "LIKE"
        }
    )
    
    if like_response.status_code not in [200, 201]:
        print(f"❌ Failed to create LIKE reaction: {like_response.text}")
        return False
    
    like_reaction = like_response.json()
    like_reaction_id = like_reaction["id"]
    print(f"✅ LIKE reaction created with ID: {like_reaction_id}")
    
    # Step 4: Test creating a NOTIFY reaction (should coexist with LIKE)
    print("\n4. Creating NOTIFY reaction (should coexist with LIKE)...")
    notify_response = requests.post(f"{BASE_URL}/reactions",
        headers=headers,
        json={
            "entity_id": artist_id,
            "entity_type": "ARTIST",
            "reaction": "NOTIFY"
        }
    )
    
    if notify_response.status_code not in [200, 201]:
        print(f"❌ Failed to create NOTIFY reaction: {notify_response.text}")
        return False
    
    notify_reaction = notify_response.json()
    notify_reaction_id = notify_reaction["id"]
    print(f"✅ NOTIFY reaction created with ID: {notify_reaction_id}")
    
    # Step 5: Check user reactions (both should exist)
    print("\n5. Checking user reactions...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code != 200:
        print(f"❌ Failed to get user reactions: {user_reactions_response.text}")
        return False
    
    user_reactions = user_reactions_response.json()
    print(f"✅ User reactions: {user_reactions}")
    
    # Verify both LIKE and NOTIFY exist
    if artist_id in user_reactions.get("notified_artists", []):
        print("✅ Artist is correctly in notified list")
    else:
        print("❌ Artist should be in notified list")
        return False
    
    if artist_id in user_reactions.get("liked_artists", []):
        print("✅ Artist is correctly in liked list (both reactions coexist)")
    else:
        print("❌ Artist should be in liked list (both reactions should coexist)")
        return False
    
    # Step 6: Test soft delete of NOTIFY reaction
    print("\n6. Testing soft delete of NOTIFY reaction...")
    delete_response = requests.delete(f"{BASE_URL}/reactions",
        headers=headers,
        json={"reaction_id": notify_reaction_id}
    )
    
    if delete_response.status_code != 200:
        print(f"❌ Failed to soft delete reaction: {delete_response.text}")
        return False
    
    print("✅ NOTIFY reaction soft deleted successfully")
    
    # Step 7: Verify NOTIFY was soft deleted but LIKE remains
    print("\n7. Verifying NOTIFY was soft deleted but LIKE remains...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code != 200:
        print(f"❌ Failed to get user reactions: {user_reactions_response.text}")
        return False
    
    user_reactions = user_reactions_response.json()
    
    if artist_id not in user_reactions.get("notified_artists", []):
        print("✅ Artist is correctly NOT in notified list after soft delete")
    else:
        print("❌ Artist should NOT be in notified list after soft delete")
        return False
    
    if artist_id in user_reactions.get("liked_artists", []):
        print("✅ Artist is still in liked list (LIKE reaction remains)")
    else:
        print("❌ Artist should still be in liked list (LIKE reaction should remain)")
        return False
    
    # Step 8: Test re-creating NOTIFY after soft delete
    print("\n8. Testing re-creating NOTIFY reaction after soft delete...")
    notify_response2 = requests.post(f"{BASE_URL}/reactions",
        headers=headers,
        json={
            "entity_id": artist_id,
            "entity_type": "ARTIST",
            "reaction": "NOTIFY"
        }
    )
    
    if notify_response2.status_code not in [200, 201]:
        print(f"❌ Failed to re-create NOTIFY reaction: {notify_response2.text}")
        return False
    
    print("✅ NOTIFY reaction re-created successfully after soft delete")
    
    # Step 9: Verify both reactions exist again
    print("\n9. Verifying both reactions exist again...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    user_reactions = user_reactions_response.json()
    
    if artist_id in user_reactions.get("notified_artists", []) and artist_id in user_reactions.get("liked_artists", []):
        print("✅ Both LIKE and NOTIFY reactions exist after re-creation")
    else:
        print(f"❌ Both reactions should exist. Got: {user_reactions}")
        return False
    
    # Step 10: Test reaction stats
    print("\n10. Testing reaction stats...")
    stats_response = requests.get(f"{BASE_URL}/reactions/stats/ARTIST/{artist_id}", headers=headers)
    
    if stats_response.status_code != 200:
        print(f"❌ Failed to get reaction stats: {stats_response.text}")
        return False
    
    stats = stats_response.json()
    print(f"✅ Reaction stats: {stats}")
    
    # Verify stats show both reactions
    if stats.get("like_count", 0) >= 1 and stats.get("notify_count", 0) >= 1:
        print("✅ Stats correctly show both LIKE and NOTIFY counts")
    else:
        print(f"❌ Stats should show both reaction types. Got: {stats}")
        return False
    
    # Step 11: Test workshop reactions are rejected
    print("\n11. Testing that workshop reactions are rejected...")
    workshop_response = requests.post(f"{BASE_URL}/reactions",
        headers=headers,
        json={
            "entity_id": "test-workshop-id",
            "entity_type": "WORKSHOP",
            "reaction": "LIKE"
        }
    )
    
    if workshop_response.status_code == 422:  # Updated to expect 422 for validation error
        print("✅ Workshop reactions correctly rejected with validation error")
    else:
        print(f"❌ Workshop reactions should be rejected with 422, got: {workshop_response.status_code}")
        return False
    
    print("\n🎉 All reaction system tests passed!")
    return True

if __name__ == "__main__":
    test_reaction_system() 