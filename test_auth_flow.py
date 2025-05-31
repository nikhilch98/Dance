#!/usr/bin/env python3
"""
Comprehensive test script for the Dance Workshop authentication flow.
This script tests all authentication endpoints to identify the password change issue.
"""

import requests
import json
import sys
from typing import Optional, Dict, Any

class AuthFlowTester:
    def __init__(self, base_url: str = "https://nachna.com/api/auth"):
        self.base_url = base_url
        self.current_token: Optional[str] = None
        self.test_user = {
            "mobile_number": "9876543210",
            "password": "newpass123",  # Current password from previous tests
            "new_password": "finalpass789"  # New password to test with
        }
        
    def log(self, message: str, level: str = "INFO"):
        """Log messages with formatting"""
        print(f"[{level}] {message}")
        
    def make_request(self, method: str, endpoint: str, data: Dict[Any, Any] = None, 
                    headers: Dict[str, str] = None) -> requests.Response:
        """Make HTTP request with error handling"""
        url = f"{self.base_url}{endpoint}"
        default_headers = {"Content-Type": "application/json"}
        
        if headers:
            default_headers.update(headers)
            
        try:
            if method == "POST":
                response = requests.post(url, json=data, headers=default_headers)
            elif method == "PUT":
                response = requests.put(url, json=data, headers=default_headers)
            elif method == "GET":
                response = requests.get(url, headers=default_headers)
            else:
                raise ValueError(f"Unsupported method: {method}")
                
            self.log(f"{method} {endpoint} -> Status: {response.status_code}")
            return response
        except Exception as e:
            self.log(f"Request failed: {e}", "ERROR")
            raise
            
    def test_registration(self) -> bool:
        """Test user registration"""
        self.log("Testing user registration...")
        
        try:
            response = self.make_request("POST", "/register", {
                "mobile_number": self.test_user["mobile_number"],
                "password": self.test_user["password"]
            })
            
            if response.status_code == 200:
                data = response.json()
                self.current_token = data["access_token"]
                self.log("✅ Registration successful")
                self.log(f"Token: {self.current_token[:20]}...")
                return True
            elif response.status_code == 400:
                error_data = response.json()
                if "already exists" in error_data.get("detail", ""):
                    self.log("ℹ️  User already exists, proceeding to login")
                    return self.test_login()
                else:
                    self.log(f"❌ Registration failed: {error_data}", "ERROR")
                    return False
            else:
                self.log(f"❌ Registration failed with status {response.status_code}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Registration error: {e}", "ERROR")
            return False
            
    def test_login(self) -> bool:
        """Test user login"""
        self.log("Testing user login...")
        
        try:
            response = self.make_request("POST", "/login", {
                "mobile_number": self.test_user["mobile_number"],
                "password": self.test_user["password"]
            })
            
            if response.status_code == 200:
                data = response.json()
                self.current_token = data["access_token"]
                self.log("✅ Login successful")
                self.log(f"Token: {self.current_token[:20]}...")
                
                # Check user profile data
                user = data["user"]
                self.log(f"User ID: {user['user_id']}")
                self.log(f"Mobile: {user['mobile_number']}")
                self.log(f"Profile Complete: {user['profile_complete']}")
                return True
            else:
                error_data = response.json()
                self.log(f"❌ Login failed: {error_data}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Login error: {e}", "ERROR")
            return False
            
    def test_profile_fetch(self) -> bool:
        """Test fetching current user profile"""
        self.log("Testing profile fetch...")
        
        if not self.current_token:
            self.log("❌ No token available for profile fetch", "ERROR")
            return False
            
        try:
            headers = {"Authorization": f"Bearer {self.current_token}"}
            response = self.make_request("GET", "/profile", headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                self.log("✅ Profile fetch successful")
                self.log(f"Profile data: {json.dumps(data, indent=2)}")
                return True
            else:
                error_data = response.json()
                self.log(f"❌ Profile fetch failed: {error_data}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Profile fetch error: {e}", "ERROR")
            return False
            
    def test_password_update(self) -> bool:
        """Test password update functionality"""
        self.log("Testing password update...")
        
        if not self.current_token:
            self.log("❌ No token available for password update", "ERROR")
            return False
            
        try:
            headers = {"Authorization": f"Bearer {self.current_token}"}
            response = self.make_request("PUT", "/password", {
                "current_password": self.test_user["password"],
                "new_password": self.test_user["new_password"]
            }, headers=headers)
            
            if response.status_code == 200:
                self.log("✅ Password update successful")
                try:
                    data = response.json()
                    self.log(f"Response: {data}")
                except:
                    self.log("Response: (empty or non-JSON)")
                    
                # Update our current password for subsequent tests
                self.test_user["password"] = self.test_user["new_password"]
                return True
            else:
                error_data = response.json()
                self.log(f"❌ Password update failed: {error_data}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Password update error: {e}", "ERROR")
            return False
            
    def test_login_with_old_password(self) -> bool:
        """Test login with old password (should fail)"""
        self.log("Testing login with old password (should fail)...")
        
        try:
            response = self.make_request("POST", "/login", {
                "mobile_number": self.test_user["mobile_number"],
                "password": "newpass123"  # The original password before update
            })
            
            if response.status_code == 401:
                self.log("✅ Login with old password correctly failed")
                return True
            else:
                self.log(f"❌ Login with old password should have failed but got status {response.status_code}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Login with old password test error: {e}", "ERROR")
            return False
            
    def test_login_with_new_password(self) -> bool:
        """Test login with new password (should succeed)"""
        self.log("Testing login with new password (should succeed)...")
        
        try:
            response = self.make_request("POST", "/login", {
                "mobile_number": self.test_user["mobile_number"],
                "password": self.test_user["new_password"]  # New password
            })
            
            if response.status_code == 200:
                data = response.json()
                self.current_token = data["access_token"]  # Update token
                self.log("✅ Login with new password successful")
                return True
            else:
                error_data = response.json()
                self.log(f"❌ Login with new password failed: {error_data}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Login with new password test error: {e}", "ERROR")
            return False
            
    def test_profile_update(self) -> bool:
        """Test profile update to see if it shows success incorrectly"""
        self.log("Testing profile update...")
        
        if not self.current_token:
            self.log("❌ No token available for profile update", "ERROR")
            return False
            
        try:
            headers = {"Authorization": f"Bearer {self.current_token}"}
            response = self.make_request("PUT", "/profile", {
                "name": "Test User",
                "gender": "male"
            }, headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                self.log("✅ Profile update successful")
                self.log(f"Updated profile: {json.dumps(data, indent=2)}")
                return True
            else:
                error_data = response.json()
                self.log(f"❌ Profile update failed: {error_data}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Profile update error: {e}", "ERROR")
            return False
            
    def test_wrong_current_password(self) -> bool:
        """Test password update with wrong current password (should fail)"""
        self.log("Testing password update with wrong current password (should fail)...")
        
        if not self.current_token:
            self.log("❌ No token available for password update", "ERROR")
            return False
            
        try:
            headers = {"Authorization": f"Bearer {self.current_token}"}
            response = self.make_request("PUT", "/password", {
                "current_password": "wrongpassword123",  # Wrong current password
                "new_password": "anothernewpass"
            }, headers=headers)
            
            if response.status_code == 400:
                self.log("✅ Password update with wrong current password correctly failed")
                return True
            else:
                self.log(f"❌ Password update with wrong current password should have failed but got status {response.status_code}", "ERROR")
                return False
        except Exception as e:
            self.log(f"❌ Password update with wrong current password test error: {e}", "ERROR")
            return False
            
    def run_full_test(self) -> None:
        """Run the complete authentication flow test"""
        self.log("🚀 Starting comprehensive authentication flow test")
        self.log("=" * 60)
        
        tests = [
            ("Registration/Login", self.test_registration),
            ("Profile Fetch", self.test_profile_fetch),
            ("Password Update", self.test_password_update),
            ("Login with Old Password", self.test_login_with_old_password),
            ("Login with New Password", self.test_login_with_new_password),
            ("Profile Update", self.test_profile_update),
            ("Wrong Current Password", self.test_wrong_current_password),
        ]
        
        results = []
        for test_name, test_func in tests:
            self.log(f"\n--- {test_name} ---")
            try:
                result = test_func()
                results.append((test_name, result))
            except Exception as e:
                self.log(f"❌ {test_name} failed with exception: {e}", "ERROR")
                results.append((test_name, False))
                
        self.log("\n" + "=" * 60)
        self.log("📊 TEST RESULTS SUMMARY")
        self.log("=" * 60)
        
        for test_name, passed in results:
            status = "✅ PASS" if passed else "❌ FAIL"
            self.log(f"{test_name}: {status}")
            
        passed_count = sum(1 for _, passed in results if passed)
        total_count = len(results)
        self.log(f"\nOverall: {passed_count}/{total_count} tests passed")
        
        if passed_count == total_count:
            self.log("🎉 All tests passed! Authentication flow is working correctly.")
        else:
            self.log("⚠️  Some tests failed. Check the logs above for details.")
            
        # Additional analysis
        password_update_passed = next((passed for name, passed in results if "Password Update" in name and "Wrong" not in name), False)
        old_password_failed = next((passed for name, passed in results if "Old Password" in name), False)
        new_password_passed = next((passed for name, passed in results if "New Password" in name), False)
        wrong_password_failed = next((passed for name, passed in results if "Wrong Current Password" in name), False)
        
        if password_update_passed and old_password_failed and new_password_passed:
            self.log("\n✅ PASSWORD CHANGE FUNCTIONALITY IS WORKING CORRECTLY")
            self.log("The backend API properly updates passwords and validates credentials.")
            if wrong_password_failed:
                self.log("✅ Password validation is also working correctly.")
            self.log("If there's an issue in the Flutter app, it's likely in the UI layer.")
        elif password_update_passed and not (old_password_failed and new_password_passed):
            self.log("\n⚠️  PASSWORD UPDATE API CLAIMS SUCCESS BUT PASSWORD NOT ACTUALLY CHANGED")
            self.log("This suggests an issue in the backend password update implementation.")
        else:
            self.log("\n❌ PASSWORD UPDATE API IS FAILING")
            self.log("Check the backend implementation and database connection.")

if __name__ == "__main__":
    tester = AuthFlowTester()
    tester.run_full_test() 