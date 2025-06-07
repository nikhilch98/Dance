#!/usr/bin/env python3
"""
Test script for the app insights API endpoint.
"""

import requests
import json

# Test configuration
BASE_URL = "https://nachna.com/admin"
TEST_USER_MOBILE = "9999999999"
TEST_USER_PASSWORD = "test123"

def test_app_insights_api():
    """Test the app insights API endpoint."""
    print("🧪 Testing App Insights API Endpoint")
    print("=" * 50)
    
    # Step 1: Login to get auth token
    print("1. Logging in...")
    login_response = requests.post(f"https://nachna.com/api/auth/login", json={
        "mobile_number": TEST_USER_MOBILE,
        "password": TEST_USER_PASSWORD
    })
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code}")
        print(f"Response: {login_response.text}")
        return
    
    login_data = login_response.json()
    if "access_token" not in login_data:
        print(f"❌ Login failed: {login_data}")
        return
    
    token = login_data["access_token"]
    print(f"✅ Login successful, token: {token[:20]}...")
    
    # Step 2: Test app insights endpoint
    print("\n2. Testing app insights endpoint...")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    insights_response = requests.get(f"{BASE_URL}/app-insights", headers=headers)
    
    print(f"📊 App Insights Response:")
    print(f"Status Code: {insights_response.status_code}")
    print(f"Headers: {dict(insights_response.headers)}")
    
    if insights_response.status_code == 200:
        try:
            insights_data = insights_response.json()
            print(f"✅ App Insights Response:")
            print(json.dumps(insights_data, indent=2))
            
            # Validate response structure
            if insights_data.get("success") and "data" in insights_data:
                data = insights_data["data"]
                required_fields = ["total_users", "total_likes", "total_follows", "total_workshops", "total_notifications_sent"]
                
                print(f"\n📋 Validating response structure...")
                for field in required_fields:
                    if field in data:
                        print(f"✅ {field}: {data[field]}")
                    else:
                        print(f"❌ Missing field: {field}")
                        
                print(f"✅ App Insights API is working correctly!")
                
            else:
                print(f"❌ Invalid response structure: {insights_data}")
                
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse JSON response: {e}")
            print(f"Raw response: {insights_response.text}")
            
    else:
        print(f"❌ App Insights request failed: {insights_response.status_code}")
        print(f"Response: {insights_response.text}")

if __name__ == "__main__":
    test_app_insights_api() 