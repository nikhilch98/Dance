#!/usr/bin/env python3
"""
Test script for the new reaction API endpoint.
Tests the /reactions/by-entity DELETE endpoint.
"""

import requests
import json

# Test configuration
BASE_URL = "https://nachna.com/api"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def test_reaction_api():
    """Test the reaction API endpoints."""
    print("🧪 Testing Reaction API Endpoints")
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
        return False
    
    auth_data = login_response.json()
    token = auth_data.get("access_token")
    if not token:
        print("❌ No access token in login response")
        return False
    
    print(f"✅ Login successful, token: {token[:20]}...")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Step 2: Create a reaction (like an artist)
    print("\n2. Creating a LIKE reaction...")
    test_artist_id = "675b123456789012345678ab"  # Test artist ID
    
    create_response = requests.post(f"{BASE_URL}/reactions", 
        headers=headers,
        json={
            "entity_id": test_artist_id,
            "entity_type": "ARTIST",
            "reaction": "LIKE"
        }
    )
    
    if create_response.status_code not in [200, 201]:
        print(f"❌ Create reaction failed: {create_response.status_code}")
        print(f"Response: {create_response.text}")
        return False
    
    reaction_data = create_response.json()
    print(f"✅ Reaction created: {reaction_data.get('id', 'Unknown ID')}")
    
    # Step 3: Test the new delete by entity endpoint
    print("\n3. Testing DELETE /reactions/by-entity...")
    
    delete_response = requests.delete(
        f"{BASE_URL}/reactions/by-entity",
        headers=headers,
        params={
            "entity_id": test_artist_id,
            "entity_type": "ARTIST",
            "reaction_type": "LIKE"
        }
    )
    
    if delete_response.status_code != 200:
        print(f"❌ Delete by entity failed: {delete_response.status_code}")
        print(f"Response: {delete_response.text}")
        return False
    
    delete_data = delete_response.json()
    print(f"✅ Delete by entity successful: {delete_data.get('message', 'No message')}")
    
    # Step 4: Verify the reaction was deleted by checking user reactions
    print("\n4. Verifying reaction was deleted...")
    
    user_reactions_response = requests.get(f"{BASE_URL}/user/reactions", headers=headers)
    
    if user_reactions_response.status_code != 200:
        print(f"❌ Get user reactions failed: {user_reactions_response.status_code}")
        return False
    
    user_reactions = user_reactions_response.json()
    liked_artists = user_reactions.get("liked_artists", [])
    
    if test_artist_id in liked_artists:
        print(f"❌ Artist {test_artist_id} still in liked artists list")
        return False
    
    print(f"✅ Artist {test_artist_id} successfully removed from liked artists")
    
    # Step 5: Test creating and deleting a NOTIFY reaction
    print("\n5. Testing NOTIFY reaction...")
    
    # Create NOTIFY reaction
    notify_response = requests.post(f"{BASE_URL}/reactions", 
        headers=headers,
        json={
            "entity_id": test_artist_id,
            "entity_type": "ARTIST",
            "reaction": "NOTIFY"
        }
    )
    
    if notify_response.status_code not in [200, 201]:
        print(f"❌ Create NOTIFY reaction failed: {notify_response.status_code}")
        return False
    
    print("✅ NOTIFY reaction created")
    
    # Delete NOTIFY reaction using new endpoint
    delete_notify_response = requests.delete(
        f"{BASE_URL}/reactions/by-entity",
        headers=headers,
        params={
            "entity_id": test_artist_id,
            "entity_type": "ARTIST",
            "reaction_type": "NOTIFY"
        }
    )
    
    if delete_notify_response.status_code != 200:
        print(f"❌ Delete NOTIFY reaction failed: {delete_notify_response.status_code}")
        return False
    
    print("✅ NOTIFY reaction deleted successfully")
    
    print("\n🎉 All reaction API tests passed!")
    return True

if __name__ == "__main__":
    try:
        success = test_reaction_api()
        if success:
            print("\n✅ All tests completed successfully!")
        else:
            print("\n❌ Some tests failed!")
    except Exception as e:
        print(f"\n💥 Test execution failed: {e}")
        import traceback
        traceback.print_exc() 