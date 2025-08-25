"""Comprehensive test script for the payment system APIs."""

import requests
import json
from datetime import datetime
import time

# Configuration
BASE_URL = "https://nachna.com"  # Update with your server URL
TEST_USER_MOBILE = "9999999999"
TEST_OTP = "583647"

# Test workshop UUID (you'll need to replace with a real one from your database)
TEST_WORKSHOP_UUID = "sample-workshop-uuid-here"  # Replace with actual workshop UUID

class PaymentSystemTester:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.access_token = None
        self.headers = {"Content-Type": "application/json"}
        
    def log(self, message: str):
        """Log test messages with timestamp."""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")
        
    def authenticate(self) -> bool:
        """Authenticate and get access token."""
        try:
            # Send OTP
            self.log("Sending OTP...")
            otp_response = requests.post(
                f"{self.base_url}/api/auth/send-otp",
                json={"mobile_number": TEST_USER_MOBILE},
                headers=self.headers
            )
            
            if otp_response.status_code != 200:
                self.log(f"Failed to send OTP: {otp_response.text}")
                return False
                
            self.log("OTP sent successfully")
            
            # Verify OTP
            self.log("Verifying OTP...")
            verify_response = requests.post(
                f"{self.base_url}/api/auth/verify-otp",
                json={
                    "mobile_number": TEST_USER_MOBILE,
                    "otp": TEST_OTP
                },
                headers=self.headers
            )
            
            if verify_response.status_code != 200:
                self.log(f"Failed to verify OTP: {verify_response.text}")
                return False
                
            auth_data = verify_response.json()
            self.access_token = auth_data["access_token"]
            self.headers["Authorization"] = f"Bearer {self.access_token}"
            
            self.log(f"Authentication successful! User ID: {auth_data['user']['user_id']}")
            return True
            
        except Exception as e:
            self.log(f"Authentication error: {str(e)}")
            return False
    
    def test_create_payment_link(self) -> str:
        """Test creating a payment link."""
        try:
            self.log("Testing payment link creation...")
            
            response = requests.post(
                f"{self.base_url}/api/orders/create-payment-link",
                json={"workshop_uuid": TEST_WORKSHOP_UUID},
                headers=self.headers
            )
            
            self.log(f"Payment link creation response: {response.status_code}")
            
            if response.status_code == 201:
                data = response.json()
                self.log(f"✅ Payment link created successfully!")
                self.log(f"   Order ID: {data['order_id']}")
                self.log(f"   Payment Link: {data['payment_link_url']}")
                self.log(f"   Amount: ₹{data['amount']/100:.2f}")
                self.log(f"   Expires: {data['expires_at']}")
                return data['order_id']
                
            elif response.status_code == 409:
                data = response.json()
                if data.get('error') == 'active_payment_exists':
                    self.log(f"⚠️  Active payment already exists")
                    self.log(f"   Existing Order: {data['existing_order']['order_id']}")
                    return data['existing_order']['order_id']
                    
            else:
                self.log(f"❌ Payment link creation failed: {response.text}")
                return None
                
        except Exception as e:
            self.log(f"❌ Payment link creation error: {str(e)}")
            return None
    
    def test_duplicate_payment_link(self) -> bool:
        """Test duplicate payment link handling."""
        try:
            self.log("Testing duplicate payment link handling...")
            
            # Create first payment link
            response1 = requests.post(
                f"{self.base_url}/api/orders/create-payment-link",
                json={"workshop_uuid": TEST_WORKSHOP_UUID},
                headers=self.headers
            )
            
            # Create second payment link (should return existing one)
            response2 = requests.post(
                f"{self.base_url}/api/orders/create-payment-link",
                json={"workshop_uuid": TEST_WORKSHOP_UUID},
                headers=self.headers
            )
            
            if response2.status_code == 409:
                data = response2.json()
                if data.get('error') == 'active_payment_exists':
                    self.log("✅ Duplicate payment link handling works correctly")
                    return True
                    
            self.log("❌ Duplicate payment link handling failed")
            return False
            
        except Exception as e:
            self.log(f"❌ Duplicate payment link test error: {str(e)}")
            return False
    
    def test_get_user_orders(self) -> bool:
        """Test getting user orders."""
        try:
            self.log("Testing user orders retrieval...")
            
            response = requests.get(
                f"{self.base_url}/api/orders/user",
                headers=self.headers
            )
            
            self.log(f"User orders response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ User orders retrieved successfully!")
                self.log(f"   Total orders: {data['total_count']}")
                self.log(f"   Orders in response: {len(data['orders'])}")
                self.log(f"   Has more: {data['has_more']}")
                
                # Show details of first order if available
                if data['orders']:
                    order = data['orders'][0]
                    self.log(f"   First order: {order['order_id']} - {order['status']} - ₹{order['amount']/100:.2f}")
                
                return True
                
            else:
                self.log(f"❌ User orders retrieval failed: {response.text}")
                return False
                
        except Exception as e:
            self.log(f"❌ User orders retrieval error: {str(e)}")
            return False
    
    def test_webhook_simulation(self, order_id: str) -> bool:
        """Test webhook simulation."""
        try:
            self.log("Testing webhook simulation...")
            
            # Simulate a successful payment webhook
            webhook_params = {
                "razorpay_payment_id": "pay_test123456789",
                "razorpay_payment_link_id": "plink_test123456789",
                "razorpay_payment_link_reference_id": order_id,
                "razorpay_payment_link_status": "paid",
                "razorpay_signature": "test_signature_123456789"
            }
            
            response = requests.get(
                f"{self.base_url}/api/razorpay/webhook",
                params=webhook_params
            )
            
            self.log(f"Webhook simulation response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ Webhook processed successfully!")
                self.log(f"   Order updated: {data['order_updated']}")
                self.log(f"   Message: {data['message']}")
                return True
                
            else:
                self.log(f"❌ Webhook simulation failed: {response.text}")
                return False
                
        except Exception as e:
            self.log(f"❌ Webhook simulation error: {str(e)}")
            return False
    
    def test_order_status_filtering(self) -> bool:
        """Test order status filtering."""
        try:
            self.log("Testing order status filtering...")
            
            # Test filtering by 'paid' status
            response = requests.get(
                f"{self.base_url}/api/orders/user?status=paid,created",
                headers=self.headers
            )
            
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ Order status filtering works!")
                self.log(f"   Filtered orders: {len(data['orders'])}")
                return True
                
            else:
                self.log(f"❌ Order status filtering failed: {response.text}")
                return False
                
        except Exception as e:
            self.log(f"❌ Order status filtering error: {str(e)}")
            return False
    
    def run_all_tests(self) -> None:
        """Run all payment system tests."""
        self.log("🚀 Starting Payment System Tests")
        self.log("=" * 50)
        
        # Test 1: Authentication
        if not self.authenticate():
            self.log("❌ Authentication failed - aborting tests")
            return
        
        # Test 2: Create payment link
        order_id = self.test_create_payment_link()
        if not order_id:
            self.log("❌ Payment link creation failed - skipping dependent tests")
        
        # Test 3: Duplicate payment link handling
        self.test_duplicate_payment_link()
        
        # Test 4: Get user orders
        self.test_get_user_orders()
        
        # Test 5: Webhook simulation (if we have an order)
        if order_id:
            self.test_webhook_simulation(order_id)
        
        # Test 6: Order status filtering
        self.test_order_status_filtering()
        
        self.log("=" * 50)
        self.log("🏁 Payment System Tests Completed")


def main():
    """Main test function."""
    print(f"""
Payment System Test Suite
==========================
Base URL: {BASE_URL}
Test User: {TEST_USER_MOBILE}
Workshop UUID: {TEST_WORKSHOP_UUID}

⚠️  IMPORTANT: Update TEST_WORKSHOP_UUID with a real workshop UUID from your database!

Starting tests in 3 seconds...
""")
    
    time.sleep(3)
    
    tester = PaymentSystemTester(BASE_URL)
    tester.run_all_tests()


if __name__ == "__main__":
    main()
