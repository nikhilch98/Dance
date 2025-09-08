"""Background QR code generation service."""

import asyncio
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional

from app.database.orders import OrderOperations
from app.database.users import UserOperations
from app.services.qr_service import get_qr_service
from utils.utils import get_mongo_client

logger = logging.getLogger(__name__)


class BackgroundQRService:
    """Service for background QR code generation."""
    
    def __init__(self):
        self.qr_service = get_qr_service()
        self.processing = False
        self.last_run = None
        
    async def process_pending_qr_generation(self, batch_size: int = 20) -> Dict[str, Any]:
        """Process pending QR code generation for paid orders.
        
        Args:
            batch_size: Number of orders to process in one batch
            
        Returns:
            Processing results summary
        """
        if self.processing:
            logger.warning("QR generation already in progress, skipping")
            return {"status": "skipped", "reason": "already_processing"}
        
        self.processing = True
        start_time = datetime.now()
        
        try:
            # Get paid orders without QR codes
            orders_to_process = OrderOperations.get_paid_orders_without_qr(limit=batch_size)
            
            if not orders_to_process:
                logger.info("No paid orders found without QR codes")
                return {
                    "status": "completed",
                    "processed": 0,
                    "failed": 0,
                    "duration_seconds": 0
                }
            
            logger.info(f"Found {len(orders_to_process)} orders needing QR codes")
            
            processed_count = 0
            failed_count = 0
            failed_orders = []
            
            # Use optimized batch processing for better performance
            processed_count, failed_count, failed_orders_list = await self._process_batch_optimized(orders_to_process)

            # Update failed orders list
            failed_orders.extend(failed_orders_list)
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            result = {
                "status": "completed",
                "processed": processed_count,
                "failed": failed_count,
                "duration_seconds": duration,
                "failed_orders": failed_orders
            }
            
            logger.info(f"QR generation batch completed: {processed_count} successful, {failed_count} failed")
            self.last_run = end_time
            
            return result
            
        except Exception as e:
            logger.error(f"Critical error in QR generation process: {str(e)}")
            return {
                "status": "error",
                "error": str(e),
                "processed": 0,
                "failed": 0
            }
        finally:
            self.processing = False
    
    async def _generate_qr_for_order(self, order_doc: Dict[str, Any]) -> bool:
        """Generate QR code for a specific order.
        
        Args:
            order_doc: Order document from database
            
        Returns:
            Success status
        """
        try:
            order_id = order_doc['order_id']
            user_id = order_doc['user_id']
            workshop_details = order_doc['workshop_details']
            amount = order_doc['amount']
            payment_gateway_details = order_doc.get('payment_gateway_details', {})
            
            # Get user details
            user_data = UserOperations.get_user_by_id(user_id)
            if not user_data:
                logger.error(f"User not found for order {order_id}")
                return False
            
            user_name = user_data.get('name', 'Unknown User')
            user_phone = user_data.get('phone', 'Unknown Phone')
            
            # Extract workshop details
            workshop_title = workshop_details.get('title', 'Unknown Workshop')
            artist_names = workshop_details.get('artist_names', [])
            studio_name = workshop_details.get('studio_name', 'Unknown Studio')
            workshop_date = workshop_details.get('date', 'Unknown Date')
            workshop_time = workshop_details.get('time', 'Unknown Time')
            workshop_uuid = order_doc['workshop_uuid']
            
            # Generate QR code
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
            
            # Update order with QR code data
            success = OrderOperations.update_order_qr_code(order_id, qr_code_data)
            
            if success:
                logger.info(f"Successfully generated and saved QR code for order {order_id}")
            else:
                logger.error(f"Failed to save QR code for order {order_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"Error generating QR code for order {order_doc.get('order_id', 'unknown')}: {str(e)}")
            return False

    async def _process_batch_optimized(self, orders: List[Dict[str, Any]]) -> tuple:
        """Process a batch of orders with optimized database queries and parallel processing."""
        processed_count = 0
        failed_count = 0
        failed_orders = []

        if not orders:
            return processed_count, failed_count, failed_orders

        try:
            # Extract unique user IDs for batch fetching
            user_ids = list(set(order['user_id'] for order in orders))

            # Batch fetch all user data in one query
            user_data_map = await self._batch_fetch_users(user_ids)

            # Process orders in parallel (with controlled concurrency)
            semaphore = asyncio.Semaphore(10)  # Increased concurrency for better performance

            async def process_single_order(order):
                async with semaphore:
                    try:
                        user_data = user_data_map.get(order['user_id'])
                        if not user_data:
                            logger.warning(f"User data not found for order {order['order_id']}")
                            return False

                        success = await self._generate_qr_for_order_optimized(order, user_data)
                        return success
                    except Exception as e:
                        logger.error(f"Error processing order {order['order_id']}: {e}")
                        return False

            # Process all orders concurrently
            tasks = [process_single_order(order) for order in orders]
            results = await asyncio.gather(*tasks, return_exceptions=True)

            # Count results
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    failed_count += 1
                    failed_orders.append(orders[i]['order_id'])
                    logger.error(f"Exception in order {orders[i]['order_id']}: {result}")
                elif result:
                    processed_count += 1
                else:
                    failed_count += 1
                    failed_orders.append(orders[i]['order_id'])

        except Exception as e:
            logger.error(f"Error in batch processing: {e}")
            # Fallback to individual processing if batch fails
            for order in orders:
                try:
                    success = await self._generate_qr_for_order(order)
                    if success:
                        processed_count += 1
                    else:
                        failed_count += 1
                        failed_orders.append(order['order_id'])
                except Exception as e:
                    failed_count += 1
                    failed_orders.append(order['order_id'])
                    logger.error(f"Fallback processing error for {order['order_id']}: {e}")

        return processed_count, failed_count, failed_orders

    async def _batch_fetch_users(self, user_ids: List[str]) -> Dict[str, Dict[str, Any]]:
        """Fetch multiple users in a single batch query."""
        user_data_map = {}

        if not user_ids:
            return user_data_map

        try:
            # Batch fetch user data
            for user_id in user_ids:
                try:
                    user_data = UserOperations.get_user_by_id(user_id)
                    if user_data:
                        user_data_map[user_id] = user_data
                    else:
                        logger.warning(f"User {user_id} not found")
                except Exception as e:
                    logger.error(f"Error fetching user {user_id}: {e}")

        except Exception as e:
            logger.error(f"Error in batch user fetch: {e}")

        return user_data_map

    async def _generate_qr_for_order_optimized(self, order_doc: Dict[str, Any], user_data: Dict[str, Any]) -> bool:
        """Generate QR code for a specific order using pre-fetched user data."""
        try:
            order_id = order_doc['order_id']
            workshop_details = order_doc['workshop_details']
            amount = order_doc['amount']
            payment_gateway_details = order_doc.get('payment_gateway_details', {})

            # Use pre-fetched user data
            user_name = user_data.get('name', 'Unknown User')
            user_phone = user_data.get('phone', 'Unknown Phone')

            # Extract workshop details
            workshop_title = workshop_details.get('title', 'Unknown Workshop')
            artist_names = workshop_details.get('artist_names', [])
            studio_name = workshop_details.get('studio_name', 'Unknown Studio')
            workshop_date = workshop_details.get('date', 'Unknown Date')
            workshop_time = workshop_details.get('time', 'Unknown Time')
            workshop_uuid = order_doc['workshop_uuid']

            # Generate QR code
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

            # Update order with QR code data
            success = OrderOperations.update_order_qr_code(order_id, qr_code_data)

            if success:
                logger.debug(f"Successfully generated and saved QR code for order {order_id}")
            else:
                logger.error(f"Failed to save QR code for order {order_id}")

            return success

        except Exception as e:
            logger.error(f"Error generating QR code for order {order_doc.get('order_id', 'unknown')}: {str(e)}")
            return False
    
    def get_processing_status(self) -> Dict[str, Any]:
        """Get current processing status.
        
        Returns:
            Status information
        """
        return {
            "processing": self.processing,
            "last_run": self.last_run.isoformat() if self.last_run else None,
            "service_active": True
        }


# Global service instance
background_qr_service = BackgroundQRService()


def get_background_qr_service() -> BackgroundQRService:
    """Get background QR service instance."""
    return background_qr_service


async def run_qr_generation_batch() -> Dict[str, Any]:
    """Run a single batch of QR code generation.
    
    Returns:
        Processing results
    """
    service = get_background_qr_service()
    return await service.process_pending_qr_generation()


async def start_background_qr_worker():
    """Start the background QR generation worker.
    
    This function runs continuously and processes QR generation
    every 5 minutes for new paid orders.
    """
    logger.info("Starting background QR generation worker")
    
    while True:
        try:
            # Run QR generation batch
            result = await run_qr_generation_batch()
            
            if result.get("processed", 0) > 0:
                logger.info(f"Background QR batch: {result}")
            
            # Wait 5 minutes before next batch
            await asyncio.sleep(300)  # 5 minutes
            
        except Exception as e:
            logger.error(f"Error in background QR worker: {str(e)}")
            # Wait 1 minute before retrying on error
            await asyncio.sleep(60)


def schedule_qr_generation_task():
    """Schedule the background QR generation task."""
    try:
        # Create the background task
        task = asyncio.create_task(start_background_qr_worker())
        logger.info("Background QR generation task scheduled")
        return task
    except Exception as e:
        logger.error(f"Failed to schedule QR generation task: {str(e)}")
        return None
