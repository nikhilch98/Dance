#!/usr/bin/env python3
"""Test APNs notifications directly."""

import asyncio
import httpx
import json

async def test_apns():
    """Test APNs notification endpoint."""
    
    # Test user credentials
    test_user = {
        "mobile_number": "9999999999",
        "password": "test123"
    }
    
    # Your device token
    device_token = "1b91e638af31d90bfae0748aa27e2f5bf6916b45d7148a02e9d95cfabce34bca"
    
    base_url = "https://nachna.com"
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        # First, login to get auth token
        print("🔐 Logging in...")
        login_response = await client.post(
            f"{base_url}/api/auth/login",
            json=test_user
        )
        
        if login_response.status_code != 200:
            print(f"❌ Login failed: {login_response.status_code}")
            print(login_response.text)
            return
            
        auth_data = login_response.json()
        token = auth_data["access_token"]
        print(f"✅ Logged in successfully")
        
        # Test APNs notification
        print(f"\n📱 Testing APNs notification to device token: {device_token[:20]}...")
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        notification_data = {
            "device_token": device_token,
            "title": "Test Notification 🎉",
            "body": "This is a test notification from the Nachna app!"
        }
        
        try:
            response = await client.post(
                f"{base_url}/admin/api/test-apns",
                headers=headers,
                json=notification_data
            )
            
            print(f"Response status: {response.status_code}")
            print(f"Response body: {response.text}")
            
            if response.status_code == 200:
                print("✅ Notification sent successfully!")
            else:
                print(f"❌ Failed to send notification: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_apns()) 