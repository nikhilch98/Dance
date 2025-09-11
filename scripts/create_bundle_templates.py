#!/usr/bin/env python3
"""
Script to create sample bundle templates in the database.
Run this script to populate bundle templates for testing the bundle system.
"""

import sys
import os
from datetime import datetime, timedelta

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.utils import DatabaseManager

def create_bundle_templates():
    """Create bundle templates for the updated workshops."""

    # Get MongoDB client
    mongo_client = DatabaseManager.get_mongo_client("prod")

    bundle_templates = [
        {
            "_id": "TWO_WORKSHOPS_BUNDLE",
            "template_id": "TWO_WORKSHOPS_BUNDLE",
            "name": "Two Workshops Bundle Package",
            "description": "Vivek & Aakanksha's complete workshop series - Mayya Mayya & Aavan Jaavan bundled together",
            "workshop_ids": [
                "theroyaldancespace/vicky__pedia-aakanksha5678-workshop_20_9_2025_mayya",
                "theroyaldancespace/vicky__pedia-aakanksha5678-workshop_20_9_2025_aavan"
            ],
            "bundle_price": 1500,  # Fixed bundle price (matches pricing_info)
            "individual_prices": [799, 799],  # Individual prices till 18th Sept
            "currency": "INR",
            "discount_percentage": 6.1,  # Save ₹98 on ₹1598 total (98/1598 ≈ 6.1%)
            "valid_until": datetime.now() + timedelta(days=7),
            "max_participants": 25,
            "is_active": True,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        }
    ]

    print("Creating bundle templates for updated workshops...")

    # Delete existing bundle templates for these workshops
    existing_ids = ["COUPLE_BUNDLE", "TWO_WORKSHOPS_BUNDLE"]  # Include both old and new template IDs
    delete_result = mongo_client["discovery"]["bundle_templates"].delete_many(
        {"template_id": {"$in": existing_ids}}
    )
    if delete_result.deleted_count > 0:
        print(f"Deleted {delete_result.deleted_count} existing bundle templates")

    # Insert new bundle templates
    insert_result = mongo_client["discovery"]["bundle_templates"].insert_many(bundle_templates)
    print(f"✅ Inserted {len(insert_result.inserted_ids)} new bundle templates")

    print("\nBundle template creation completed!")
    print("✅ Created template for:")
    print("   - TWO_WORKSHOPS_BUNDLE: Two Workshops Bundle Package")
    print("   - Includes both Mayya Mayya and Aavan Jaavan workshops")
    print("   - Individual: ₹799 each = ₹1598 total")
    print("   - Bundle price: ₹1500 (Save ₹98)")
    print("   - Early bird pricing till 18th Sept")

if __name__ == "__main__":
    create_bundle_templates()
