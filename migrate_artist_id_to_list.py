#!/usr/bin/env python3
"""
Migration script to convert old artist_id fields to artist_id_list
and remove the old artist_id field from all workshop documents.
"""

import sys
import os
from pymongo import MongoClient
import argparse

# Add the parent directory to the path to import config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

def migrate_artist_id_to_list(env: str):
    """Migrate artist_id to artist_id_list and remove old field."""
    
    # Get database configuration
    cfg = config.Config(env=env)
    
    # Connect to MongoDB
    if env == "prod":
        client = MongoClient(cfg.mongodb_uri)
    else:
        client = MongoClient(cfg.mongodb_uri)
    
    db = client["discovery"]
    collection = db["workshops_v2"]
    
    print(f"Starting migration for {env} environment...")
    
    # Find all documents that have artist_id but no artist_id_list or empty artist_id_list
    query = {
        "$and": [
            {"artist_id": {"$exists": True}},
            {"$or": [
                {"artist_id_list": {"$exists": False}},
                {"artist_id_list": None},
                {"artist_id_list": []}
            ]}
        ]
    }
    
    documents_to_migrate = list(collection.find(query))
    print(f"Found {len(documents_to_migrate)} documents to migrate")
    
    if not documents_to_migrate:
        print("No documents need migration")
        return
    
    # Migrate each document
    migrated_count = 0
    for doc in documents_to_migrate:
        artist_id = doc.get("artist_id")
        if artist_id:
            # Convert single artist_id to list
            artist_id_list = [artist_id] if isinstance(artist_id, str) else []
            
            # Update the document
            result = collection.update_one(
                {"_id": doc["_id"]},
                {
                    "$set": {"artist_id_list": artist_id_list},
                    "$unset": {"artist_id": ""}
                }
            )
            
            if result.modified_count > 0:
                migrated_count += 1
                print(f"Migrated document {doc['_id']}: {artist_id} -> {artist_id_list}")
    
    print(f"Successfully migrated {migrated_count} documents")
    
    # Now remove artist_id field from all remaining documents
    print("Removing artist_id field from all documents...")
    result = collection.update_many(
        {"artist_id": {"$exists": True}},
        {"$unset": {"artist_id": ""}}
    )
    
    print(f"Removed artist_id field from {result.modified_count} additional documents")
    
    # Verify migration
    remaining_with_artist_id = collection.count_documents({"artist_id": {"$exists": True}})
    total_with_artist_id_list = collection.count_documents({"artist_id_list": {"$exists": True}})
    
    print(f"\nMigration complete!")
    print(f"Documents still with artist_id field: {remaining_with_artist_id}")
    print(f"Documents with artist_id_list field: {total_with_artist_id_list}")
    
    if remaining_with_artist_id == 0:
        print("✅ Migration successful - no documents have the old artist_id field")
    else:
        print("⚠️ Some documents still have the artist_id field")

def parse_arguments():
    parser = argparse.ArgumentParser(description="Migrate artist_id to artist_id_list")
    parser.add_argument(
        "--env",
        required=True,
        choices=["prod", "dev"],
        help="Environment to migrate (prod or dev)"
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Confirm that you want to run the migration"
    )
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_arguments()
    
    if not args.confirm:
        print("This script will modify your database.")
        print("Please run with --confirm flag to proceed.")
        print(f"Example: python migrate_artist_id_to_list.py --env {args.env} --confirm")
        sys.exit(1)
    
    print(f"⚠️  WARNING: This will modify the {args.env} database!")
    print("This migration will:")
    print("1. Convert any existing artist_id fields to artist_id_list arrays")
    print("2. Remove the old artist_id field from all documents")
    print()
    
    confirm = input(f"Are you sure you want to proceed with {args.env} environment? (yes/no): ")
    if confirm.lower() != "yes":
        print("Migration cancelled")
        sys.exit(1)
    
    migrate_artist_id_to_list(args.env) 