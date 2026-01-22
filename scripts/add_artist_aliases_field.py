"""Migration script to add artist_aliases field to all artists.

This script adds an empty artist_aliases array to all artist documents
in the artists_v2 collection that don't already have this field.

Usage:
    python scripts/add_artist_aliases_field.py --env prod
    python scripts/add_artist_aliases_field.py --env dev
"""

import argparse
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import config
from utils.utils import DatabaseManager


def migrate_artists(env: str) -> None:
    """Add artist_aliases field to all artists that don't have it."""
    cfg = config.Config(env)
    client = DatabaseManager.get_mongo_client(cfg.env)
    collection = client["discovery"]["artists_v2"]

    # Find all artists without artist_aliases field
    artists_without_aliases = collection.count_documents(
        {"artist_aliases": {"$exists": False}}
    )

    print(f"Found {artists_without_aliases} artists without artist_aliases field")

    if artists_without_aliases == 0:
        print("No migration needed - all artists already have artist_aliases field")
        return

    # Update all artists without artist_aliases to have an empty array
    result = collection.update_many(
        {"artist_aliases": {"$exists": False}},
        {"$set": {"artist_aliases": []}}
    )

    print(f"Updated {result.modified_count} artists with empty artist_aliases array")

    # Verify the migration
    remaining = collection.count_documents(
        {"artist_aliases": {"$exists": False}}
    )

    if remaining == 0:
        print("✓ Migration completed successfully - all artists now have artist_aliases field")
    else:
        print(f"⚠ Warning: {remaining} artists still don't have artist_aliases field")


def main():
    parser = argparse.ArgumentParser(
        description="Add artist_aliases field to all artists"
    )
    parser.add_argument(
        "--env",
        required=True,
        choices=["prod", "dev"],
        help="Environment to run migration on"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without making changes"
    )

    args = parser.parse_args()

    if args.dry_run:
        cfg = config.Config(args.env)
        client = DatabaseManager.get_mongo_client(cfg.env)
        collection = client["discovery"]["artists_v2"]

        count = collection.count_documents(
            {"artist_aliases": {"$exists": False}}
        )
        print(f"[DRY RUN] Would update {count} artists to add empty artist_aliases array")
        return

    migrate_artists(args.env)


if __name__ == "__main__":
    main()
