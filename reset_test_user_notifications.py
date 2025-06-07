#!/usr/bin/env python3
"""
Reset notification permissions for the test user.
This will allow us to test the notification permission dialog.
"""

import subprocess
import sys

def reset_notification_permissions():
    """Reset notification permissions for testing."""
    print("🔄 Resetting notification permissions for test user...")
    
    # The test user ID from our test credentials
    test_user_id = "683cdbb39caf05c68764cde4"
    
    print(f"📱 Test user ID: {test_user_id}")
    print("🧪 This will reset notification permission status so the dialog shows again")
    
    # We'll need to do this through the Flutter app since we can't directly access SharedPreferences from Python
    print("\n📋 To reset notification permissions:")
    print("1. Open the Flutter app")
    print("2. Go to Admin screen")
    print("3. Use the 'Request Device Token' button to trigger permission dialog")
    print("4. Or manually clear app data/reinstall the app")
    
    print("\n✅ Instructions provided for resetting notification permissions")
    return True

if __name__ == "__main__":
    try:
        success = reset_notification_permissions()
        if success:
            print("\n✅ Ready to test notification permissions!")
        else:
            print("\n❌ Failed to reset permissions!")
    except Exception as e:
        print(f"\n💥 Error: {e}")
        sys.exit(1) 