#!/usr/bin/env python3
"""
Test script to verify multi-artist display functionality
"""

import requests
import json

def test_multi_artist_api():
    """Test the multi-artist API functionality"""
    
    print("Testing multi-artist API functionality...")
    
    # Test workshops endpoint
    print("\n1. Testing /api/workshops endpoint...")
    try:
        response = requests.get("http://localhost:8002/api/workshops")
        if response.status_code == 200:
            workshops = response.json()
            print(f"✅ Successfully fetched {len(workshops)} workshops")
            
            # Check for workshops with multiple artists
            multi_artist_workshops = []
            for workshop in workshops[:5]:  # Check first 5 workshops
                artist_id_list = workshop.get('artist_id_list', [])
                artist_image_urls = workshop.get('artist_image_urls', [])
                
                print(f"\nWorkshop: {workshop.get('by', 'Unknown')}")
                print(f"  - Artist IDs: {artist_id_list}")
                print(f"  - Image URLs: {len(artist_image_urls)} images")
                
                if len(artist_id_list) > 1:
                    multi_artist_workshops.append(workshop)
                    print(f"  ✅ Multi-artist workshop found!")
            
            if multi_artist_workshops:
                print(f"\n✅ Found {len(multi_artist_workshops)} multi-artist workshops")
            else:
                print("\n⚠️  No multi-artist workshops found in sample")
                
        else:
            print(f"❌ Failed to fetch workshops: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error testing workshops endpoint: {e}")
    
    # Test artists endpoint
    print("\n2. Testing /api/artists endpoint...")
    try:
        response = requests.get("http://localhost:8002/api/artists")
        if response.status_code == 200:
            artists = response.json()
            print(f"✅ Successfully fetched {len(artists)} artists")
            
            # Show sample artists
            for artist in artists[:3]:
                print(f"  - {artist.get('name', 'Unknown')}: {artist.get('id', 'No ID')}")
                
        else:
            print(f"❌ Failed to fetch artists: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error testing artists endpoint: {e}")

if __name__ == "__main__":
    test_multi_artist_api() 