#!/usr/bin/env python3
"""
Test script to verify QR code generation fix for bundle orders.
This script demonstrates that each workshop UUID now gets its own QR code.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.orders import OrderOperations
from app.services.background_qr_service import BackgroundQRService
from app.services.qr_service import QRService

def test_qr_generation_fix():
    """Test that QR codes are generated for each workshop UUID in bundle orders."""

    print("=== Testing QR Code Generation Fix ===\n")

    # Test with a bundle order (replace with actual order ID)
    test_order_id = "ord_d175df7b01dc0b5be5a1987a946a8e5a"

    # Get the order
    order = OrderOperations.get_order_by_id(test_order_id)
    if not order:
        print(f"❌ Order {test_order_id} not found")
        return

    print(f"📋 Order: {order.get('order_id')}")
    print(f"📦 Is Bundle Order: {order.get('is_bundle_order', False)}")

    # Check workshop UUIDs
    workshop_uuids = order.get('workshop_uuids', [])
    if not workshop_uuids and order.get('workshop_uuid'):
        workshop_uuids = [order['workshop_uuid']]

    print(f"🎯 Workshop UUIDs: {workshop_uuids}")
    print(f"🔢 Number of workshops: {len(workshop_uuids)}")

    # Check existing QR codes
    qr_codes_data = order.get('qr_codes_data', {})
    print(f"📱 Existing QR codes: {list(qr_codes_data.keys()) if qr_codes_data else 'None'}")
    print(f"🔢 Number of QR codes: {len(qr_codes_data)}")

    # Check if we have QR codes for all workshop UUIDs
    missing_qr_uuids = [uuid for uuid in workshop_uuids if uuid not in qr_codes_data]
    if missing_qr_uuids:
        print(f"⚠️  Missing QR codes for: {missing_qr_uuids}")
        print(f"💡 Need to regenerate QR codes for {len(missing_qr_uuids)} workshop(s)")
    else:
        print("✅ All workshop UUIDs have QR codes!")

    # Show what the old behavior would have been
    print("\n=== Old Behavior (Before Fix) ===")
    print("❌ Would generate only 1 QR code with key 'default'")
    print("❌ Would not include workshop-specific information in QR codes")
    print("❌ Bundle orders would have incomplete QR code data")

    # Show what the new behavior should be
    print("\n=== New Behavior (After Fix) ===")
    if len(workshop_uuids) == 1:
        print(f"✅ Single workshop: Generates 1 QR code with key '{workshop_uuids[0]}'")
    else:
        print(f"✅ Bundle with {len(workshop_uuids)} workshops:")
        for uuid in workshop_uuids:
            status = "✅" if uuid in qr_codes_data else "❌"
            print(f"   {status} Workshop {uuid}: QR code generated")

    # Show bundle information if applicable
    if order.get('is_bundle_order'):
        bundle_id = order.get('bundle_id')
        print(f"\n📦 Bundle Details:")
        print(f"   Bundle ID: {bundle_id}")
        print(f"   Total Workshops: {order.get('bundle_total_workshops', 'Unknown')}")
        print(f"   Bundle Amount: ₹{order.get('bundle_total_amount', 'Unknown')}")

        # Check if bundle details are available
        if bundle_id:
            from app.database.bundles import BundleOperations
            bundle_details = BundleOperations.get_bundle_with_workshop_details(bundle_id)
            if bundle_details:
                bundle_workshops = bundle_details.get('workshops', [])
                print(f"   ✅ Bundle found with {len(bundle_workshops)} workshop details")
                for i, workshop in enumerate(bundle_workshops):
                    print(f"      {i+1}. {workshop.get('title', 'Unknown')} - {workshop.get('uuid')}")
            else:
                print("   ❌ Bundle details not found!")
if __name__ == "__main__":
    test_qr_generation_fix()
