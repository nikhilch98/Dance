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
        # Dharmik Samani bundles - Three workshops with various combinations
        {
            "bundle_id": "DHARMIK_TWO_CLASSES_CHHAN_DHOONDE",
            "name": "Dharmik Samani - Two Classes Bundle (Chhan ke Mohalla + Dhoonde Akhiyaan)",
            "description": "Get both Chhan ke Mohalla and Dhoonde Akhiyaan workshops together at a discounted price",
            "studio_id": "beinrtribe",
            "workshop_ids": [
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla",
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan"
            ],
            "pricing_info": "Bundle Price: ₹2000/-\nIndividual Price: ₹1100/- per class\nSave ₹200 on this bundle!",
            "individual_workshop_prices": {
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla": 1100,
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan": 1100
            },
            "bundle_price": 2000,
            "savings_amount": 200,  # (1100 * 2) - 2000 = 200
            "savings_percentage": 9.1,  # 200 / 2200 ≈ 9.1%
            "is_active": True,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        },
        {
            "bundle_id": "DHARMIK_TWO_CLASSES_CHHAN_KUKKAD",
            "name": "Dharmik Samani - Two Classes Bundle (Chhan ke Mohalla + Kukkad)",
            "description": "Get both Chhan ke Mohalla and Kukkad workshops together at a discounted price",
            "studio_id": "beinrtribe",
            "workshop_ids": [
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla",
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad"
            ],
            "pricing_info": "Bundle Price: ₹2000/-\nIndividual Price: ₹1100/- per class\nSave ₹200 on this bundle!",
            "individual_workshop_prices": {
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla": 1100,
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad": 1100
            },
            "bundle_price": 2000,
            "savings_amount": 200,  # (1100 * 2) - 2000 = 200
            "savings_percentage": 9.1,  # 200 / 2200 ≈ 9.1%
            "is_active": True,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        },
        {
            "bundle_id": "DHARMIK_TWO_CLASSES_DHOONDE_KUKKAD",
            "name": "Dharmik Samani - Two Classes Bundle (Dhoonde Akhiyaan + Kukkad)",
            "description": "Get both Dhoonde Akhiyaan and Kukkad workshops together at a discounted price",
            "studio_id": "beinrtribe",
            "workshop_ids": [
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan",
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad"
            ],
            "pricing_info": "Bundle Price: ₹2000/-\nIndividual Price: ₹1100/- per class\nSave ₹200 on this bundle!",
            "individual_workshop_prices": {
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan": 1100,
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad": 1100
            },
            "bundle_price": 2000,
            "savings_amount": 200,  # (1100 * 2) - 2000 = 200
            "savings_percentage": 9.1,  # 200 / 2200 ≈ 9.1%
            "is_active": True,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        },
        {
            "bundle_id": "DHARMIK_THREE_CLASSES_ALL",
            "name": "Dharmik Samani - Three Classes Bundle (Complete Package)",
            "description": "Get all three workshops - Chhan ke Mohalla, Dhoonde Akhiyaan, and Kukkad - together at the best discounted price",
            "studio_id": "beinrtribe",
            "workshop_ids": [
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla",
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan",
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad"
            ],
            "pricing_info": "Bundle Price: ₹2700/-\nIndividual Price: ₹1100/- per class\nSave ₹600 on this complete bundle!",
            "individual_workshop_prices": {
                "beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla": 1100,
                "beinrtribe_dharmik_samani_workshop_7_12_2025_dhoonde_akhiyaan": 1100,
                "beinrtribe_dharmik_samani_workshop_7_12_2025_kukkad": 1100
            },
            "bundle_price": 2700,
            "savings_amount": 600,  # (1100 * 3) - 2700 = 600
            "savings_percentage": 18.2,  # 600 / 3300 ≈ 18.2%
            "is_active": True,
            "created_at": datetime.now(),
            "updated_at": datetime.now()
        }
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
