#!/usr/bin/env python3
"""Test script to verify QR code logo generation is working."""

import sys
import os

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.services.qr_service import get_qr_service

def test_qr_logo():
    """Test QR code generation with logo."""
    print("Testing QR Code Logo Generation...")

    try:
        qr_service = get_qr_service()

        # Test logo generation
        print("1. Testing logo generation...")
        logo_test = qr_service.test_logo_generation()
        print(f"   Logo test result: {'PASS' if logo_test else 'FAIL'}")

        # Test QR code generation
        print("2. Testing QR code generation with logo...")
        qr_data = qr_service.generate_order_qr_code(
            order_id="test_order_12345",
            workshop_title="Test Dance Workshop",
            amount=150000,  # ₹1,500 in paise
            user_name="Test User",
            user_phone="9999999999",
            workshop_uuid="test-workshop-uuid-123",
            artist_names=["Test Artist"],
            studio_name="Test Studio",
            workshop_date="25/12/2024",
            workshop_time="10:00 AM - 12:00 PM",
            payment_gateway_details={"payment_id": "test_payment_123"}
        )

        if qr_data and len(qr_data) > 100:
            print(f"   QR code generated successfully! Length: {len(qr_data)} characters")
            print(f"   Contains 'data:image/png;base64,': {'data:image/png;base64,' in qr_data}")
            print("   ✅ QR Code with Logo Generation: SUCCESS")
            return True
        else:
            print("   ❌ QR code generation failed or too short")
            return False

    except Exception as e:
        print(f"   ❌ Error during testing: {str(e)}")
        return False

if __name__ == "__main__":
    success = test_qr_logo()
    sys.exit(0 if success else 1)
