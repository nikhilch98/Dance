#!/usr/bin/env python3
"""
Script to create a test admin user with a known password.
"""

from utils.utils import get_mongo_client
from passlib.context import CryptContext
from datetime import datetime

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def create_test_admin_user():
    """Create a test admin user with known credentials."""
    try:
        client = get_mongo_client()
        db = client['dance_app']
        users = db['users']
        
        mobile_number = "+919999999999"
        password = "test123"
        
        # Check if user already exists
        existing_user = users.find_one({'mobile_number': mobile_number})
        if existing_user:
            # Update existing user
            result = users.update_one(
                {'mobile_number': mobile_number},
                {
                    '$set': {
                        'password_hash': pwd_context.hash(password),
                        'is_admin': True,
                        'updated_at': datetime.utcnow()
                    }
                }
            )
            print(f"✅ Updated test user {mobile_number} with admin privileges")
        else:
            # Create new user
            user_data = {
                "mobile_number": mobile_number,
                "password_hash": pwd_context.hash(password),
                "name": "Test Admin",
                "date_of_birth": "1990-01-01",
                "gender": "Other",
                "profile_complete": True,
                "is_admin": True,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            }
            
            result = users.insert_one(user_data)
            print(f"✅ Created test admin user {mobile_number}")
        
        print(f"📱 Mobile: {mobile_number}")
        print(f"🔑 Password: {password}")
        return True
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    create_test_admin_user() 