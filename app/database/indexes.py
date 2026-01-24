"""Database index management for MongoDB collections."""

import logging
from pymongo import ASCENDING, DESCENDING, IndexModel
from pymongo.errors import OperationFailure
from typing import List, Dict, Any

from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)


# Index definitions for each collection
INDEX_DEFINITIONS: Dict[str, List[Dict[str, Any]]] = {
    # Users collection
    "users": [
        {
            "keys": [("mobile_number", ASCENDING)],
            "unique": True,
            "name": "mobile_number_unique"
        },
        {
            "keys": [("is_admin", ASCENDING)],
            "name": "is_admin_idx"
        },
        {
            "keys": [("created_at", DESCENDING)],
            "name": "created_at_idx"
        }
    ],

    # Device tokens collection
    "device_tokens": [
        {
            "keys": [("user_id", ASCENDING)],
            "name": "user_id_idx"
        },
        {
            "keys": [("device_token", ASCENDING)],
            "unique": True,
            "name": "device_token_unique"
        },
        {
            "keys": [("platform", ASCENDING)],
            "name": "platform_idx"
        }
    ],

    # Orders collection
    "orders": [
        {
            "keys": [("user_id", ASCENDING)],
            "name": "user_id_idx"
        },
        {
            "keys": [("order_id", ASCENDING)],
            "unique": True,
            "name": "order_id_unique"
        },
        {
            "keys": [("workshop_uuid", ASCENDING)],
            "name": "workshop_uuid_idx"
        },
        {
            "keys": [("status", ASCENDING)],
            "name": "status_idx"
        },
        {
            "keys": [("created_at", DESCENDING)],
            "name": "created_at_idx"
        },
        {
            "keys": [("user_id", ASCENDING), ("workshop_uuid", ASCENDING)],
            "name": "user_workshop_idx"
        },
        {
            "keys": [("razorpay_order_id", ASCENDING)],
            "sparse": True,
            "name": "razorpay_order_id_idx"
        }
    ],

    # Reactions collection
    "reactions": [
        {
            "keys": [("user_id", ASCENDING)],
            "name": "user_id_idx"
        },
        {
            "keys": [("entity_type", ASCENDING), ("entity_id", ASCENDING)],
            "name": "entity_idx"
        },
        {
            "keys": [("user_id", ASCENDING), ("entity_type", ASCENDING), ("entity_id", ASCENDING)],
            "unique": True,
            "name": "user_entity_unique"
        }
    ],

    # Profile pictures collection
    "profile_pictures": [
        {
            "keys": [("user_id", ASCENDING)],
            "unique": True,
            "name": "user_id_unique"
        }
    ],

    # Rate limits collection (with TTL)
    "rate_limits": [
        {
            "keys": [("key", ASCENDING)],
            "unique": True,
            "name": "key_unique"
        },
        {
            "keys": [("expires_at", ASCENDING)],
            "expireAfterSeconds": 0,
            "name": "expires_at_ttl"
        }
    ],

    # OTP attempts collection (with TTL)
    "otp_attempts": [
        {
            "keys": [("mobile_number", ASCENDING)],
            "name": "mobile_number_idx"
        },
        {
            "keys": [("expires_at", ASCENDING)],
            "expireAfterSeconds": 0,
            "name": "expires_at_ttl"
        }
    ],

    # Audit logs collection
    "audit_logs": [
        {
            "keys": [("user_id", ASCENDING)],
            "name": "user_id_idx"
        },
        {
            "keys": [("action", ASCENDING)],
            "name": "action_idx"
        },
        {
            "keys": [("timestamp", DESCENDING)],
            "name": "timestamp_idx"
        },
        {
            "keys": [("user_id", ASCENDING), ("action", ASCENDING)],
            "name": "user_action_idx"
        }
    ],

    # Rewards collection
    "rewards": [
        {
            "keys": [("user_id", ASCENDING)],
            "name": "user_id_idx"
        },
        {
            "keys": [("created_at", DESCENDING)],
            "name": "created_at_idx"
        }
    ],

    # Images collection
    "images": [
        {
            "keys": [("image_type", ASCENDING), ("entity_id", ASCENDING)],
            "unique": True,
            "name": "type_entity_unique"
        }
    ]
}

# Discovery database indexes
DISCOVERY_INDEX_DEFINITIONS: Dict[str, List[Dict[str, Any]]] = {
    # Artists collection
    "artists_v2": [
        {
            "keys": [("artist_id", ASCENDING)],
            "unique": True,
            "name": "artist_id_unique"
        },
        {
            "keys": [("artist_name", ASCENDING)],
            "name": "artist_name_idx"
        }
    ],

    # Studios collection
    "studios_v2": [
        {
            "keys": [("studio_id", ASCENDING)],
            "unique": True,
            "name": "studio_id_unique"
        },
        {
            "keys": [("studio_name", ASCENDING)],
            "name": "studio_name_idx"
        }
    ],

    # Workshops collection
    "workshops_v2": [
        {
            "keys": [("workshop_uuid", ASCENDING)],
            "unique": True,
            "name": "workshop_uuid_unique"
        },
        {
            "keys": [("studio_id", ASCENDING)],
            "name": "studio_id_idx"
        },
        {
            "keys": [("artist_ids", ASCENDING)],
            "name": "artist_ids_idx"
        },
        {
            "keys": [("date", ASCENDING)],
            "name": "date_idx"
        },
        {
            "keys": [("is_archived", ASCENDING)],
            "name": "is_archived_idx"
        },
        {
            "keys": [("studio_id", ASCENDING), ("date", ASCENDING)],
            "name": "studio_date_idx"
        }
    ]
}


def create_indexes_for_collection(
    db,
    collection_name: str,
    index_definitions: List[Dict[str, Any]]
) -> List[str]:
    """
    Create indexes for a single collection.

    Args:
        db: MongoDB database instance
        collection_name: Name of the collection
        index_definitions: List of index definitions

    Returns:
        List of created index names
    """
    created_indexes = []
    collection = db[collection_name]

    for index_def in index_definitions:
        try:
            keys = index_def.pop("keys")
            name = index_def.get("name", None)

            # Create index model
            index_model = IndexModel(keys, **index_def)

            # Create the index
            result = collection.create_indexes([index_model])
            created_indexes.extend(result)

            logger.debug(f"Created index '{name}' on {collection_name}")

            # Restore keys for potential reuse
            index_def["keys"] = keys

        except OperationFailure as e:
            if "already exists" in str(e) or "duplicate key" in str(e).lower():
                logger.debug(f"Index '{index_def.get('name')}' already exists on {collection_name}")
                # Restore keys
                index_def["keys"] = keys
            else:
                logger.error(f"Failed to create index on {collection_name}: {e}")
                # Restore keys
                index_def["keys"] = keys
                raise

    return created_indexes


def ensure_indexes() -> Dict[str, List[str]]:
    """
    Ensure all required indexes exist in the database.

    Returns:
        Dictionary mapping collection names to created index names
    """
    client = get_mongo_client()
    results = {}

    # Create indexes for dance_app database
    db = client["dance_app"]
    for collection_name, indexes in INDEX_DEFINITIONS.items():
        try:
            # Make a deep copy of indexes to avoid modifying the original
            indexes_copy = [dict(idx) for idx in indexes]
            created = create_indexes_for_collection(db, collection_name, indexes_copy)
            results[f"dance_app.{collection_name}"] = created
            logger.info(f"Ensured indexes for dance_app.{collection_name}: {len(created)} indexes")
        except Exception as e:
            logger.error(f"Error creating indexes for dance_app.{collection_name}: {e}")
            results[f"dance_app.{collection_name}"] = []

    # Create indexes for discovery database
    discovery_db = client["discovery"]
    for collection_name, indexes in DISCOVERY_INDEX_DEFINITIONS.items():
        try:
            # Make a deep copy of indexes to avoid modifying the original
            indexes_copy = [dict(idx) for idx in indexes]
            created = create_indexes_for_collection(discovery_db, collection_name, indexes_copy)
            results[f"discovery.{collection_name}"] = created
            logger.info(f"Ensured indexes for discovery.{collection_name}: {len(created)} indexes")
        except Exception as e:
            logger.error(f"Error creating indexes for discovery.{collection_name}: {e}")
            results[f"discovery.{collection_name}"] = []

    return results


def drop_all_indexes(exclude_id: bool = True) -> None:
    """
    Drop all indexes from collections (useful for rebuilding).

    Args:
        exclude_id: If True, keep the _id index (recommended)
    """
    client = get_mongo_client()

    # Drop indexes from dance_app
    db = client["dance_app"]
    for collection_name in INDEX_DEFINITIONS.keys():
        try:
            if exclude_id:
                db[collection_name].drop_indexes()
            else:
                # This would drop ALL indexes including _id
                for index in db[collection_name].list_indexes():
                    if index["name"] != "_id_":
                        db[collection_name].drop_index(index["name"])
            logger.info(f"Dropped indexes for dance_app.{collection_name}")
        except Exception as e:
            logger.error(f"Error dropping indexes for {collection_name}: {e}")

    # Drop indexes from discovery
    discovery_db = client["discovery"]
    for collection_name in DISCOVERY_INDEX_DEFINITIONS.keys():
        try:
            discovery_db[collection_name].drop_indexes()
            logger.info(f"Dropped indexes for discovery.{collection_name}")
        except Exception as e:
            logger.error(f"Error dropping indexes for {collection_name}: {e}")
