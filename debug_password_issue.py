#!/usr/bin/env python3
"""
Debug script to specifically test the password change issue.
This script will simulate the exact scenario the user described.
"""

import requests
import json

def test_password_change_issue():
    base_url = "https://nachna.com/api/auth"
    
    print("🔍 DEBUG: Testing the exact password change issue scenario")
    print("=" * 60)
    
    # Step 1: Create a test user with known credentials
    test_mobile = "9999888777"  # Different number to avoid conflicts
    initial_password = "initial123"
    new_password = "changed456"
    
    print(f"📱 Test mobile: {test_mobile}")
    print(f"🔑 Initial password: {initial_password}")
    print(f"🔄 New password: {new_password}")
    print()
    
    # Register or login with initial credentials
    print("1️⃣ Registering/logging in with initial credentials...")
    try:
        # Try to register
        response = requests.post(f"{base_url}/register", json={
            "mobile_number": test_mobile,
            "password": initial_password
        })
        
        if response.status_code == 200:
            print("✅ Registration successful")
            token = response.json()["access_token"]
        elif response.status_code == 400 and "already exists" in response.json().get("detail", ""):
            print("ℹ️  User exists, trying login...")
            # Try login
            response = requests.post(f"{base_url}/login", json={
                "mobile_number": test_mobile,
                "password": initial_password
            })
            if response.status_code == 200:
                print("✅ Login successful")
                token = response.json()["access_token"]
            else:
                print(f"❌ Login failed: {response.json()}")
                return
        else:
            print(f"❌ Registration failed: {response.json()}")
            return
    except Exception as e:
        print(f"❌ Error in step 1: {e}")
        return
    
    print(f"🎫 Token obtained: {token[:20]}...")
    print()
    
    # Step 2: Test password change
    print("2️⃣ Testing password change...")
    try:
        response = requests.put(f"{base_url}/password", 
            json={
                "current_password": initial_password,
                "new_password": new_password
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        
        print(f"📊 Password update response status: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ Password update API returned success")
            try:
                response_data = response.json()
                print(f"📄 Response data: {response_data}")
            except:
                print("📄 Response data: (empty or non-JSON)")
        else:
            print(f"❌ Password update failed: {response.json()}")
            return
    except Exception as e:
        print(f"❌ Error in step 2: {e}")
        return
    
    print()
    
    # Step 3: Verify old password no longer works
    print("3️⃣ Testing old password (should fail)...")
    try:
        response = requests.post(f"{base_url}/login", json={
            "mobile_number": test_mobile,
            "password": initial_password
        })
        
        if response.status_code == 401:
            print("✅ Old password correctly rejected")
        else:
            print(f"❌ Old password still works! Status: {response.status_code}")
            print("🚨 This indicates the password was NOT actually changed!")
            return
    except Exception as e:
        print(f"❌ Error in step 3: {e}")
        return
    
    print()
    
    # Step 4: Verify new password works
    print("4️⃣ Testing new password (should work)...")
    try:
        response = requests.post(f"{base_url}/login", json={
            "mobile_number": test_mobile,
            "password": new_password
        })
        
        if response.status_code == 200:
            print("✅ New password works correctly")
            print("🎉 PASSWORD CHANGE IS WORKING PROPERLY!")
        else:
            print(f"❌ New password doesn't work! Status: {response.status_code}")
            print(f"📄 Response: {response.json()}")
            print("🚨 This indicates a password change issue!")
            return
    except Exception as e:
        print(f"❌ Error in step 4: {e}")
        return
    
    print()
    
    # Step 5: Test wrong current password scenario
    print("5️⃣ Testing password change with wrong current password...")
    try:
        response = requests.put(f"{base_url}/password", 
            json={
                "current_password": "wrong_password_123",
                "new_password": "another_new_pass"
            },
            headers={"Authorization": f"Bearer {token}"}
        )
        
        if response.status_code == 400:
            print("✅ Wrong current password correctly rejected")
            print(f"📄 Error message: {response.json()}")
        else:
            print(f"❌ Wrong current password was accepted! Status: {response.status_code}")
            print("🚨 This indicates a validation issue!")
    except Exception as e:
        print(f"❌ Error in step 5: {e}")
    
    print("\n" + "=" * 60)
    print("🎯 CONCLUSION: Backend password change functionality is working correctly.")
    print("💡 If the Flutter app shows success but password doesn't change,")
    print("   the issue is likely in the Flutter UI error handling or state management.")

def test_flutter_ui_scenario():
    """Test scenarios that might cause Flutter UI to show success incorrectly"""
    print("\n🎨 FLUTTER UI SCENARIOS TO CHECK:")
    print("=" * 60)
    
    scenarios = [
        "1. Network timeout causing success message to show before error",
        "2. AuthProvider returning true even when API call fails",
        "3. Error message being cleared before user sees it",
        "4. UI showing cached success state",
        "5. Exception handling showing success instead of error",
        "6. Token expiration causing silent failures",
        "7. Incorrect API endpoint being called"
    ]
    
    for scenario in scenarios:
        print(f"🔍 {scenario}")
    
    print("\n💡 DEBUGGING RECOMMENDATIONS:")
    print("- Add debug prints in AuthService.updatePassword()")
    print("- Add debug prints in AuthProvider.updatePassword()")
    print("- Check network logs in Flutter app")
    print("- Verify API endpoint URLs in Flutter code")
    print("- Test with network disconnected to see error handling")

if __name__ == "__main__":
    test_password_change_issue()
    test_flutter_ui_scenario() 