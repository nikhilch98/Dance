#!/usr/bin/env python3
"""
Test script for multi-artist API changes
"""

import requests
import json
import sys

# Test configuration
BASE_URL = "http://localhost:8002"  # Adjust if your server runs on a different port
TEST_ADMIN_TOKEN = "your-admin-token-here"  # You'll need to get this from login

def test_assign_multiple_artists():
    """Test assigning multiple artists to a workshop"""
    
    # First, get a list of available artists
    print("1. Fetching available artists...")
    response = requests.get(f"{BASE_URL}/api/artists")
    if response.status_code != 200:
        print(f"Failed to fetch artists: {response.status_code}")
        return False
    
    artists = response.json()
    if len(artists) < 2:
        print("Need at least 2 artists to test multi-artist assignment")
        return False
    
    print(f"Found {len(artists)} artists")
    
    # Get missing artist sessions
    print("\n2. Fetching missing artist sessions...")
    headers = {"Authorization": f"Bearer {TEST_ADMIN_TOKEN}"}
    response = requests.get(f"{BASE_URL}/admin/api/missing_artist_sessions", headers=headers)
    
    if response.status_code != 200:
        print(f"Failed to fetch missing artist sessions: {response.status_code}")
        print("Make sure you have a valid admin token")
        return False
    
    missing_sessions = response.json()
    if not missing_sessions:
        print("No missing artist sessions found")
        return True
    
    print(f"Found {len(missing_sessions)} sessions missing artists")
    
    # Test assigning multiple artists to the first session
    test_session = missing_sessions[0]
    workshop_uuid = test_session["workshop_uuid"]
    
    # Select first 2 artists for testing
    test_artists = artists[:2]
    
    print(f"\n3. Assigning artists to workshop {workshop_uuid}")
    print(f"Artists: {[artist['name'] for artist in test_artists]}")
    
    payload = {
        "artist_id_list": [artist["id"] for artist in test_artists],
        "artist_name_list": [artist["name"] for artist in test_artists]
    }
    
    response = requests.put(
        f"{BASE_URL}/admin/api/workshops/{workshop_uuid}/assign_artist",
        headers=headers,
        json=payload
    )
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Success: {result['message']}")
        return True
    else:
        print(f"❌ Failed to assign artists: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def test_api_endpoints():
    """Test that all API endpoints return the correct structure"""
    
    print("4. Testing API endpoints for new structure...")
    
    # Test workshops endpoint
    response = requests.get(f"{BASE_URL}/api/workshops")
    if response.status_code == 200:
        workshops = response.json()
        if workshops:
            first_workshop = workshops[0]
            if "artist_id_list" in first_workshop:
                print("✅ Workshops endpoint has artist_id_list field")
            else:
                print("❌ Workshops endpoint missing artist_id_list field")
        else:
            print("No workshops found to test")
    else:
        print(f"❌ Failed to fetch workshops: {response.status_code}")
    
    # Test artists endpoint
    response = requests.get(f"{BASE_URL}/api/artists")
    if response.status_code == 200:
        print("✅ Artists endpoint working")
    else:
        print(f"❌ Artists endpoint failed: {response.status_code}")

if __name__ == "__main__":
    print("Testing Multi-Artist API Changes")
    print("=" * 40)
    
    if len(sys.argv) > 1:
        TEST_ADMIN_TOKEN = sys.argv[1]
    
    if TEST_ADMIN_TOKEN == "your-admin-token-here":
        print("Please provide an admin token as the first argument")
        print("Usage: python test_multi_artist_api.py <admin-token>")
        sys.exit(1)
    
    # Run tests
    test_api_endpoints()
    
    if test_assign_multiple_artists():
        print("\n✅ All tests passed!")
    else:
        print("\n❌ Some tests failed!") 