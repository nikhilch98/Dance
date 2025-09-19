#!/usr/bin/env python3
"""
Test script to process welcome bonus rewards for all eligible users.

This script finds all users who haven't received a welcome bonus yet and awards them the bonus.
It includes safety features like dry-run mode and batch processing.

Usage:
    python scripts/test_welcome_bonuses.py [--dry-run] [--batch-size 100] [--force]

Options:
    --dry-run: Show what would be done without making changes
    --batch-size: Process users in batches (default: 50)
    --force: Process all users regardless of existing bonuses (dangerous!)
"""

import sys
import os
import argparse
from datetime import datetime
from typing import List, Dict, Any
from tqdm import tqdm

# Add the parent directory to the path to import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.utils import get_mongo_client
from app.database.rewards import RewardOperations
from app.models.rewards import RewardSourceEnum, RewardTransactionTypeEnum, RewardTransactionStatusEnum


def get_users_without_welcome_bonus(force: bool = False) -> List[Dict[str, Any]]:
    """
    Get all users who don't have a welcome bonus yet.

    Args:
        force: If True, return all users regardless of existing bonuses

    Returns:
        List of user documents
    """
    client = get_mongo_client()

    if force:
        # Get all users
        users = list(client["dance_app"]["users"].find({}, {"_id": 1, "mobile_number": 1}))
        print(f"🔍 FORCE MODE: Found {len(users)} total users")
        return users

    # Get users who don't have a welcome bonus
    pipeline = [
        {
            "$lookup": {
                "from": "reward_transactions",
                "localField": "_id",
                "foreignField": "user_id",
                "as": "reward_transactions"
            }
        },
        {
            "$match": {
                "$or": [
                    {"reward_transactions": {"$size": 0}},  # No transactions at all
                    {"reward_transactions": {"$not": {"$elemMatch": {
                        "source": RewardSourceEnum.WELCOME_BONUS.value,
                        "transaction_type": RewardTransactionTypeEnum.CREDIT.value,
                        "status": RewardTransactionStatusEnum.COMPLETED.value
                    }}}}
                ]
            }
        },
        {
            "$project": {
                "_id": 1,
                "mobile_number": 1
                # reward_transactions field is not included, so it won't be returned
            }
        }
    ]

    users = list(client["dance_app"]["users"].aggregate(pipeline))
    print(f"🔍 Found {len(users)} users without welcome bonus")
    return users


def award_welcome_bonus_to_user(user: Dict[str, Any], dry_run: bool = False) -> Dict[str, Any]:
    """
    Award welcome bonus to a single user.

    Args:
        user: User document
        dry_run: If True, don't actually award the bonus

    Returns:
        Result dictionary with success status and details
    """
    user_id = str(user["_id"])
    mobile = user.get("mobile_number", "unknown")

    try:
        if dry_run:
            return {
                "user_id": user_id,
                "mobile": mobile,
                "success": True,
                "transaction_id": f"DRY_RUN_{user_id}",
                "message": "Would award welcome bonus (dry run)"
            }

        # Award the welcome bonus
        transaction_id = RewardOperations.award_welcome_bonus(user_id)

        return {
            "user_id": user_id,
            "mobile": mobile,
            "success": True,
            "transaction_id": transaction_id,
            "message": "Welcome bonus awarded successfully"
        }

    except Exception as e:
        return {
            "user_id": user_id,
            "mobile": mobile,
            "success": False,
            "error": str(e),
            "message": f"Failed to award welcome bonus: {str(e)}"
        }


def process_welcome_bonuses(dry_run: bool = False, batch_size: int = 50, force: bool = False):
    """
    Process welcome bonuses for all eligible users.

    Args:
        dry_run: If True, don't make actual changes
        batch_size: Number of users to process in each batch
        force: If True, process all users regardless of existing bonuses
    """
    print("🚀 Starting welcome bonus processing...")
    print(f"📅 Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"🔧 Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print(f"📦 Batch size: {batch_size}")
    print(f"⚡ Force mode: {'ENABLED' if force else 'DISABLED'}")
    print("-" * 60)

    # Get eligible users
    users = get_users_without_welcome_bonus(force=force)

    if not users:
        print("✅ No eligible users found. All users already have welcome bonuses!")
        return

    # Process users in batches
    total_processed = 0
    successful = 0
    failed = 0
    skipped = 0

    with tqdm(total=len(users), desc="Processing users", unit="user") as pbar:
        for i in range(0, len(users), batch_size):
            batch = users[i:i + batch_size]
            batch_results = []

            for user in batch:
                result = award_welcome_bonus_to_user(user, dry_run=dry_run)
                batch_results.append(result)

                if result["success"]:
                    successful += 1
                else:
                    failed += 1

                total_processed += 1
                pbar.update(1)

            # Log batch results
            for result in batch_results:
                if result["success"]:
                    print(f"✅ {result['mobile']}: {result['message']}")
                else:
                    print(f"❌ {result['mobile']}: {result['message']}")

            print(f"📊 Batch {i//batch_size + 1} completed - Success: {len([r for r in batch_results if r['success']])}, Failed: {len([r for r in batch_results if not r['success']])}")
            print("-" * 40)

    # Final statistics
    print("\n" + "=" * 60)
    print("🎉 WELCOME BONUS PROCESSING COMPLETED")
    print("=" * 60)
    print(f"📊 Total users processed: {total_processed}")
    print(f"✅ Successful: {successful}")
    print(f"❌ Failed: {failed}")
    print(f"⏭️  Skipped: {skipped}")
    print(".1f")
    print(f"📅 Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    if dry_run:
        print("\n💡 This was a DRY RUN - no actual changes were made!")
        print("   Remove --dry-run flag to process bonuses for real.")

    if failed > 0:
        print(f"\n⚠️  {failed} users failed to receive bonuses. Check logs above for details.")

    return {
        "total_processed": total_processed,
        "successful": successful,
        "failed": failed,
        "skipped": skipped,
        "success_rate": successful / total_processed if total_processed > 0 else 0
    }


def main():
    """Main function with command line argument parsing."""
    parser = argparse.ArgumentParser(
        description="Process welcome bonus rewards for all eligible users",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/test_welcome_bonuses.py --dry-run              # Test run without changes
  python scripts/test_welcome_bonuses.py --batch-size 10        # Process in small batches
  python scripts/test_welcome_bonuses.py --force                # Process ALL users (dangerous!)
  python scripts/test_welcome_bonuses.py                        # Live run with defaults
        """
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes"
    )

    parser.add_argument(
        "--batch-size",
        type=int,
        default=50,
        help="Number of users to process in each batch (default: 50)"
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Process ALL users regardless of existing bonuses (dangerous!)"
    )

    args = parser.parse_args()

    # Safety check for force mode
    if args.force and not args.dry_run:
        print("⚠️  WARNING: Force mode will attempt to award bonuses to ALL users!")
        print("   This may create duplicate bonuses for users who already have them.")
        response = input("   Are you sure you want to continue? (type 'yes' to confirm): ")
        if response.lower() != 'yes':
            print("❌ Operation cancelled.")
            return

    try:
        results = process_welcome_bonuses(
            dry_run=args.dry_run,
            batch_size=args.batch_size,
            force=args.force
        )

        # Exit with appropriate code
        if results and results.get("failed", 0) > 0:
            sys.exit(1)  # Some failures occurred
        else:
            sys.exit(0)  # Success

    except KeyboardInterrupt:
        print("\n\n⏹️  Operation interrupted by user.")
        sys.exit(130)

    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
