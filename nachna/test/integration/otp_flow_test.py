#!/usr/bin/env python3
"""
Test OTP Authentication Flow End-to-End
Tests the complete OTP authentication workflow including:
1. Send OTP to mobile number
2. Verify OTP and get access token
3. Access protected endpoints with token
"""

import requests
import json
import time
from typing import Dict, Any


class OTPAuthFlowTest:
    def __init__(self):
        self.base_url = "https://nachna.com/api/auth"
        self.test_mobile = "9999999999"
        self.test_otp = "123456"  # This would be the actual OTP in real testing
        self.access_token = None
        
    def log_test(self, step: str, success: bool, message: str):
        """Log test results"""
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {step}: {message}")
        
    def send_otp(self) -> bool:
        """Test sending OTP to mobile number"""
        try:
            url = f"{self.base_url}/send-otp"
            payload = {
                "mobile_number": self.test_mobile
            }
            
            response = requests.post(url, json=payload, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                self.log_test("Send OTP", True, f"OTP sent successfully: {data.get('message', 'Success')}")
                return True
            else:
                self.log_test("Send OTP", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_test("Send OTP", False, f"Exception: {str(e)}")
            return False
    
    def verify_otp(self) -> bool:
        """Test verifying OTP and getting access token"""
        try:
            url = f"{self.base_url}/verify-otp"
            payload = {
                "mobile_number": self.test_mobile,
                "otp": self.test_otp
            }
            
            response = requests.post(url, json=payload, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                self.access_token = data.get('access_token')
                
                if self.access_token:
                    self.log_test("Verify OTP", True, f"Token received: {self.access_token[:20]}...")
                    
                    # Verify user profile in response
                    user_profile = data.get('user_profile', {})
                    if user_profile.get('mobile_number') == self.test_mobile:
                        self.log_test("User Profile", True, f"User profile verified for mobile: {self.test_mobile}")
                        return True
                    else:
                        self.log_test("User Profile", False, "User profile missing or incorrect")
                        return False
                else:
                    self.log_test("Verify OTP", False, "Access token not found in response")
                    return False
            else:
                self.log_test("Verify OTP", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_test("Verify OTP", False, f"Exception: {str(e)}")
            return False
    
    def test_protected_endpoint(self) -> bool:
        """Test accessing a protected endpoint with the token"""
        if not self.access_token:
            self.log_test("Protected Endpoint", False, "No access token available")
            return False
            
        try:
            url = f"{self.base_url}/profile"  # Assuming this is a protected endpoint
            headers = {
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json"
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                self.log_test("Protected Endpoint", True, f"Profile accessed successfully")
                return True
            else:
                self.log_test("Protected Endpoint", False, f"HTTP {response.status_code}: {response.text}")
                return False
                
        except Exception as e:
            self.log_test("Protected Endpoint", False, f"Exception: {str(e)}")
            return False
    
    def test_invalid_otp(self) -> bool:
        """Test that invalid OTP is rejected"""
        try:
            url = f"{self.base_url}/verify-otp"
            payload = {
                "mobile_number": self.test_mobile,
                "otp": "000000"  # Invalid OTP
            }
            
            response = requests.post(url, json=payload, timeout=10)
            
            # Should fail with 400 or 401
            if response.status_code in [400, 401]:
                self.log_test("Invalid OTP", True, "Invalid OTP correctly rejected")
                return True
            else:
                self.log_test("Invalid OTP", False, f"Unexpected response: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            self.log_test("Invalid OTP", False, f"Exception: {str(e)}")
            return False
    
    def test_invalid_mobile(self) -> bool:
        """Test that invalid mobile number is rejected"""
        try:
            url = f"{self.base_url}/send-otp"
            payload = {
                "mobile_number": "123"  # Invalid mobile number
            }
            
            response = requests.post(url, json=payload, timeout=10)
            
            # Should fail with 400
            if response.status_code == 400:
                self.log_test("Invalid Mobile", True, "Invalid mobile number correctly rejected")
                return True
            else:
                self.log_test("Invalid Mobile", False, f"Unexpected response: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            self.log_test("Invalid Mobile", False, f"Exception: {str(e)}")
            return False
    
    def run_complete_test(self):
        """Run the complete OTP authentication flow test"""
        print("🧪 Starting OTP Authentication Flow Test")
        print("=" * 50)
        
        # Test 1: Send OTP
        print("\n📱 Testing Send OTP...")
        send_success = self.send_otp()
        
        # Wait a moment before verification
        if send_success:
            print("⏳ Waiting 2 seconds before verification...")
            time.sleep(2)
        
        # Test 2: Verify OTP
        print("\n🔐 Testing Verify OTP...")
        verify_success = self.verify_otp() if send_success else False
        
        # Test 3: Protected endpoint access
        print("\n🛡️ Testing Protected Endpoint...")
        protected_success = self.test_protected_endpoint() if verify_success else False
        
        # Test 4: Invalid OTP handling
        print("\n❌ Testing Invalid OTP...")
        invalid_otp_success = self.test_invalid_otp()
        
        # Test 5: Invalid mobile handling
        print("\n📞 Testing Invalid Mobile...")
        invalid_mobile_success = self.test_invalid_mobile()
        
        # Summary
        print("\n" + "=" * 50)
        print("📊 TEST SUMMARY")
        print("=" * 50)
        
        total_tests = 5
        passed_tests = sum([
            send_success,
            verify_success,
            protected_success,
            invalid_otp_success,
            invalid_mobile_success
        ])
        
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {total_tests - passed_tests}")
        print(f"Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if passed_tests == total_tests:
            print("\n🎉 ALL TESTS PASSED! OTP Authentication flow is working correctly.")
        else:
            print(f"\n⚠️ {total_tests - passed_tests} test(s) failed. Please check the implementation.")
        
        return passed_tests == total_tests


if __name__ == "__main__":
    tester = OTPAuthFlowTest()
    tester.run_complete_test() 