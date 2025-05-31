#!/usr/bin/env python3
"""
Script to make a user admin for testing the admin functionality.
"""

import sys
from utils.utils import get_mongo_client

def make_user_admin(mobile_number=None):
    """Make a user admin by mobile number, or the first user if no mobile provided."""
    try:
        client = get_mongo_client()
        db = client['dance_app']
        users = db['users']
        
        if mobile_number:
            user = users.find_one({'mobile_number': mobile_number})
            if not user:
                print(f"❌ User with mobile {mobile_number} not found")
                return False
        else:
            # Get the first user
            user = users.find_one({})
            if not user:
                print("❌ No users found in database")
                return False
        
        # Update user to admin
        result = users.update_one(
            {'_id': user['_id']}, 
            {'$set': {'is_admin': True}}
        )
        
        if result.modified_count > 0:
            print(f"✅ Successfully made user {user.get('mobile_number', 'unknown')} admin")
            return True
        else:
            print(f"⚠️  User {user.get('mobile_number', 'unknown')} was already admin")
            return True
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    mobile = sys.argv[1] if len(sys.argv) > 1 else None
    make_user_admin(mobile) 