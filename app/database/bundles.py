"""
Database operations for bundle management.
New structure: Separate bundles collection with workshop lists and pricing.
"""

import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from utils.utils import DatabaseManager
from pymongo.errors import PyMongoError

logger = logging.getLogger(__name__)


class BundleOperations:
    """Database operations for bundles with new structure."""

    @staticmethod
    def get_bundles_collection():
        """Get the bundles collection."""
        mongo_client = DatabaseManager.get_mongo_client()
        db = mongo_client["discovery"]
        return db["bundles"]

    @staticmethod
    def create_bundle(bundle_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new bundle."""
        try:
            bundle_data["created_at"] = datetime.now()
            bundle_data["updated_at"] = datetime.now()

            collection = BundleOperations.get_bundles_collection()
            result = collection.insert_one(bundle_data)
            bundle_data["_id"] = result.inserted_id

            logger.info(f"Created bundle {bundle_data.get('bundle_id', 'unknown')}")
            return bundle_data

        except PyMongoError as e:
            logger.error(f"Error creating bundle: {e}")
            raise

    @staticmethod
    def get_bundle_by_id(bundle_id: str) -> Optional[Dict[str, Any]]:
        """Get bundle by bundle_id."""
        try:
            collection = BundleOperations.get_bundles_collection()
            bundle = collection.find_one({"bundle_id": bundle_id, "is_active": True})
            return bundle

        except PyMongoError as e:
            logger.error(f"Error fetching bundle {bundle_id}: {e}")
            raise

    @staticmethod
    def get_bundles_by_studio(studio_id: str) -> List[Dict[str, Any]]:
        """Get all active bundles for a studio."""
        try:
            collection = BundleOperations.get_bundles_collection()
            bundles = list(collection.find(
                {"studio_id": studio_id, "is_active": True}
            ).sort("created_at", -1))
            return bundles

        except PyMongoError as e:
            logger.error(f"Error fetching bundles for studio {studio_id}: {e}")
            raise

    @staticmethod
    def get_bundles_containing_workshop(workshop_uuid: str) -> List[Dict[str, Any]]:
        """Get all bundles that contain a specific workshop."""
        try:
            collection = BundleOperations.get_bundles_collection()
            bundles = list(collection.find(
                {"workshop_ids": workshop_uuid, "is_active": True}
            ).sort("created_at", -1))
            return bundles

        except PyMongoError as e:
            logger.error(f"Error fetching bundles containing workshop {workshop_uuid}: {e}")
            raise

    @staticmethod
    def get_bundle_with_workshop_details(bundle_id: str) -> Optional[Dict[str, Any]]:
        """Get bundle with full workshop details."""
        try:
            from app.database.workshops import DatabaseOperations

            bundle = BundleOperations.get_bundle_by_id(bundle_id)
            if not bundle:
                return None

            # Get workshop details for all workshops in the bundle
            workshop_details = []
            for workshop_uuid in bundle.get("workshop_ids", []):
                workshop = DatabaseOperations.get_workshop_by_uuid(workshop_uuid)
                if workshop:
                    workshop_details.append(workshop)

            bundle["workshops"] = workshop_details
            return bundle

        except PyMongoError as e:
            logger.error(f"Error fetching bundle with workshop details {bundle_id}: {e}")
            raise

    @staticmethod
    def update_bundle(bundle_id: str, update_data: Dict[str, Any]) -> bool:
        """Update bundle information."""
        try:
            update_data["updated_at"] = datetime.now()

            collection = BundleOperations.get_bundles_collection()
            result = collection.update_one(
                {"bundle_id": bundle_id},
                {"$set": update_data}
            )

            success = result.modified_count > 0
            if success:
                logger.info(f"Updated bundle {bundle_id}")
            return success

        except PyMongoError as e:
            logger.error(f"Error updating bundle {bundle_id}: {e}")
            raise

    @staticmethod
    def deactivate_bundle(bundle_id: str) -> bool:
        """Deactivate a bundle (soft delete)."""
        try:
            collection = BundleOperations.get_bundles_collection()
            result = collection.update_one(
                {"bundle_id": bundle_id},
                {"$set": {"is_active": False, "updated_at": datetime.now()}}
            )

            success = result.modified_count > 0
            if success:
                logger.info(f"Deactivated bundle {bundle_id}")
            return success

        except PyMongoError as e:
            logger.error(f"Error deactivating bundle {bundle_id}: {e}")
            raise

