#!/usr/bin/env python3
"""
Test script for force app update flow
This script simulates different version scenarios to test the force update functionality
"""

import requests
import json
import time

# Configuration
BASE_URL = "https://nachna.com"
TEST_USER_TOKEN = None  # Will be set after login

def login_test_user():
    """Login with test user to get authentication token"""
    print("🔐 Logging in with test user...")

    login_data = {
        "mobile_number": "9999999999",
        "otp": "583647"
    }

    try:
        response = requests.post(f"{BASE_URL}/api/auth/verify-otp", json=login_data)
        if response.status_code == 200:
            data = response.json()
            global TEST_USER_TOKEN
            TEST_USER_TOKEN = data["access_token"]
            print(f"✅ Login successful. Token: {TEST_USER_TOKEN[:20]}...")
            return True
        else:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Login error: {e}")
        return False

def test_version_endpoints():
    """Test all version-related endpoints"""
    if not TEST_USER_TOKEN:
        print("❌ No authentication token available")
        return False

    headers = {
        "Authorization": f"Bearer {TEST_USER_TOKEN}",
        "Content-Type": "application/json"
    }

    print("\n📋 Testing version endpoints...")

    # Test 1: Get minimum version
    print("\n1️⃣ Testing GET /api/version/minimum (iOS)")
    try:
        response = requests.get(f"{BASE_URL}/api/version/minimum?platform=ios", headers=headers)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Minimum version response: {json.dumps(data, indent=2)}")
        else:
            print(f"❌ Error: {response.text}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

    # Test 2: Get current version info
    print("\n2️⃣ Testing GET /api/version/current")
    try:
        response = requests.get(f"{BASE_URL}/api/version/current", headers=headers)
        print(f"Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Current version response: {json.dumps(data, indent=2)}")
        else:
            print(f"❌ Error: {response.text}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

    # Test 3: Test admin update config (should fail for regular user)
    print("\n3️⃣ Testing POST /api/version/update-config (should fail for regular user)")
    update_data = {
        "platform": "ios",
        "minimum_version": "1.5.0",
        "force_update": True,
        "update_message": "Test force update message"
    }
    try:
        response = requests.post(f"{BASE_URL}/api/version/update-config", json=update_data, headers=headers)
        print(f"Status: {response.status_code}")
        if response.status_code == 403:
            print("✅ Correctly denied access to regular user")
        else:
            print(f"Response: {response.text}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

def simulate_force_update():
    """Simulate a force update scenario"""
    print("\n🚀 Simulating force update scenario...")

    # This would require admin access to update the version config
    # For now, we'll just show how the API would be called

    print("To simulate a force update scenario:")
    print("1. Use an admin account to call POST /api/version/update-config")
    print("2. Set minimum_version to a higher version than current app")
    print("3. Set force_update to true")
    print("4. The app will show the force update dialog on next startup")

    print("\nExample admin API call:")
    admin_update_example = {
        "platform": "ios",
        "minimum_version": "2.0.0",  # Higher than current 1.4.1
        "force_update": True,
        "update_message": "This is a critical update that fixes important security issues. Please update immediately.",
        "ios_app_store_url": "https://apps.apple.com/app/idYOUR_APP_ID"
    }
    print(json.dumps(admin_update_example, indent=2))

def test_without_auth():
    """Test version endpoints without authentication (should fail)"""
    print("\n🔒 Testing version endpoints without authentication (should fail)...")

    try:
        response = requests.get(f"{BASE_URL}/api/version/minimum?platform=ios")
        print(f"Status: {response.status_code}")
        if response.status_code == 401:
            print("✅ Correctly requires authentication")
        else:
            print(f"Unexpected response: {response.text}")
    except Exception as e:
        print(f"❌ Request failed: {e}")

def main():
    """Main test function"""
    print("🧪 Testing Force App Update Flow")
    print("=" * 50)

    # Test without authentication first
    test_without_auth()

    # Login and test authenticated endpoints
    if login_test_user():
        test_version_endpoints()
        simulate_force_update()
    else:
        print("❌ Cannot proceed with tests - login failed")

    print("\n" + "=" * 50)
    print("📱 Flutter App Testing Instructions:")
    print("1. Run the app on iOS device/simulator")
    print("2. Login with test user (9999999999)")
    print("3. App should check for updates after login")
    print("4. If force_update is true and version is outdated, dialog should appear")
    print("5. Dialog should prevent dismissal and redirect to App Store")

    print("\n🔧 Admin Configuration:")
    print("- Use admin account to update version config")
    print("- Set minimum_version higher than current app version")
    print("- Set force_update=true to enable force updates")
    print("- Update ios_app_store_url with actual App Store link")

if __name__ == "__main__":
    main()
