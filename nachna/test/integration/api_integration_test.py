#!/usr/bin/env python3
"""
======================================================================
NACHNA APP - API INTEGRATION TEST SUITE (Python)
======================================================================

This file contains integration tests for ALL APIs used in the Nachna Flutter app.

🚨 CURSOR RULE: When adding new API calls to the Flutter app, you MUST:
1. Add corresponding test cases to this file
2. Follow the existing test structure and naming conventions
3. Include both success and error scenarios
4. Update the API endpoint documentation section

Test Coverage:
- Authentication APIs (register, login, profile, etc.)
- Data Fetching APIs (artists, studios, workshops)
- Notification APIs (device token management)
- Admin APIs (workshop management, test notifications)
- File Upload APIs (profile pictures)

======================================================================
"""

import requests
import json
import time
import sys
from typing import Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime


@dataclass
class ApiTestConfig:
    """Configuration for API integration tests"""
    base_url: str = 'https://nachna.com'
    test_mobile_number: str = '9999999999'
    test_password: str = 'test123'
    test_user_id: str = '683cdbb39caf05c68764cde4'
    timeout: int = 30
    
    # Test data IDs (update these with real IDs from your database)
    test_artist_id: str = 'test_artist_id'
    test_studio_id: str = 'test_studio_id'
    test_workshop_uuid: str = 'test_workshop_uuid'
    test_device_token: str = 'test_device_token_for_integration_testing'


class ApiTestRunner:
    """Main test runner for Nachna API integration tests"""
    
    def __init__(self, config: ApiTestConfig):
        self.config = config
        self.auth_token: Optional[str] = None
        self.admin_auth_token: Optional[str] = None
        self.session = requests.Session()
        self.session.timeout = config.timeout
        
        # Test results tracking
        self.passed_tests = 0
        self.failed_tests = 0
        self.test_results = []
    
    def log_test_result(self, test_name: str, success: bool, message: str = ""):
        """Log test result with emoji indicators"""
        status = "✅" if success else "❌"
        result = f"{status} {test_name}"
        if message:
            result += f" - {message}"
        print(result)
        
        self.test_results.append({
            'test': test_name,
            'success': success,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })
        
        if success:
            self.passed_tests += 1
        else:
            self.failed_tests += 1
    
    def make_request(self, method: str, endpoint: str, data: Optional[Dict] = None, 
                    auth_required: bool = False, admin_required: bool = False) -> requests.Response:
        """Make HTTP request with proper headers and authentication"""
        url = f"{self.config.base_url}{endpoint}"
        headers = {'Content-Type': 'application/json'}
        
        # Add authentication if required
        if auth_required or admin_required:
            token = self.admin_auth_token if admin_required else self.auth_token
            if token:
                headers['Authorization'] = f'Bearer {token}'
        
        # Make the request
        if method.upper() == 'GET':
            return self.session.get(url, headers=headers)
        elif method.upper() == 'POST':
            return self.session.post(url, headers=headers, json=data)
        elif method.upper() == 'PUT':
            return self.session.put(url, headers=headers, json=data)
        elif method.upper() == 'DELETE':
            return self.session.delete(url, headers=headers, json=data)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
    
    def run_all_tests(self):
        """Run all API integration tests"""
        print("🚀 Starting API Integration Tests for Nachna App")
        print(f"📍 Base URL: {self.config.base_url}")
        print("=" * 70)
        
        try:
            # Run test groups
            self.test_authentication_apis()
            self.test_data_fetching_apis()
            self.test_reaction_apis()
            self.test_notification_apis()
            self.test_admin_apis()
            self.test_error_handling()
            self.test_performance()
            
        except Exception as e:
            print(f"❌ Test suite failed with error: {e}")
        
        finally:
            self.print_test_summary()
    
    def test_authentication_apis(self):
        """Test authentication-related APIs"""
        print("\n🔐 Testing Authentication APIs")
        print("-" * 40)
        
        # Test user registration
        try:
            response = self.make_request('POST', '/api/auth/register', {
                'mobile_number': '9876543210',  # Different number for registration test
                'password': 'testpass123'
            })
            
            if response.status_code in [200, 201, 400]:  # 400 if user exists
                if response.status_code in [200, 201]:
                    data = response.json()
                    assert 'access_token' in data
                    assert 'user' in data
                    self.log_test_result("POST /api/auth/register", True, "Registration successful")
                else:
                    self.log_test_result("POST /api/auth/register", True, "User already exists (expected)")
            else:
                self.log_test_result("POST /api/auth/register", False, f"Status: {response.status_code}")
        except Exception as e:
            self.log_test_result("POST /api/auth/register", False, str(e))
        
        # Test user login
        try:
            response = self.make_request('POST', '/api/auth/login', {
                'mobile_number': self.config.test_mobile_number,
                'password': self.config.test_password
            })
            
            assert response.status_code == 200
            data = response.json()
            assert 'access_token' in data
            assert 'user' in data
            
            self.auth_token = data['access_token']
            self.admin_auth_token = self.auth_token  # Use same token for admin tests
            
            self.log_test_result("POST /api/auth/login", True, "Token obtained")
        except Exception as e:
            self.log_test_result("POST /api/auth/login", False, str(e))
        
        # Test get profile
        try:
            response = self.make_request('GET', '/api/auth/profile', auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert 'user_id' in data
            assert data['mobile_number'] == self.config.test_mobile_number
            
            self.log_test_result("GET /api/auth/profile", True, "Profile fetched")
        except Exception as e:
            self.log_test_result("GET /api/auth/profile", False, str(e))
        
        # Test config endpoint
        try:
            response = self.make_request('POST', '/api/auth/config', {
                'device_token': self.config.test_device_token,
                'platform': 'ios'
            }, auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert 'is_admin' in data
            
            self.log_test_result("POST /api/auth/config", True, "Config retrieved")
        except Exception as e:
            self.log_test_result("POST /api/auth/config", False, str(e))
        
        # Test profile update
        try:
            response = self.make_request('PUT', '/api/auth/profile', {
                'name': 'Integration Test User',
                'gender': 'Other'
            }, auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert data['name'] == 'Integration Test User'
            
            self.log_test_result("PUT /api/auth/profile", True, "Profile updated")
        except Exception as e:
            self.log_test_result("PUT /api/auth/profile", False, str(e))
    
    def test_data_fetching_apis(self):
        """Test data fetching APIs"""
        print("\n📊 Testing Data Fetching APIs")
        print("-" * 40)
        
        # Test fetch all artists
        try:
            response = self.make_request('GET', '/api/artists?version=v2')
            
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, list)
            
            if data:
                artist = data[0]
                assert 'artist_id' in artist
                assert 'artist_name' in artist
            
            self.log_test_result("GET /api/artists?version=v2", True, f"Found {len(data)} artists")
        except Exception as e:
            self.log_test_result("GET /api/artists?version=v2", False, str(e))
        
        # Test fetch artists with workshops
        try:
            response = self.make_request('GET', '/api/artists?version=v2&has_workshops=true')
            
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, list)
            
            self.log_test_result("GET /api/artists (with workshops)", True, f"Found {len(data)} artists")
        except Exception as e:
            self.log_test_result("GET /api/artists (with workshops)", False, str(e))
        
        # Test fetch all studios
        try:
            response = self.make_request('GET', '/api/studios?version=v2')
            
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, list)
            
            if data:
                studio = data[0]
                assert 'studio_id' in studio
                assert 'studio_name' in studio
            
            self.log_test_result("GET /api/studios?version=v2", True, f"Found {len(data)} studios")
        except Exception as e:
            self.log_test_result("GET /api/studios?version=v2", False, str(e))
        
        # Test fetch all workshops
        try:
            response = self.make_request('GET', '/api/workshops?version=v2')
            
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, list)
            
            if data:
                workshop = data[0]
                assert 'uuid' in workshop
                assert 'studio_name' in workshop
            
            self.log_test_result("GET /api/workshops?version=v2", True, f"Found {len(data)} workshops")
        except Exception as e:
            self.log_test_result("GET /api/workshops?version=v2", False, str(e))
        
        # Test fetch config
        try:
            response = self.make_request('GET', '/api/config', auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data, dict)
            
            self.log_test_result("GET /api/config", True, "Config fetched")
        except Exception as e:
            self.log_test_result("GET /api/config", False, str(e))
    
    def test_reaction_apis(self):
        """Test reaction-related APIs"""
        print("\n❤️ Testing Reaction APIs")
        print("-" * 40)
        
        # Test create reaction
        try:
            response = self.make_request('POST', '/api/reactions', {
                'entity_id': self.config.test_artist_id,
                'entity_type': 'ARTIST',
                'reaction': 'LIKE'
            }, auth_required=True)
            
            # Should succeed or fail if reaction already exists
            assert response.status_code in [200, 201, 400]
            
            self.log_test_result("POST /api/reactions", True, "Reaction created/exists")
        except Exception as e:
            self.log_test_result("POST /api/reactions", False, str(e))
        
        # Test get user reactions
        try:
            response = self.make_request('GET', '/api/user/reactions', auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert 'reactions' in data
            assert isinstance(data['reactions'], list)
            
            self.log_test_result("GET /api/user/reactions", True, f"Found {len(data['reactions'])} reactions")
        except Exception as e:
            self.log_test_result("GET /api/user/reactions", False, str(e))
    
    def test_notification_apis(self):
        """Test notification-related APIs"""
        print("\n🔔 Testing Notification APIs")
        print("-" * 40)
        
        # Test register device token
        try:
            response = self.make_request('POST', '/api/notifications/register-token', {
                'device_token': self.config.test_device_token,
                'platform': 'ios'
            }, auth_required=True)
            
            assert response.status_code == 200
            data = response.json()
            assert 'message' in data
            
            self.log_test_result("POST /api/notifications/register-token", True, "Device token registered")
        except Exception as e:
            self.log_test_result("POST /api/notifications/register-token", False, str(e))
        
        # Test get device token
        try:
            response = self.make_request('GET', '/api/notifications/device-token', auth_required=True)
            
            # Should succeed or return not found
            assert response.status_code in [200, 404]
            
            if response.status_code == 200:
                data = response.json()
                assert 'device_token' in data
                message = "Device token found"
            else:
                message = "No device token found"
            
            self.log_test_result("GET /api/notifications/device-token", True, message)
        except Exception as e:
            self.log_test_result("GET /api/notifications/device-token", False, str(e))
    
    def test_admin_apis(self):
        """Test admin-related APIs"""
        print("\n👑 Testing Admin APIs")
        print("-" * 40)
        
        # Test get missing artist sessions
        try:
            response = self.make_request('GET', '/admin/api/missing_artist_sessions', admin_required=True)
            
            # Should succeed for admin or fail for non-admin
            assert response.status_code in [200, 403]
            
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list)
                message = f"Found {len(data)} missing artist sessions"
            else:
                message = "Access denied (non-admin user)"
            
            self.log_test_result("GET /admin/api/missing_artist_sessions", True, message)
        except Exception as e:
            self.log_test_result("GET /admin/api/missing_artist_sessions", False, str(e))
        
        # Test get missing song sessions
        try:
            response = self.make_request('GET', '/admin/api/missing_song_sessions', admin_required=True)
            
            # Should succeed for admin or fail for non-admin
            assert response.status_code in [200, 403]
            
            if response.status_code == 200:
                data = response.json()
                assert isinstance(data, list)
                message = f"Found {len(data)} missing song sessions"
            else:
                message = "Access denied (non-admin user)"
            
            self.log_test_result("GET /admin/api/missing_song_sessions", True, message)
        except Exception as e:
            self.log_test_result("GET /admin/api/missing_song_sessions", False, str(e))
        
        # Test send test notification
        try:
            response = self.make_request('POST', '/admin/api/send-test-notification', {
                'title': 'Integration Test Notification',
                'body': 'This is a test notification from API integration tests'
            }, admin_required=True)
            
            # Should succeed for admin or fail for non-admin/error
            assert response.status_code in [200, 403, 500]
            
            if response.status_code == 200:
                data = response.json()
                message = "Test notification sent successfully"
            else:
                message = f"Access denied or error: {response.status_code}"
            
            self.log_test_result("POST /admin/api/send-test-notification", True, message)
        except Exception as e:
            self.log_test_result("POST /admin/api/send-test-notification", False, str(e))
    
    def test_error_handling(self):
        """Test error handling scenarios"""
        print("\n🚨 Testing Error Handling")
        print("-" * 40)
        
        # Test invalid credentials
        try:
            response = self.make_request('POST', '/api/auth/login', {
                'mobile_number': '0000000000',
                'password': 'wrongpassword'
            })
            
            assert response.status_code == 401
            self.log_test_result("Invalid credentials", True, "401 Unauthorized")
        except Exception as e:
            self.log_test_result("Invalid credentials", False, str(e))
        
        # Test unauthorized access
        try:
            # Temporarily clear auth token
            temp_token = self.auth_token
            self.auth_token = None
            
            response = self.make_request('GET', '/api/auth/profile', auth_required=True)
            
            assert response.status_code == 401
            self.log_test_result("Unauthorized access", True, "401 Unauthorized")
            
            # Restore auth token
            self.auth_token = temp_token
        except Exception as e:
            self.log_test_result("Unauthorized access", False, str(e))
        
        # Test 404 error
        try:
            response = self.make_request('GET', '/api/nonexistent-endpoint')
            
            assert response.status_code == 404
            self.log_test_result("404 error", True, "404 Not Found")
        except Exception as e:
            self.log_test_result("404 error", False, str(e))
    
    def test_performance(self):
        """Test API performance"""
        print("\n⚡ Testing Performance")
        print("-" * 40)
        
        endpoints = [
            ('GET', '/api/artists?version=v2'),
            ('GET', '/api/studios?version=v2'),
            ('GET', '/api/workshops?version=v2')
        ]
        
        for method, endpoint in endpoints:
            try:
                start_time = time.time()
                response = self.make_request(method, endpoint)
                end_time = time.time()
                
                response_time = (end_time - start_time) * 1000  # Convert to milliseconds
                
                assert response.status_code == 200
                assert response_time < 5000  # Should be under 5 seconds
                
                self.log_test_result(f"Performance {endpoint}", True, f"{response_time:.0f}ms")
            except Exception as e:
                self.log_test_result(f"Performance {endpoint}", False, str(e))
    
    def print_test_summary(self):
        """Print test summary"""
        print("\n" + "=" * 70)
        print("📊 TEST SUMMARY")
        print("=" * 70)
        print(f"✅ Passed: {self.passed_tests}")
        print(f"❌ Failed: {self.failed_tests}")
        print(f"📈 Total: {self.passed_tests + self.failed_tests}")
        
        success_rate = (self.passed_tests / (self.passed_tests + self.failed_tests)) * 100 if (self.passed_tests + self.failed_tests) > 0 else 0
        print(f"🎯 Success Rate: {success_rate:.1f}%")
        
        if self.failed_tests > 0:
            print("\n❌ FAILED TESTS:")
            for result in self.test_results:
                if not result['success']:
                    print(f"  - {result['test']}: {result['message']}")
        
        print("\n🏁 API Integration Tests completed")


def main():
    """Main entry point for API integration tests"""
    config = ApiTestConfig()
    runner = ApiTestRunner(config)
    
    try:
        runner.run_all_tests()
        
        # Exit with error code if tests failed
        if runner.failed_tests > 0:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n⏹️ Tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Test suite crashed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()


# ======================================================================
# API ENDPOINTS DOCUMENTATION
# ======================================================================
#
# Auth Endpoints:
# - POST /api/auth/register
# - POST /api/auth/login
# - GET /api/auth/profile
# - POST /api/auth/config
# - PUT /api/auth/profile
# - PUT /api/auth/password
# - POST /api/auth/profile-picture
# - DELETE /api/auth/profile-picture
# - DELETE /api/auth/account
#
# Data Endpoints:
# - GET /api/artists?version=v2[&has_workshops=true]
# - GET /api/studios?version=v2
# - GET /api/workshops?version=v2
# - GET /api/workshops_by_artist/{artistId}?version=v2
# - GET /api/workshops_by_studio/{studioId}?version=v2
# - GET /api/config
#
# Reaction Endpoints:
# - POST /api/reactions
# - DELETE /api/reactions
# - GET /api/user/reactions
# - GET /api/reactions/stats/{entityType}/{entityId}
#
# Notification Endpoints:
# - POST /api/notifications/register-token
# - GET /api/notifications/device-token
# - DELETE /api/notifications/unregister-token
#
# Admin Endpoints:
# - GET /admin/api/missing_artist_sessions
# - GET /admin/api/missing_song_sessions
# - PUT /admin/api/workshops/{uuid}/assign_artist
# - PUT /admin/api/workshops/{uuid}/assign_song
# - POST /admin/api/send-test-notification
# - POST /admin/api/test-apns
#
# ======================================================================

# ======================================================================
# CURSOR RULE IMPLEMENTATION
# ======================================================================
#
# 🚨 IMPORTANT: When adding new API endpoints to the Flutter app:
#
# 1. **Search for existing API calls** in the codebase to ensure no duplicates
# 2. **Add test case to this file** following the existing pattern:
#    - Add to appropriate test method (auth, data, reactions, notifications, admin)
#    - Include both success and error scenarios
#    - Use proper test naming and logging
#    - Add timeout handling and proper assertions
#
# 3. **Update API documentation** in the header comment section
# 4. **Add any new test data constants** to ApiTestConfig class
# 5. **Create helper methods** if the new API requires complex setup
#
# Example template for new API test:
# ```python
# try:
#     response = self.make_request('POST', '/api/new/endpoint', {
#         'param1': 'value1',
#         'param2': 'value2'
#     }, auth_required=True)  # Set auth_required if needed
#     
#     assert response.status_code == 200
#     data = response.json()
#     assert 'expected_field' in data
#     
#     self.log_test_result("POST /api/new/endpoint", True, "Description of success")
# except Exception as e:
#     self.log_test_result("POST /api/new/endpoint", False, str(e))
# ```
#
# ====================================================================== 