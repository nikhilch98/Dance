#!/usr/bin/env python3
"""Script to regenerate QR codes for all existing orders with the updated logo."""

import asyncio
import logging
import sys
import os
from datetime import datetime
from typing import List, Dict, Any, Optional

# Add the app directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'app'))

from app.database.orders import OrderOperations
from app.database.users import UserOperations
from app.services.qr_service import get_qr_service
from app.models.orders import OrderStatusEnum
from utils.utils import get_mongo_client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class QRCodeRegenerator:
    """Service to regenerate QR codes for all existing orders."""

    def __init__(self, batch_size: int = 10):
        self.qr_service = get_qr_service()
        self.batch_size = batch_size
        self.client = get_mongo_client()
        self.orders_collection = self.client["dance_app"]["orders"]

    def get_orders_with_qr_codes(self, limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get all paid orders that have QR codes."""
        try:
            query = {
                "status": OrderStatusEnum.PAID.value,
                "qr_code_data": {"$exists": True, "$ne": None, "$ne": ""}
            }

            orders = list(self.orders_collection.find(query).limit(limit) if limit else self.orders_collection.find(query))

            logger.info(f"Found {len(orders)} orders with existing QR codes")
            return orders

        except Exception as e:
            logger.error(f"Error fetching orders with QR codes: {str(e)}")
            return []

    def get_orders_without_qr_codes(self, limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get all paid orders that don't have QR codes."""
        try:
            query = {
                "status": OrderStatusEnum.PAID.value,
                "$or": [
                    {"qr_code_data": {"$exists": False}},
                    {"qr_code_data": None},
                    {"qr_code_data": ""}
                ]
            }

            orders = list(self.orders_collection.find(query).limit(limit) if limit else self.orders_collection.find(query))

            logger.info(f"Found {len(orders)} orders without QR codes")
            return orders

        except Exception as e:
            logger.error(f"Error fetching orders without QR codes: {str(e)}")
            return []

    async def regenerate_qr_for_order(self, order_doc: Dict[str, Any]) -> Dict[str, Any]:
        """Regenerate QR code for a specific order."""
        try:
            order_id = order_doc['order_id']
            user_id = order_doc['user_id']
            workshop_details = order_doc['workshop_details']
            amount = order_doc['amount']
            payment_gateway_details = order_doc.get('payment_gateway_details', {})

            # Get user details
            user_data = UserOperations.get_user_by_id(user_id)
            if not user_data:
                return {
                    "order_id": order_id,
                    "success": False,
                    "error": "User not found"
                }

            user_name = user_data.get('name', 'Unknown User')
            user_phone = user_data.get('phone', 'Unknown Phone')

            # Extract workshop details
            workshop_title = workshop_details.get('title', 'Unknown Workshop')
            artist_names = workshop_details.get('artist_names', [])
            studio_name = workshop_details.get('studio_name', 'Unknown Studio')
            workshop_date = workshop_details.get('date', 'Unknown Date')
            workshop_time = workshop_details.get('time', 'Unknown Time')
            workshop_uuid = order_doc['workshop_uuid']

            # Generate new QR code with logo
            qr_code_data = self.qr_service.generate_order_qr_code(
                order_id=order_id,
                workshop_title=workshop_title,
                amount=amount,
                user_name=user_name,
                user_phone=user_phone,
                workshop_uuid=workshop_uuid,
                artist_names=artist_names,
                studio_name=studio_name,
                workshop_date=workshop_date,
                workshop_time=workshop_time,
                payment_gateway_details=payment_gateway_details
            )

            # Update order with new QR code data
            success = OrderOperations.update_order_qr_code(order_id, qr_code_data)

            if success:
                logger.info(f"Successfully regenerated QR code for order {order_id}")
                return {
                    "order_id": order_id,
                    "success": True,
                    "qr_code_length": len(qr_code_data)
                }
            else:
                logger.error(f"Failed to update QR code for order {order_id}")
                return {
                    "order_id": order_id,
                    "success": False,
                    "error": "Database update failed"
                }

        except Exception as e:
            logger.error(f"Error regenerating QR code for order {order_doc.get('order_id', 'unknown')}: {str(e)}")
            return {
                "order_id": order_doc.get('order_id', 'unknown'),
                "success": False,
                "error": str(e)
            }

    async def regenerate_all_qr_codes(self, limit: Optional[int] = None) -> Dict[str, Any]:
        """Regenerate QR codes for all orders that have them."""
        logger.info("Starting QR code regeneration process...")

        # Get all orders with QR codes
        orders = self.get_orders_with_qr_codes(limit)

        if not orders:
            return {
                "success": True,
                "message": "No orders found with QR codes",
                "total_orders": 0,
                "processed": 0,
                "successful": 0,
                "failed": 0
            }

        logger.info(f"Starting regeneration of {len(orders)} QR codes...")

        processed = 0
        successful = 0
        failed = 0
        failed_orders = []

        # Process in batches
        for i in range(0, len(orders), self.batch_size):
            batch = orders[i:i + self.batch_size]
            logger.info(f"Processing batch {i//self.batch_size + 1}/{(len(orders) + self.batch_size - 1)//self.batch_size} ({len(batch)} orders)")

            # Process batch concurrently
            tasks = [self.regenerate_qr_for_order(order) for order in batch]
            batch_results = await asyncio.gather(*tasks, return_exceptions=True)

            # Process results
            for j, result in enumerate(batch_results):
                processed += 1

                if isinstance(result, Exception):
                    failed += 1
                    order_id = batch[j].get('order_id', f'batch_{i}_order_{j}')
                    failed_orders.append({"order_id": order_id, "error": str(result)})
                    logger.error(f"Exception in order {order_id}: {result}")
                elif result["success"]:
                    successful += 1
                else:
                    failed += 1
                    failed_orders.append(result)

            # Progress update
            logger.info(f"Progress: {processed}/{len(orders)} orders processed ({successful} successful, {failed} failed)")

        result = {
            "success": True,
            "message": f"QR code regeneration completed",
            "total_orders": len(orders),
            "processed": processed,
            "successful": successful,
            "failed": failed,
            "failed_orders": failed_orders[:10],  # Limit failed orders in response
            "completion_time": datetime.now().isoformat()
        }

        logger.info(f"QR code regeneration completed: {successful}/{processed} successful")
        return result

    async def generate_missing_qr_codes(self, limit: Optional[int] = None) -> Dict[str, Any]:
        """Generate QR codes for orders that don't have them yet."""
        logger.info("Starting QR code generation for missing orders...")

        # Get all paid orders without QR codes
        orders = self.get_orders_without_qr_codes(limit)

        if not orders:
            return {
                "success": True,
                "message": "No orders found without QR codes",
                "total_orders": 0,
                "processed": 0,
                "successful": 0,
                "failed": 0
            }

        logger.info(f"Starting generation of {len(orders)} missing QR codes...")

        processed = 0
        successful = 0
        failed = 0
        failed_orders = []

        # Process in batches
        for i in range(0, len(orders), self.batch_size):
            batch = orders[i:i + self.batch_size]
            logger.info(f"Processing batch {i//self.batch_size + 1}/{(len(orders) + self.batch_size - 1)//self.batch_size} ({len(batch)} orders)")

            # Process batch concurrently
            tasks = [self.regenerate_qr_for_order(order) for order in batch]
            batch_results = await asyncio.gather(*tasks, return_exceptions=True)

            # Process results
            for j, result in enumerate(batch_results):
                processed += 1

                if isinstance(result, Exception):
                    failed += 1
                    order_id = batch[j].get('order_id', f'batch_{i}_order_{j}')
                    failed_orders.append({"order_id": order_id, "error": str(result)})
                    logger.error(f"Exception in order {order_id}: {result}")
                elif result["success"]:
                    successful += 1
                else:
                    failed += 1
                    failed_orders.append(result)

            # Progress update
            logger.info(f"Progress: {processed}/{len(orders)} orders processed ({successful} successful, {failed} failed)")

        result = {
            "success": True,
            "message": f"Missing QR code generation completed",
            "total_orders": len(orders),
            "processed": processed,
            "successful": successful,
            "failed": failed,
            "failed_orders": failed_orders[:10],  # Limit failed orders in response
            "completion_time": datetime.now().isoformat()
        }

        logger.info(f"Missing QR code generation completed: {successful}/{processed} successful")
        return result

    def get_qr_statistics(self) -> Dict[str, Any]:
        """Get statistics about QR codes in the system."""
        try:
            # Total paid orders
            total_paid = self.orders_collection.count_documents({
                "status": OrderStatusEnum.PAID.value
            })

            # Orders with QR codes
            with_qr = self.orders_collection.count_documents({
                "status": OrderStatusEnum.PAID.value,
                "qr_code_data": {"$exists": True, "$ne": None, "$ne": ""}
            })

            # Orders without QR codes
            without_qr = self.orders_collection.count_documents({
                "status": OrderStatusEnum.PAID.value,
                "$or": [
                    {"qr_code_data": {"$exists": False}},
                    {"qr_code_data": None},
                    {"qr_code_data": ""}
                ]
            })

            return {
                "total_paid_orders": total_paid,
                "orders_with_qr_codes": with_qr,
                "orders_without_qr_codes": without_qr,
                "qr_coverage_percentage": round((with_qr / total_paid * 100), 2) if total_paid > 0 else 0
            }

        except Exception as e:
            logger.error(f"Error getting QR statistics: {str(e)}")
            return {"error": str(e)}


async def main():
    """Main function to run QR code regeneration."""
    import argparse

    parser = argparse.ArgumentParser(description='Regenerate QR codes for orders')
    parser.add_argument('--mode', choices=['regenerate', 'missing', 'stats'],
                       default='regenerate', help='Mode: regenerate existing QR codes, generate missing ones, or show statistics')
    parser.add_argument('--limit', type=int, help='Limit number of orders to process')
    parser.add_argument('--batch-size', type=int, default=10, help='Batch size for processing')

    args = parser.parse_args()

    regenerator = QRCodeRegenerator(batch_size=args.batch_size)

    if args.mode == 'stats':
        stats = regenerator.get_qr_statistics()
        print("\n=== QR Code Statistics ===")
        for key, value in stats.items():
            print(f"{key}: {value}")
        return

    elif args.mode == 'regenerate':
        print(f"Starting QR code regeneration for all existing orders...")
        if args.limit:
            print(f"Limited to {args.limit} orders")
        result = await regenerator.regenerate_all_qr_codes(args.limit)

    elif args.mode == 'missing':
        print(f"Starting QR code generation for orders missing them...")
        if args.limit:
            print(f"Limited to {args.limit} orders")
        result = await regenerator.generate_missing_qr_codes(args.limit)

    print("\n=== Results ===")
    print(f"Total orders: {result.get('total_orders', 0)}")
    print(f"Processed: {result.get('processed', 0)}")
    print(f"Successful: {result.get('successful', 0)}")
    print(f"Failed: {result.get('failed', 0)}")

    if result.get('failed_orders'):
        print("\n=== Failed Orders (first 5) ===")
        for failed in result['failed_orders'][:5]:
            print(f"- {failed['order_id']}: {failed.get('error', 'Unknown error')}")

    print(f"\nCompletion time: {result.get('completion_time', 'Unknown')}")


if __name__ == "__main__":
    asyncio.run(main())
