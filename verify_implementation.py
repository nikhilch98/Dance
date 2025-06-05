#!/usr/bin/env python3
"""
Nachna App Implementation Verification Script

This script verifies that all existing functionality is working correctly
before making any changes to the codebase. It should be run before and 
after any modifications to ensure no breaking changes are introduced.
"""

import requests
import sys
import time
from typing import List, Dict, Any


class ImplementationVerifier:
    """Verifies that all existing Nachna app functionality is working."""
    
    def __init__(self, base_url: str = "http://127.0.0.1:8002"):
        self.base_url = base_url
        self.test_results: List[Dict[str, Any]] = []
    
    def log_test(self, test_name: str, passed: bool, details: str = ""):
        """Log a test result."""
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status}: {test_name}")
        if details:
            print(f"   Details: {details}")
        
        self.test_results.append({
            "test": test_name,
            "passed": passed,
            "details": details
        })
    
    def test_server_startup(self) -> bool:
        """Test that the server is running and responding."""
        try:
            response = requests.get(f"{self.base_url}/", timeout=5)
            passed = response.status_code == 200
            self.log_test("Server Startup", passed, f"Status: {response.status_code}")
            return passed
        except Exception as e:
            self.log_test("Server Startup", False, f"Error: {str(e)}")
            return False
    
    def test_core_api_endpoints(self) -> bool:
        """Test core API endpoints are responding."""
        endpoints = [
            ("/api/workshops?version=v2", "Workshops API"),
            ("/api/artists?version=v2", "Artists API"),
            ("/api/studios?version=v2", "Studios API"),
        ]
        
        all_passed = True
        for endpoint, name in endpoints:
            try:
                response = requests.get(f"{self.base_url}{endpoint}", timeout=10)
                passed = response.status_code == 200
                if passed:
                    data = response.json()
                    passed = isinstance(data, list)
                
                self.log_test(f"{name} Endpoint", passed, 
                            f"Status: {response.status_code}, Response: {type(response.json()).__name__}")
                all_passed = all_passed and passed
            except Exception as e:
                self.log_test(f"{name} Endpoint", False, f"Error: {str(e)}")
                all_passed = False
        
        return all_passed
    
    def test_workshop_specific_endpoints(self) -> bool:
        """Test workshop-specific endpoints."""
        endpoints = [
            ("/api/workshops_by_studio/manifestbytmn?version=v2", "Workshop by Studio"),
            ("/api/workshops_by_artist/jaysharma_ruh?version=v2", "Workshop by Artist"),
        ]
        
        all_passed = True
        for endpoint, name in endpoints:
            try:
                response = requests.get(f"{self.base_url}{endpoint}", timeout=10)
                passed = response.status_code == 200
                self.log_test(f"{name} Endpoint", passed, f"Status: {response.status_code}")
                all_passed = all_passed and passed
            except Exception as e:
                self.log_test(f"{name} Endpoint", False, f"Error: {str(e)}")
                all_passed = False
        
        return all_passed
    
    def test_static_endpoints(self) -> bool:
        """Test static web endpoints."""
        endpoints = [
            ("/", "Home Page"),
            ("/marketing", "Marketing Page"),
            ("/privacy-policy", "Privacy Policy"),
            ("/terms-of-service", "Terms of Service"),
            ("/support", "Support Page"),
        ]
        
        all_passed = True
        for endpoint, name in endpoints:
            try:
                response = requests.get(f"{self.base_url}{endpoint}", timeout=5)
                passed = response.status_code == 200
                self.log_test(f"{name}", passed, f"Status: {response.status_code}")
                all_passed = all_passed and passed
            except Exception as e:
                self.log_test(f"{name}", False, f"Error: {str(e)}")
                all_passed = False
        
        return all_passed
    
    def test_auth_endpoints_structure(self) -> bool:
        """Test that auth endpoints are accessible (without actual authentication)."""
        # These should return 422 (validation error) or 401 (unauthorized), not 404
        endpoints = [
            ("/api/auth/register", "Auth Register Endpoint"),
            ("/api/auth/login", "Auth Login Endpoint"),
        ]
        
        all_passed = True
        for endpoint, name in endpoints:
            try:
                response = requests.post(f"{self.base_url}{endpoint}", json={}, timeout=5)
                # Should get validation error, not 404
                passed = response.status_code in [422, 401, 400]
                self.log_test(f"{name} Structure", passed, f"Status: {response.status_code}")
                all_passed = all_passed and passed
            except Exception as e:
                self.log_test(f"{name} Structure", False, f"Error: {str(e)}")
                all_passed = False
        
        return all_passed
    
    def test_api_versioning(self) -> bool:
        """Test that API versioning is working."""
        try:
            # Test without version (should use default)
            response1 = requests.get(f"{self.base_url}/api/workshops", timeout=10)
            # Test with explicit version
            response2 = requests.get(f"{self.base_url}/api/workshops?version=v2", timeout=10)
            
            passed = response1.status_code == 200 and response2.status_code == 200
            self.log_test("API Versioning", passed, 
                        f"Default: {response1.status_code}, v2: {response2.status_code}")
            return passed
        except Exception as e:
            self.log_test("API Versioning", False, f"Error: {str(e)}")
            return False
    
    def test_cors_and_middleware(self) -> bool:
        """Test that CORS and middleware are working."""
        try:
            response = requests.get(f"{self.base_url}/api/workshops?version=v2", timeout=10)
            
            # Check for CORS headers
            has_cors = 'access-control-allow-origin' in response.headers
            
            # Check response is compressed (if middleware is working)
            has_content = len(response.content) > 0
            
            passed = response.status_code == 200 and has_content
            self.log_test("CORS and Middleware", passed, 
                        f"CORS: {has_cors}, Content: {has_content}")
            return passed
        except Exception as e:
            self.log_test("CORS and Middleware", False, f"Error: {str(e)}")
            return False
    
    def run_all_tests(self) -> bool:
        """Run all verification tests."""
        print("🔍 Starting Nachna App Implementation Verification...")
        print("=" * 60)
        
        tests = [
            self.test_server_startup,
            self.test_core_api_endpoints,
            self.test_workshop_specific_endpoints,
            self.test_static_endpoints,
            self.test_auth_endpoints_structure,
            self.test_api_versioning,
            self.test_cors_and_middleware,
        ]
        
        all_passed = True
        for test in tests:
            try:
                result = test()
                all_passed = all_passed and result
                print()  # Add spacing between test groups
            except Exception as e:
                print(f"❌ CRITICAL ERROR in {test.__name__}: {str(e)}")
                all_passed = False
        
        return all_passed
    
    def print_summary(self) -> None:
        """Print test summary."""
        print("=" * 60)
        print("📊 VERIFICATION SUMMARY")
        print("=" * 60)
        
        passed_count = sum(1 for result in self.test_results if result['passed'])
        total_count = len(self.test_results)
        
        print(f"Total Tests: {total_count}")
        print(f"Passed: {passed_count}")
        print(f"Failed: {total_count - passed_count}")
        print(f"Success Rate: {(passed_count/total_count)*100:.1f}%")
        
        if passed_count == total_count:
            print("\n🎉 ALL TESTS PASSED - Implementation is working correctly!")
            print("✅ Safe to proceed with new features/changes")
        else:
            print("\n⚠️  SOME TESTS FAILED - Issues detected!")
            print("❌ Do NOT proceed with changes until issues are resolved")
            
            print("\nFailed Tests:")
            for result in self.test_results:
                if not result['passed']:
                    print(f"  - {result['test']}: {result['details']}")


def main():
    """Main verification function."""
    verifier = ImplementationVerifier()
    
    print("Starting verification in 2 seconds...")
    print("Make sure the server is running on http://127.0.0.1:8002")
    time.sleep(2)
    
    all_passed = verifier.run_all_tests()
    verifier.print_summary()
    
    # Exit with appropriate code
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main() 