#!/usr/bin/env python3
"""
Test script for profile picture API endpoints.
Tests the MongoDB-based profile picture storage functionality.
"""

import requests
import json
import io
from PIL import Image
import tempfile
import os

# Configuration
BASE_URL = "https://nachna.com/api/auth"
TEST_USER = {
    "mobile_number": "9876543210",
    "password": "testpass123"
}

def create_test_image():
    """Create a simple test image."""
    # Create a simple 100x100 red image
    img = Image.new('RGB', (100, 100), color='red')
    
    # Save to bytes
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='JPEG')
    img_bytes.seek(0)
    
    return img_bytes

def test_profile_picture_workflow():
    """Test the complete profile picture workflow."""
    print("🧪 Testing Profile Picture API Workflow")
    print("=" * 50)
    
    # Step 1: Register or login user
    print("1. Logging in user...")
    login_response = requests.post(
        f"{BASE_URL}/login",
        headers={"Content-Type": "application/json"},
        json=TEST_USER
    )
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code}")
        print(f"Response: {login_response.text}")
        return False
    
    auth_data = login_response.json()
    token = auth_data["access_token"]
    print(f"✅ Login successful, token: {token[:20]}...")
    
    # Step 2: Upload profile picture
    print("\n2. Uploading profile picture...")
    test_image = create_test_image()
    
    upload_response = requests.post(
        f"{BASE_URL}/profile-picture",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("test.jpg", test_image, "image/jpeg")}
    )
    
    if upload_response.status_code != 200:
        print(f"❌ Upload failed: {upload_response.status_code}")
        print(f"Response: {upload_response.text}")
        return False
    
    upload_data = upload_response.json()
    image_url = upload_data["image_url"]
    print(f"✅ Upload successful, image URL: {image_url}")
    
    # Step 3: Verify profile picture can be retrieved
    print("\n3. Retrieving profile picture...")
    picture_response = requests.get(f"https://nachna.com{image_url}")
    
    if picture_response.status_code != 200:
        print(f"❌ Retrieval failed: {picture_response.status_code}")
        return False
    
    print(f"✅ Retrieval successful, content type: {picture_response.headers.get('content-type')}")
    print(f"✅ Image size: {len(picture_response.content)} bytes")
    
    # Step 4: Verify profile shows the picture
    print("\n4. Checking user profile...")
    profile_response = requests.get(
        f"{BASE_URL}/profile",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    if profile_response.status_code != 200:
        print(f"❌ Profile check failed: {profile_response.status_code}")
        return False
    
    profile_data = profile_response.json()
    profile_picture_url = profile_data.get("profile_picture_url")
    
    if profile_picture_url != image_url:
        print(f"❌ Profile picture URL mismatch: {profile_picture_url} != {image_url}")
        return False
    
    print(f"✅ Profile updated with picture URL: {profile_picture_url}")
    
    # Step 5: Remove profile picture
    print("\n5. Removing profile picture...")
    remove_response = requests.delete(
        f"{BASE_URL}/profile-picture",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    if remove_response.status_code != 200:
        print(f"❌ Removal failed: {remove_response.status_code}")
        print(f"Response: {remove_response.text}")
        return False
    
    print("✅ Profile picture removed successfully")
    
    # Step 6: Verify picture is no longer accessible
    print("\n6. Verifying picture is removed...")
    verify_response = requests.get(f"https://nachna.com{image_url}")
    
    if verify_response.status_code == 200:
        print(f"⚠️  Warning: Picture still accessible after removal")
    else:
        print(f"✅ Picture properly removed (status: {verify_response.status_code})")
    
    # Step 7: Check profile no longer has picture
    final_profile_response = requests.get(
        f"{BASE_URL}/profile",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    if final_profile_response.status_code == 200:
        final_profile_data = final_profile_response.json()
        final_picture_url = final_profile_data.get("profile_picture_url")
        
        if final_picture_url is None:
            print("✅ Profile picture URL properly removed from profile")
        else:
            print(f"❌ Profile still shows picture URL: {final_picture_url}")
            return False
    
    print("\n🎉 All tests passed! Profile picture API is working correctly.")
    return True

if __name__ == "__main__":
    try:
        success = test_profile_picture_workflow()
        exit(0 if success else 1)
    except Exception as e:
        print(f"❌ Test failed with exception: {e}")
        import traceback
        traceback.print_exc()
        exit(1) 