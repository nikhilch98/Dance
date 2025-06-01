#!/usr/bin/env python3
"""
Create a test user for testing purposes.
Mobile: 9999999999
Password: test123
"""

import requests
import json

# Configuration
BASE_URL = "https://nachna.com/api/auth"
TEST_USER = {
    "mobile_number": "9999999999",
    "password": "test123"
}

def create_test_user():
    """Create a test user for testing purposes."""
    print("🔧 Creating test user for testing...")
    print(f"📱 Mobile: {TEST_USER['mobile_number']}")
    print(f"🔑 Password: {TEST_USER['password']}")
    
    # Try to register the user
    register_response = requests.post(
        f"{BASE_URL}/register",
        headers={"Content-Type": "application/json"},
        json=TEST_USER
    )
    
    if register_response.status_code == 200:
        print("✅ Test user created successfully!")
        auth_data = register_response.json()
        print(f"👤 User ID: {auth_data['user']['user_id']}")
        print(f"📱 Mobile: {auth_data['user']['mobile_number']}")
        print(f"✅ Profile Complete: {auth_data['user']['profile_complete']}")
        return True
    elif register_response.status_code == 400 and "already exists" in register_response.text:
        print("ℹ️  Test user already exists, that's fine!")
        
        # Try to login to verify credentials
        login_response = requests.post(
            f"{BASE_URL}/login",
            headers={"Content-Type": "application/json"},
            json=TEST_USER
        )
        
        if login_response.status_code == 200:
            print("✅ Test user login verified!")
            auth_data = login_response.json()
            print(f"👤 User ID: {auth_data['user']['user_id']}")
            print(f"📱 Mobile: {auth_data['user']['mobile_number']}")
            print(f"✅ Profile Complete: {auth_data['user']['profile_complete']}")
            return True
        else:
            print(f"❌ Test user exists but login failed: {login_response.status_code}")
            print(f"Response: {login_response.text}")
            return False
    else:
        print(f"❌ Failed to create test user: {register_response.status_code}")
        print(f"Response: {register_response.text}")
        return False

if __name__ == "__main__":
    success = create_test_user()
    if success:
        print("\n🎉 Test user is ready for testing!")
        print("You can now use these credentials in the app:")
        print(f"📱 Mobile: {TEST_USER['mobile_number']}")
        print(f"🔑 Password: {TEST_USER['password']}")
    exit(0 if success else 1) 