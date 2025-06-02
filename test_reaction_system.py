#!/usr/bin/env python3
"""
Test script for the updated reaction system functionality.
Tests artist-only reactions with soft delete.
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
    
    # Step 4: Test creating a FOLLOW reaction (should replace LIKE)
    print("\n4. Creating FOLLOW reaction (should replace LIKE)...")
    follow_response = requests.post(f"{BASE_URL}/reactions",
        headers=headers,
        json={
            "entity_id": artist_id,
            "entity_type": "ARTIST",
            "reaction": "FOLLOW"
        }
    )
    
    if follow_response.status_code not in [200, 201]:
        print(f"❌ Failed to create FOLLOW reaction: {follow_response.text}")
        return False
    
    follow_reaction = follow_response.json()
    follow_reaction_id = follow_reaction["id"]
    print(f"✅ FOLLOW reaction created with ID: {follow_reaction_id}")
    
    # Step 5: Check user reactions
    print("\n5. Checking user reactions...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code != 200:
        print(f"❌ Failed to get user reactions: {user_reactions_response.text}")
        return False
    
    user_reactions = user_reactions_response.json()
    print(f"✅ User reactions: {user_reactions}")
    
    # Verify LIKE was replaced by FOLLOW
    if artist_id in user_reactions.get("followed_artists", []):
        print("✅ Artist is correctly in followed list")
    else:
        print("❌ Artist should be in followed list")
        return False
    
    if artist_id not in user_reactions.get("liked_artists", []):
        print("✅ Artist is correctly NOT in liked list (replaced by follow)")
    else:
        print("❌ Artist should NOT be in liked list (should be replaced by follow)")
        return False
    
    # Step 6: Test soft delete
    print("\n6. Testing soft delete of FOLLOW reaction...")
    delete_response = requests.delete(f"{BASE_URL}/reactions",
        headers=headers,
        json={"reaction_id": follow_reaction_id}
    )
    
    if delete_response.status_code != 200:
        print(f"❌ Failed to soft delete reaction: {delete_response.text}")
        return False
    
    print("✅ Reaction soft deleted successfully")
    
    # Step 7: Verify reaction was soft deleted
    print("\n7. Verifying reaction was soft deleted...")
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code != 200:
        print(f"❌ Failed to get user reactions: {user_reactions_response.text}")
        return False
    
    user_reactions = user_reactions_response.json()
    
    if artist_id not in user_reactions.get("followed_artists", []):
        print("✅ Artist is correctly NOT in followed list after soft delete")
    else:
        print("❌ Artist should NOT be in followed list after soft delete")
        return False
    
    # Step 8: Test reaction stats
    print("\n8. Testing reaction stats...")
    stats_response = requests.get(f"{BASE_URL}/reactions/stats/ARTIST/{artist_id}", headers=headers)
    
    if stats_response.status_code != 200:
        print(f"❌ Failed to get reaction stats: {stats_response.text}")
        return False
    
    stats = stats_response.json()
    print(f"✅ Reaction stats: {stats}")
    
    # Step 9: Test workshop reactions are rejected
    print("\n9. Testing that workshop reactions are rejected...")
    workshop_response = requests.post(f"{BASE_URL}/reactions",
        headers=headers,
        json={
            "entity_id": "test-workshop-id",
            "entity_type": "WORKSHOP",
            "reaction": "LIKE"
        }
    )
    
    if workshop_response.status_code == 400:
        print("✅ Workshop reactions correctly rejected")
    else:
        print(f"❌ Workshop reactions should be rejected, got: {workshop_response.status_code}")
        return False
    
    print("\n🎉 All reaction system tests passed!")
    return True

if __name__ == "__main__":
    test_reaction_system() 