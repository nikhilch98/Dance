#!/usr/bin/env python3
"""Test script for OTP authentication API."""

import os
import requests
import json
from time import sleep


# API Base URL
BASE_URL = "https://nachna.com/api/auth"  # Update this if running locally

def test_send_otp(mobile_number):
    """Test sending OTP to mobile number."""
    print(f"\n=== Testing Send OTP for {mobile_number} ===")
    
    url = f"{BASE_URL}/send-otp"
    payload = {
        "mobile_number": mobile_number
    }
    
    try:
        response = requests.post(url, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ OTP sent successfully!")
            return True
        else:
            print(f"❌ Failed to send OTP: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error sending OTP: {e}")
        return False

def test_verify_otp(mobile_number, otp_code):
    """Test verifying OTP and login."""
    print(f"\n=== Testing Verify OTP for {mobile_number} with OTP: {otp_code} ===")
    
    url = f"{BASE_URL}/verify-otp"
    payload = {
        "mobile_number": mobile_number,
        "otp": otp_code
    }
    
    try:
        response = requests.post(url, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ OTP verified successfully!")
            print(f"Access Token: {data.get('access_token', 'N/A')[:50]}...")
            print(f"User ID: {data.get('user', {}).get('user_id', 'N/A')}")
            print(f"Mobile Number: {data.get('user', {}).get('mobile_number', 'N/A')}")
            print(f"Profile Complete: {data.get('user', {}).get('profile_complete', 'N/A')}")
            return data.get('access_token')
        else:
            print(f"❌ Failed to verify OTP: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error verifying OTP: {e}")
        return None

def test_profile_with_token(access_token):
    """Test accessing profile with the received token."""
    print(f"\n=== Testing Profile Access with Token ===")
    
    url = f"{BASE_URL}/profile"
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ Profile access successful!")
            return True
        else:
            print(f"❌ Failed to access profile: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error accessing profile: {e}")
        return False

def main():
    """Main test function."""
    print("🚀 Starting OTP Authentication API Tests")
    print("=" * 50)
    
    # Test mobile number (you can change this)
    test_mobile = "8985374940"  # Replace with your test number
    
    # Step 1: Send OTP
    otp_sent = test_send_otp(test_mobile)
    
    if not otp_sent:
        print("\n❌ Cannot proceed with tests - OTP sending failed")
        return
    
    # Step 2: Wait for manual OTP input
    print(f"\n📱 Please check your mobile number {test_mobile} for OTP")
    otp_code = input("Enter the 6-digit OTP you received: ").strip()
    
    if len(otp_code) != 6 or not otp_code.isdigit():
        print("❌ Invalid OTP format. Please enter a 6-digit number.")
        return
    
    # Step 3: Verify OTP
    access_token = test_verify_otp(test_mobile, otp_code)
    
    if not access_token:
        print("\n❌ Cannot proceed with tests - OTP verification failed")
        return
    
    # Step 4: Test profile access
    test_profile_with_token(access_token)
    
    print("\n🎉 All tests completed!")
    print("=" * 50)

if __name__ == "__main__":
    main() 