#!/usr/bin/env python3
"""
Create a test user for profile picture testing.
"""

import requests
import json

# Configuration
BASE_URL = "https://nachna.com/api/auth"
TEST_USER = {
    "mobile_number": "9876543210",
    "password": "testpass123"
}

def create_test_user():
    """Create a test user for profile picture testing."""
    print("🔧 Creating test user for profile picture testing...")
    
    # Try to register the user
    register_response = requests.post(
        f"{BASE_URL}/register",
        headers={"Content-Type": "application/json"},
        json=TEST_USER
    )
    
    if register_response.status_code == 200:
        print("✅ Test user created successfully!")
        auth_data = register_response.json()
        print(f"User ID: {auth_data['user']['user_id']}")
        print(f"Mobile: {auth_data['user']['mobile_number']}")
        return True
    elif register_response.status_code == 400 and "already exists" in register_response.text:
        print("ℹ️  Test user already exists, that's fine!")
        return True
    else:
        print(f"❌ Failed to create test user: {register_response.status_code}")
        print(f"Response: {register_response.text}")
        return False

if __name__ == "__main__":
    success = create_test_user()
    exit(0 if success else 1) 