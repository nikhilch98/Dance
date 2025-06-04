#!/usr/bin/env python3
"""
Create indexes for the notification_history collection to ensure efficient queries
and prevent duplicate notifications.
"""

from pymongo import MongoClient, ASCENDING, DESCENDING
from datetime import datetime
import config

def create_notification_indexes():
    """Create necessary indexes for the notification_history collection."""
    
    # Get MongoDB client
    cfg = config.Config(env="prod")  # Change to your environment
    client = MongoClient(cfg.mongo_uri)
    db = client["dance_app"]
    collection = db["notification_history"]
    
    print("Creating indexes for notification_history collection...")
    
    # Index 1: Compound index for checking if notification was already sent
    # This is the most important index for preventing duplicates
    collection.create_index(
        [
            ("user_id", ASCENDING),
            ("workshop_uuid", ASCENDING),
            ("notification_type", ASCENDING),
            ("is_sent", ASCENDING)
        ],
        name="user_workshop_type_sent_idx",
        background=True
    )
    print("✅ Created index: user_workshop_type_sent_idx")
    
    # Index 2: For finding notifications by workshop UUID (for change detection)
    collection.create_index(
        [
            ("workshop_uuid", ASCENDING),
            ("sent_at", DESCENDING)
        ],
        name="workshop_sent_date_idx",
        background=True
    )
    print("✅ Created index: workshop_sent_date_idx")
    
    # Index 3: For cleanup operations (finding old notifications)
    collection.create_index(
        [("sent_at", ASCENDING)],
        name="sent_date_idx",
        background=True
    )
    print("✅ Created index: sent_date_idx")
    
    # Index 4: For user-specific queries
    collection.create_index(
        [
            ("user_id", ASCENDING),
            ("sent_at", DESCENDING)
        ],
        name="user_sent_date_idx",
        background=True
    )
    print("✅ Created index: user_sent_date_idx")
    
    # Index 5: For artist-specific analytics
    collection.create_index(
        [
            ("artist_id", ASCENDING),
            ("notification_type", ASCENDING),
            ("sent_at", DESCENDING)
        ],
        name="artist_type_date_idx",
        background=True
    )
    print("✅ Created index: artist_type_date_idx")
    
    # Create TTL index to automatically delete old notifications after 90 days
    # This helps keep the collection size manageable
    collection.create_index(
        [("sent_at", ASCENDING)],
        name="ttl_idx",
        expireAfterSeconds=90 * 24 * 60 * 60,  # 90 days in seconds
        background=True
    )
    print("✅ Created TTL index: ttl_idx (90 days)")
    
    print("\n✅ All indexes created successfully!")
    
    # Print collection stats
    stats = db.command("collStats", "notification_history")
    print(f"\nCollection stats:")
    print(f"- Document count: {stats.get('count', 0)}")
    print(f"- Total indexes: {stats.get('nindexes', 0)}")
    
    # List all indexes
    print("\nCurrent indexes:")
    for index in collection.list_indexes():
        print(f"- {index['name']}: {index['key']}")

if __name__ == "__main__":
    create_notification_indexes() 