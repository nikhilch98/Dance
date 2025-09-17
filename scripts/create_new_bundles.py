#!/usr/bin/env python3
"""
Script to create the new bundle structure from existing workshop data.
Creates separate bundle documents with workshop lists and pricing.
"""

import sys
import os
from datetime import datetime

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.utils import DatabaseManager

def create_new_bundles():
    """Create new bundle structure from existing workshops."""

    # Get MongoDB client
    mongo_client = DatabaseManager.get_mongo_client()
    db = mongo_client["discovery"]

    print("Creating new bundle structure...")

    # Define bundles based on existing workshop data
    bundles = [
        # {
        #     "bundle_id": "TWO_WORKSHOPS_BUNDLE",
        #     "name": "Two Workshops Bundle Package",
        #     "description": "Vivek & Aakanksha's complete workshop series - Mayya Mayya & Aavan Jaavan bundled together",
        #     "studio_id": "theroyaldancespace",
        #     "workshop_ids": [
        #         "theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya",
        #         "theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan"
        #     ],
        #     "pricing_info": "Bundle Price: ₹1500/-\nEarly Bird (Till 18th Sept): ₹1500/-\nStandard (19th-20th Sept): ₹1600/-",
        #     "individual_workshop_prices": {
        #         "theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_mayya": 799,
        #         "theroyaldancespace_vicky__pedia_aakanksha5678_workshop_20_9_2025_aavan": 799
        #     },
        #     "bundle_price": 1500,
        #     "savings_amount": 98,  # (799 * 2) - 1500 = 98
        #     "savings_percentage": 6.1,  # 98 / 1598 ≈ 6.1%
        #     "is_active": True,
        #     "created_at": datetime.now(),
        #     "updated_at": datetime.now()
        # }
    ]

    # Clear existing bundles
    db["bundles"].delete_many({})
    print("Cleared existing bundles")

    # Insert new bundles
    if bundles:
        result = db["bundles"].insert_many(bundles)
        print(f"✅ Created {len(result.inserted_ids)} new bundles")

    # Verify bundles were created
    created_bundles = list(db["bundles"].find())
    print("\nCreated bundles:")
    for bundle in created_bundles:
        print(f"  - {bundle['bundle_id']}: {bundle['name']}")
        print(f"    Workshops: {len(bundle['workshop_ids'])}")
        print(f"    Bundle Price: ₹{bundle['bundle_price']}")
        print(f"    Savings: ₹{bundle['savings_amount']} ({bundle['savings_percentage']}%)")
        print()

    print("✅ New bundle structure created successfully!")

if __name__ == "__main__":
    create_new_bundles()
