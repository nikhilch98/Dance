#!/usr/bin/env python3
"""
Test script for the new admin workshop refresh functionality
"""

import requests
import json
import time
import sys
import os
from dotenv import load_dotenv

load_dotenv()

def test_admin_endpoints():
    """Test the new admin workshop refresh endpoints"""
    
    # Configuration
    BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8002")
    # You'll need a valid admin token, or use --get-token to fetch one automatically
    ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "YOUR_ADMIN_TOKEN_HERE")
    
    headers = {
        "Authorization": f"Bearer {ADMIN_TOKEN}",
        "Content-Type": "application/json"
    }
    
    print("🧪 Testing Admin Workshop Refresh Endpoints")
    print("=" * 50)
    
    try:
        # Test 1: Get studios for refresh
        print("\n1️⃣ Testing GET /admin/api/studios-for-refresh")
        response = requests.get(f"{BASE_URL}/admin/api/studios-for-refresh", headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Success: Found {len(data.get('studios', []))} studios")
            for studio in data.get('studios', []):
                print(f"   - {studio['name']} ({studio['studio_id']})")
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    try:
        # Test 2: Start workshop refresh
        print("\n2️⃣ Testing POST /admin/api/refresh-studio-workshops")
        refresh_data = {
            "studio_id": "dance_n_addiction",
            "ai_model": "gemini"
        }
        
        response = requests.post(
            f"{BASE_URL}/admin/api/refresh-studio-workshops", 
            headers=headers, 
            json=refresh_data
        )
        
        if response.status_code == 200:
            data = response.json()
            session_id = data.get('session_id')
            print(f"✅ Success: Workshop refresh started")
            print(f"   Session ID: {session_id}")
            
            # Test 3: Check progress
            if session_id:
                print("\n3️⃣ Testing GET /admin/api/refresh-progress/{session_id}")
                time.sleep(2)  # Wait a bit for the process to start
                
                for i in range(5):  # Check progress 5 times
                    progress_response = requests.get(
                        f"{BASE_URL}/admin/api/refresh-progress/{session_id}", 
                        headers=headers
                    )
                    
                    if progress_response.status_code == 200:
                        progress_data = progress_response.json()
                        print(f"   Progress: {progress_data.get('progress', 0)}% - {progress_data.get('message', 'Unknown')}")
                        
                        if progress_data.get('status') in ['completed', 'error']:
                            break
                    else:
                        print(f"   ❌ Progress check failed: {progress_response.status_code}")
                        break
                    
                    time.sleep(3)  # Wait between checks
                    
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    print("\n✨ Test completed!")
    print("\n📝 Note: To run this test properly:")
    print("1. Make sure your server is running on localhost:8002")
    print("2. Update the ADMIN_TOKEN variable with a valid admin token")
    print("3. Ensure you have the required environment variables set (API keys)")

def get_admin_token():
    """Helper function to get an admin token for testing"""
    BASE_URL = "http://localhost:8002"
    
    # Login with test credentials
    login_data = {
        "mobile_number": "9999999999",  # Test admin user
        "password": "test123"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
        if response.status_code == 200:
            data = response.json()
            return data.get('access_token')
        else:
            print(f"Login failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Login error: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--get-token":
        print("🔑 Getting admin token...")
        token = get_admin_token()
        if token:
            print(f"✅ Admin token: {token}")
        else:
            print("❌ Failed to get admin token")
    else:
        test_admin_endpoints() 