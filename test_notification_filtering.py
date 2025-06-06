#!/usr/bin/env python3
"""Test script for notification filtering functionality."""

import sys
import os
from datetime import datetime, timedelta

# Add the project root to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.notifications import NotificationOperations
from utils.utils import get_mongo_client


def test_notification_filtering():
    """Test the notification filtering functionality."""
    print("🧪 Testing notification filtering functionality...")
    
    # Test data
    test_user_id = "test_user_123"
    test_artist_id = "test_artist_456"
    test_workshop_uuid = "test_workshop_789"
    
    try:
        # Clean up any existing test data
        client = get_mongo_client()
        client["dance_app"]["notification_history"].delete_many({
            "user_id": test_user_id,
            "artist_id": test_artist_id
        })
        
        print(f"✅ Cleaned up existing test data")
        
        # Test 1: No previous notifications - should allow notification
        print("\n📝 Test 1: No previous notifications")
        has_recent = NotificationOperations.has_artist_notification_been_sent_recently(
            test_user_id, test_artist_id, days=7
        )
        print(f"   Has recent notification: {has_recent} (should be False)")
        assert not has_recent, "Should not have recent notifications"
        
        # Test 2: Record a notification and check if it's detected
        print("\n📝 Test 2: Record notification and check detection")
        success = NotificationOperations.record_notification_sent(
            user_id=test_user_id,
            workshop_uuid=test_workshop_uuid,
            artist_id=test_artist_id,
            notification_type="new_workshop",
            title="Test Notification",
            body="Test notification body"
        )
        print(f"   Notification recorded: {success} (should be True)")
        assert success, "Should successfully record notification"
        
        # Test 3: Check if recent notification is detected
        print("\n📝 Test 3: Check recent notification detection")
        has_recent = NotificationOperations.has_artist_notification_been_sent_recently(
            test_user_id, test_artist_id, days=7
        )
        print(f"   Has recent notification: {has_recent} (should be True)")
        assert has_recent, "Should detect recent notification"
        
        # Test 4: Check specific workshop notification
        print("\n📝 Test 4: Check specific workshop notification")
        has_workshop_notif = NotificationOperations.has_notification_been_sent(
            test_user_id, test_workshop_uuid, "new_workshop"
        )
        print(f"   Has workshop notification: {has_workshop_notif} (should be True)")
        assert has_workshop_notif, "Should detect specific workshop notification"
        
        # Test 5: Check notification stats
        print("\n📝 Test 5: Check notification statistics")
        stats = NotificationOperations.get_recent_notification_stats(test_artist_id, days=7)
        print(f"   Stats: {stats}")
        assert stats["total_notifications"] == 1, "Should have 1 notification"
        assert stats["unique_users_notified"] == 1, "Should have 1 unique user"
        assert "new_workshop" in stats["notification_types"], "Should have new_workshop type"
        
        # Test 6: Test with old notification (simulate 8 days ago)
        print("\n📝 Test 6: Test with old notification")
        old_date = datetime.utcnow() - timedelta(days=8)
        client["dance_app"]["notification_history"].update_one(
            {"user_id": test_user_id, "artist_id": test_artist_id},
            {"$set": {"sent_at": old_date}}
        )
        
        has_recent = NotificationOperations.has_artist_notification_been_sent_recently(
            test_user_id, test_artist_id, days=7
        )
        print(f"   Has recent notification (8 days old): {has_recent} (should be False)")
        assert not has_recent, "Should not detect 8-day-old notification as recent"
        
        print("\n✅ All tests passed! Notification filtering is working correctly.")
        
    except Exception as e:
        print(f"\n❌ Test failed: {str(e)}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        # Clean up test data
        try:
            client["dance_app"]["notification_history"].delete_many({
                "user_id": test_user_id,
                "artist_id": test_artist_id
            })
            print(f"🧹 Cleaned up test data")
        except Exception as e:
            print(f"⚠️ Warning: Could not clean up test data: {e}")
    
    return True


if __name__ == "__main__":
    success = test_notification_filtering()
    sys.exit(0 if success else 1) 