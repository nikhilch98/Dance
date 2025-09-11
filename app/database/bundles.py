"""
Database operations for bundle management.
"""

import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from motor.motor_asyncio import AsyncIOMotorCollection
from pymongo.errors import PyMongoError

from app.database.mongodb import get_database

logger = logging.getLogger(__name__)


class BundleOperations:
    """Database operations for bundles."""

    @staticmethod
    def get_bundle_collection() -> AsyncIOMotorCollection:
        """Get the bundles collection."""
        return get_database()["bundles"]

    @staticmethod
    def get_bundle_templates_collection() -> AsyncIOMotorCollection:
        """Get the bundle templates collection."""
        return get_database()["bundle_templates"]

    @staticmethod
    async def create_bundle(bundle_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new bundle record."""
        try:
            bundle_data["created_at"] = datetime.now()
            bundle_data["updated_at"] = datetime.now()

            result = await BundleOperations.get_bundle_collection().insert_one(bundle_data)
            bundle_data["_id"] = result.inserted_id

            logger.info(f"Created bundle {bundle_data.get('bundle_id', 'unknown')}")
            return bundle_data

        except PyMongoError as e:
            logger.error(f"Error creating bundle: {e}")
            raise

    @staticmethod
    async def get_bundle_by_id(bundle_id: str) -> Optional[Dict[str, Any]]:
        """Get bundle by bundle_id."""
        try:
            bundle = await BundleOperations.get_bundle_collection().find_one(
                {"bundle_id": bundle_id}
            )
            return bundle

        except PyMongoError as e:
            logger.error(f"Error fetching bundle {bundle_id}: {e}")
            raise

    @staticmethod
    async def update_bundle_status(bundle_id: str, status: str) -> bool:
        """Update bundle status."""
        try:
            result = await BundleOperations.get_bundle_collection().update_one(
                {"bundle_id": bundle_id},
                {
                    "$set": {
                        "status": status,
                        "updated_at": datetime.now(),
                        "completed_at": datetime.now() if status == "completed" else None
                    }
                }
            )

            success = result.modified_count > 0
            if success:
                logger.info(f"Updated bundle {bundle_id} status to {status}")
            else:
                logger.warning(f"Bundle {bundle_id} not found for status update")

            return success

        except PyMongoError as e:
            logger.error(f"Error updating bundle {bundle_id} status: {e}")
            raise

    @staticmethod
    async def get_bundle_member_orders(bundle_id: str) -> List[Dict[str, Any]]:
        """Get all orders that are part of a bundle."""
        try:
            from app.database.orders import OrderOperations

            orders = await OrderOperations.get_orders_by_bundle_id(bundle_id)
            return orders

        except PyMongoError as e:
            logger.error(f"Error fetching bundle member orders for {bundle_id}: {e}")
            raise

    @staticmethod
    async def get_user_bundles(user_id: str) -> List[Dict[str, Any]]:
        """Get all bundles for a user."""
        try:
            bundles = await BundleOperations.get_bundle_collection().find(
                {"user_id": user_id}
            ).sort("created_at", -1).to_list(length=None)

            return bundles

        except PyMongoError as e:
            logger.error(f"Error fetching bundles for user {user_id}: {e}")
            raise

    @staticmethod
    async def create_bundle_template(template_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new bundle template."""
        try:
            template_data["created_at"] = datetime.now()
            template_data["updated_at"] = datetime.now()

            result = await BundleOperations.get_bundle_templates_collection().insert_one(template_data)
            template_data["_id"] = result.inserted_id

            logger.info(f"Created bundle template {template_data.get('template_id', 'unknown')}")
            return template_data

        except PyMongoError as e:
            logger.error(f"Error creating bundle template: {e}")
            raise

    @staticmethod
    async def get_bundle_template(template_id: str) -> Optional[Dict[str, Any]]:
        """Get bundle template by template_id."""
        try:
            template = await BundleOperations.get_bundle_templates_collection().find_one(
                {"template_id": template_id, "is_active": True}
            )
            return template

        except PyMongoError as e:
            logger.error(f"Error fetching bundle template {template_id}: {e}")
            raise

    @staticmethod
    async def get_active_bundle_templates() -> List[Dict[str, Any]]:
        """Get all active bundle templates."""
        try:
            templates = await BundleOperations.get_bundle_templates_collection().find(
                {"is_active": True}
            ).sort("created_at", -1).to_list(length=None)

            return templates

        except PyMongoError as e:
            logger.error(f"Error fetching active bundle templates: {e}")
            raise

    @staticmethod
    async def update_bundle_payment_status(bundle_payment_id: str, status: str) -> int:
        """Update all orders in a bundle with the same payment status."""
        try:
            from app.database.orders import OrderOperations

            # Find all orders with this bundle_payment_id
            orders = await OrderOperations.get_orders_by_bundle_payment_id(bundle_payment_id)

            updated_count = 0
            for order in orders:
                success = await OrderOperations.update_order_status(order["order_id"], status)
                if success:
                    updated_count += 1

            logger.info(f"Updated {updated_count} orders for bundle payment {bundle_payment_id} to status {status}")
            return updated_count

        except PyMongoError as e:
            logger.error(f"Error updating bundle payment status {bundle_payment_id}: {e}")
            raise
