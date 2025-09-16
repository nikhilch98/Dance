"""Background order expiry service."""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import threading

from app.database.orders import OrderOperations
from app.models.orders import OrderStatusEnum
from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)


class BackgroundOrderExpiryService:
    """Service for background order expiry checking and processing."""

    def __init__(self):
        self.processing = False
        self.last_run = None
        self.check_interval_minutes = 1  # Check every 1 minute
        self._lock = threading.Lock()  # Thread lock for race condition prevention
        self.min_run_interval_seconds = 30  # Minimum 30 seconds between runs

    async def process_expired_orders(self, batch_size: int = 50) -> Dict[str, Any]:
        """Process expired orders and mark them as expired.

        Args:
            batch_size: Number of orders to process in one batch

        Returns:
            Processing results summary
        """
        # Check if enough time has passed since last run
        if self.last_run:
            time_since_last_run = (datetime.now() - self.last_run).total_seconds()
            if time_since_last_run < self.min_run_interval_seconds:
                logger.debug(f"Skipping order expiry check - only {time_since_last_run:.1f}s since last run")
                return {"status": "skipped", "reason": "too_soon", "seconds_since_last_run": time_since_last_run}

        # Use thread lock to prevent race conditions
        if not self._lock.acquire(blocking=False):
            logger.warning("Order expiry processing already in progress, skipping")
            return {"status": "skipped", "reason": "already_processing"}

        try:
            self.processing = True
            start_time = datetime.now()

            # Get orders that have expired payment links
            expired_orders = self._get_expired_orders(limit=batch_size)

            if not expired_orders:
                logger.info("No expired orders found")
                return {
                    "status": "completed",
                    "processed": 0,
                    "skipped": 0,
                    "duration_seconds": 0
                }

            logger.info(f"Found {len(expired_orders)} expired orders to process")

            processed_count = 0
            skipped_count = 0
            processed_orders = []
            skipped_orders = []

            for order in expired_orders:
                try:
                    order_id = order['order_id']
                    current_status = order.get('status', 'unknown')

                    # Skip if already expired or cancelled
                    if current_status in [OrderStatusEnum.EXPIRED.value, OrderStatusEnum.CANCELLED.value]:
                        logger.debug(f"Order {order_id} already has status {current_status}, skipping")
                        skipped_count += 1
                        skipped_orders.append(order_id)
                        continue

                    # Skip if order is already paid
                    if current_status == OrderStatusEnum.PAID.value:
                        logger.debug(f"Order {order_id} is already paid, skipping expiry")
                        skipped_count += 1
                        skipped_orders.append(order_id)
                        continue

                    # Double-check order status before updating to prevent race conditions
                    current_order = OrderOperations.get_order_by_id(order_id)
                    if not current_order:
                        logger.warning(f"Order {order_id} not found during expiry processing")
                        skipped_count += 1
                        skipped_orders.append(order_id)
                        continue
                    
                    current_status = current_order.get('status', 'unknown')
                    if current_status in [OrderStatusEnum.EXPIRED.value, OrderStatusEnum.CANCELLED.value, OrderStatusEnum.PAID.value]:
                        logger.debug(f"Order {order_id} status changed to {current_status} during processing, skipping")
                        skipped_count += 1
                        skipped_orders.append(order_id)
                        continue

                    # Mark order as expired
                    success = OrderOperations.update_order_status(
                        order_id,
                        OrderStatusEnum.EXPIRED,
                        additional_data={
                            "expiry_processed_at": datetime.utcnow(),
                            "original_expires_at": order.get('expires_at'),
                            "auto_expiry": True,
                            "payment_link_id": order.get('payment_link_id')
                        }
                    )

                    if success:
                        processed_count += 1
                        processed_orders.append(order_id)
                        logger.info(f"Successfully marked order {order_id} as expired")
                    else:
                        logger.error(f"Failed to update status for expired order {order_id}")
                        skipped_count += 1
                        skipped_orders.append(order_id)

                except Exception as e:
                    logger.error(f"Error processing expired order {order.get('order_id', 'unknown')}: {str(e)}")
                    skipped_count += 1
                    if order.get('order_id'):
                        skipped_orders.append(order['order_id'])

            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()

            result = {
                "status": "completed",
                "processed": processed_count,
                "skipped": skipped_count,
                "duration_seconds": duration,
                "processed_orders": processed_orders,
                "skipped_orders": skipped_orders
            }

            logger.info(f"Order expiry batch completed: {processed_count} processed, {skipped_count} skipped")
            self.last_run = end_time

            return result

        except Exception as e:
            logger.error(f"Critical error in order expiry process: {str(e)}")
            return {
                "status": "error",
                "error": str(e),
                "processed": 0,
                "skipped": 0
            }
        finally:
            self.processing = False
            self._lock.release()

    def _get_expired_orders(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Get orders with expired payment links.

        Args:
            limit: Maximum number of orders to return

        Returns:
            List of expired order documents
        """
        try:
            client = get_mongo_client()
            now = datetime.utcnow()

            # Find orders that:
            # 1. Have an expires_at field
            # 2. expires_at is in the past
            # 3. Are not already expired, cancelled, or paid
            pipeline = [
                {
                    "$match": {
                        "expires_at": {"$exists": True, "$ne": None},
                        "expires_at": {"$lt": now},
                        "status": {
                            "$nin": [
                                OrderStatusEnum.EXPIRED.value,
                                OrderStatusEnum.CANCELLED.value,
                                OrderStatusEnum.PAID.value
                            ]
                        }
                    }
                },
                {
                    "$sort": {"expires_at": 1}  # Process oldest expired orders first
                },
                {
                    "$limit": limit
                }
            ]

            expired_orders = list(client["dance_app"]["orders"].aggregate(pipeline))
            logger.debug(f"Found {len(expired_orders)} expired orders")

            return expired_orders

        except Exception as e:
            logger.error(f"Error fetching expired orders: {str(e)}")
            # Return empty list to prevent service from crashing
            return []

    def get_processing_status(self) -> Dict[str, Any]:
        """Get current processing status.

        Returns:
            Status information
        """
        return {
            "processing": self.processing,
            "last_run": self.last_run.isoformat() if self.last_run else None,
            "service_active": True,
            "check_interval_minutes": self.check_interval_minutes
        }


# Global service instance
background_order_expiry_service = BackgroundOrderExpiryService()


def get_background_order_expiry_service() -> BackgroundOrderExpiryService:
    """Get background order expiry service instance."""
    return background_order_expiry_service


async def run_order_expiry_check() -> Dict[str, Any]:
    """Run a single batch of order expiry checking.

    Returns:
        Processing results
    """
    service = get_background_order_expiry_service()
    return await service.process_expired_orders()


async def start_background_order_expiry_worker():
    """Start the background order expiry worker.

    This function runs continuously and processes expired orders
    every 1 minute.
    """
    logger.info("Starting background order expiry worker")

    while True:
        try:
            # Run order expiry check
            result = await run_order_expiry_check()

            if result.get("processed", 0) > 0:
                logger.info(f"Background order expiry batch: {result}")

            # Wait 1 minute before next check
            await asyncio.sleep(60)  # 1 minute

        except Exception as e:
            logger.error(f"Error in background order expiry worker: {str(e)}")
            # Wait 1 minute before retrying on error
            await asyncio.sleep(60)


def schedule_order_expiry_task():
    """Schedule the background order expiry task."""
    try:
        # Create the background task
        task = asyncio.create_task(start_background_order_expiry_worker())
        logger.info("Background order expiry task scheduled")
        return task
    except Exception as e:
        logger.error(f"Failed to schedule order expiry task: {str(e)}")
        return None
