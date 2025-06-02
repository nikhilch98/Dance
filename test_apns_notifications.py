#!/usr/bin/env python3
"""
Test script for APNs (Apple Push Notification service) functionality.
This script helps test the complete push notification workflow.
"""
import requests
import json
import time
import os

BASE_URL = "https://nachna.com/api"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def test_apns_workflow():
    """Test the complete APNs workflow."""
    print("🍎 Testing APNs Notification System...")
    
    # Step 1: Login as test user
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
    user_id = auth_data["user"]["user_id"]
    
    print("✅ Login successful")
    
    # Step 2: Register a test device token
    print("\n2. Registering test device token...")
    
    # This would be a real device token from your iOS app
    # For testing, use a dummy token (real tokens are 64 hex characters)
    test_device_token = "a" * 64  # Dummy token for testing
    
    device_token_response = requests.post(f"{BASE_URL}/notifications/register-token",
        headers=headers,
        json={
            "device_token": test_device_token,
            "platform": "ios"
        }
    )
    
    if device_token_response.status_code != 200:
        print(f"❌ Failed to register device token: {device_token_response.text}")
        return False
    
    print("✅ Device token registered successfully")
    
    # Step 3: Create a NOTIFY reaction for an artist
    print("\n3. Setting up notification for an artist...")
    
    # Get an artist
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
    
    # Create NOTIFY reaction
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
    
    print(f"✅ NOTIFY reaction created for {artist_name}")
    
    # Step 4: Test admin notification endpoint
    print("\n4. Testing admin notification endpoint...")
    
    # This would require admin access - skip if not admin
    admin_test_response = requests.post(f"{BASE_URL}/admin/api/send-test-notification",
        headers=headers,
        json={"artist_id": artist_id}
    )
    
    if admin_test_response.status_code == 403:
        print("⏭️  Skipping admin test (not admin user)")
    elif admin_test_response.status_code == 200:
        print("✅ Admin notification test successful")
    else:
        print(f"⚠️  Admin notification test failed: {admin_test_response.text}")
    
    print("\n🎉 APNs workflow test completed!")
    print("\n📱 To test with real notifications:")
    print("1. Get a real device token from your iOS app")
    print("2. Set up APNs credentials (auth key, team ID)")
    print("3. Use the admin endpoint to send test notifications")
    print("4. Check your device for notifications")
    
    return True

def print_apns_setup_guide():
    """Print a guide for setting up APNs."""
    print("\n📋 APNs Setup Guide:")
    print("\n1. **Get APNs Auth Key:**")
    print("   - Go to Apple Developer Console")
    print("   - Keys -> Create a key")
    print("   - Enable Apple Push Notifications service (APNs)")
    print("   - Download the .p8 file and note the Key ID")
    
    print("\n2. **Environment Variables:**")
    print("   export APNS_AUTH_KEY_ID='your_key_id'")
    print("   export APNS_TEAM_ID='your_team_id'")
    print("   export APNS_BUNDLE_ID='com.yourapp.nachna'")
    
    print("\n3. **iOS App Setup:**")
    print("   - Enable Push Notifications capability")
    print("   - Register for remote notifications")
    print("   - Send device token to server")
    
    print("\n4. **Testing Tools:**")
    print("   - Pusher (macOS app for APNs testing)")
    print("   - Terminal: curl commands to APNs")
    print("   - Xcode Device Logs")
    
    print("\n5. **Device Token Extraction:**")
    print("   Add this to your iOS app:")
    print("""
   func application(_ application: UIApplication, 
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
       let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
       print("Device Token: \\(tokenString)")
       // Send to your server
   }
   """)

def test_with_real_device_token():
    """Test with a real device token (requires manual input)."""
    print("\n📱 Testing with Real Device Token")
    
    device_token = input("Enter your iOS device token (64 hex characters): ").strip()
    
    if len(device_token) != 64:
        print("❌ Invalid device token length. Should be 64 hex characters.")
        return False
    
    print(f"\n🧪 Testing with device token: {device_token[:10]}...")
    
    # Login
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
    
    # Check if user is admin
    config_response = requests.get(f"{BASE_URL}/config", headers=headers)
    is_admin = config_response.json().get("is_admin", False) if config_response.status_code == 200 else False
    
    if not is_admin:
        print("❌ Admin access required for APNs testing")
        return False
    
    # Send test notification
    test_response = requests.post(f"{BASE_URL}/admin/api/test-apns",
        headers=headers,
        json={
            "device_token": device_token,
            "title": "Nachna Test",
            "body": "This is a test notification from your Nachna app! 🎉"
        }
    )
    
    if test_response.status_code == 200:
        print("✅ Test notification sent! Check your device.")
        return True
    else:
        print(f"❌ Failed to send notification: {test_response.text}")
        return False

def main():
    """Main function with testing options."""
    print("🍎 APNs Testing Suite")
    print("\nOptions:")
    print("1. Test APNs workflow (dummy tokens)")
    print("2. Setup guide")
    print("3. Test with real device token")
    print("4. All of the above")
    
    choice = input("\nSelect option (1-4): ").strip()
    
    if choice in ["1", "4"]:
        test_apns_workflow()
    
    if choice in ["2", "4"]:
        print_apns_setup_guide()
    
    if choice in ["3", "4"]:
        if choice == "4":
            proceed = input("\nDo you have a real device token to test? (y/n): ").strip().lower()
            if proceed == "y":
                test_with_real_device_token()
        else:
            test_with_real_device_token()

if __name__ == "__main__":
    main() 