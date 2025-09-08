"""Background rewards generation service for workshop bookings."""

import asyncio
import logging
from datetime import datetime
from typing import List, Optional
from bson import ObjectId

from app.database.orders import OrderOperations
from app.database.rewards import RewardOperations
from app.models.rewards import (
    RewardTransaction,
    RewardTransactionTypeEnum,
    RewardSourceEnum,
    RewardTransactionStatusEnum,
)
from app.models.orders import OrderStatusEnum
from app.config.settings import get_settings

logger = logging.getLogger(__name__)

class BackgroundRewardsService:
    """Service for generating rewards for paid orders in the background."""
    
    def __init__(self):
        self.order_operations = OrderOperations()
        self.reward_operations = RewardOperations()
        self.settings = get_settings()
        self.is_running = False
        
    async def start_rewards_generation_service(self):
        """Start the background rewards generation service."""
        if self.is_running:
            logger.info("Background rewards generation service is already running")
            return

        self.is_running = True
        logger.info("Starting background rewards generation service...")

        try:
            # Process immediately on startup
            logger.info("Processing rewards batch on startup...")
            await self._process_rewards_batch()

            while self.is_running:
                await self._process_rewards_batch()
                # Wait 30 seconds before next batch
                await asyncio.sleep(30)
        except asyncio.CancelledError:
            logger.info("Background rewards generation service cancelled")
        except Exception as e:
            logger.error(f"Critical error in rewards generation service: {e}")
            # Try to restart the service after error
            if self.is_running:
                logger.info("Attempting to restart rewards service after error...")
                await asyncio.sleep(5)
                asyncio.create_task(self.start_rewards_generation_service())
        finally:
            self.is_running = False
            
    async def stop_rewards_generation_service(self):
        """Stop the background rewards generation service."""
        logger.info("Stopping background rewards generation service...")
        self.is_running = False
        
    async def _process_rewards_batch(self):
        """Process a batch of paid orders that need rewards generated."""
        try:
            # Get paid orders without rewards generated
            orders = self._get_paid_orders_without_rewards()

            logger.info(f"Rewards service check: Found {len(orders)} orders needing rewards generation")

            if not orders:
                logger.info("No orders found requiring rewards generation")
                return

            logger.info(f"Processing {len(orders)} orders for rewards generation")

            processed_count = 0
            failed_count = 0

            for order in orders:
                try:
                    success = self._generate_rewards_for_order(order)
                    if success:
                        processed_count += 1
                        logger.info(f"Successfully generated rewards for order {order['order_id']}")
                    else:
                        failed_count += 1
                        logger.warning(f"Failed to generate rewards for order {order['order_id']}")
                except Exception as e:
                    failed_count += 1
                    logger.error(f"Exception generating rewards for order {order['order_id']}: {e}")

            logger.info(f"Rewards batch completed: {processed_count} successful, {failed_count} failed")

        except Exception as e:
            logger.error(f"Error processing rewards batch: {e}")
            
    def _get_paid_orders_without_rewards(self) -> List[dict]:
        """Get all paid orders that don't have rewards generated yet."""
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            orders_collection = client["dance_app"]["orders"]
            
            # Get orders that are paid and don't have rewards generated flag
            orders = orders_collection.find({
                "status": OrderStatusEnum.PAID.value,
                "rewards_generated": {"$ne": True}
            }).limit(100)  # Process max 100 at a time
            
            return list(orders)
            
        except Exception as e:
            logger.error(f"Error fetching orders for rewards generation: {e}")
            return []
            
    def _generate_rewards_for_order(self, order: dict) -> bool:
        """Generate cashback rewards for a specific order."""
        try:
            user_id = str(order["user_id"])
            order_id = str(order["_id"])

            # Safely get and validate order amount
            raw_amount = order.get("amount", 0)
            try:
                if raw_amount is None:
                    logger.warning(f"Order {order_id} has None amount, skipping rewards generation")
                    return False

                order_amount = float(raw_amount)
                if order_amount <= 0:
                    logger.warning(f"Order {order_id} has invalid amount: {order_amount}, skipping rewards generation")
                    return False

                logger.debug(f"Processing order {order_id} with amount: {order_amount} paise")

            except (ValueError, TypeError) as e:
                logger.error(f"Invalid amount format for order {order_id}: {raw_amount} ({type(raw_amount)}), error: {e}")
                return False

            # Use final amount paid if available (after discounts), otherwise use original amount
            # This ensures cashback is calculated on the actual amount paid by the user
            final_amount_paid = order.get("final_amount_paid")

            try:
                if final_amount_paid is not None:
                    # Handle case where final_amount_paid might be a string
                    if isinstance(final_amount_paid, str):
                        final_amount_paid = float(final_amount_paid)
                    elif not isinstance(final_amount_paid, (int, float)):
                        final_amount_paid = None

                    if final_amount_paid is not None and final_amount_paid > 0:
                        # Convert rupees to paise and use final amount
                        amount_for_cashback = float(final_amount_paid) * 100
                        logger.debug(f"Using final amount paid for order {order_id}: ₹{final_amount_paid} → {amount_for_cashback} paise")
                    else:
                        # Fallback to original amount if final_amount_paid is 0 or invalid
                        amount_for_cashback = order_amount
                        logger.debug(f"Using original amount for order {order_id}: {amount_for_cashback} paise (final_amount_paid was 0 or invalid)")
                else:
                    # Fallback to original amount if final_amount_paid is None
                    amount_for_cashback = order_amount
                    logger.debug(f"Using original amount for order {order_id}: {amount_for_cashback} paise (final_amount_paid was None)")

            except (ValueError, TypeError) as e:
                # If there's any conversion error, fallback to original amount
                logger.warning(f"Error converting final_amount_paid for order {order_id}: {e}, using original amount")
                amount_for_cashback = order_amount

            # Skip if amount is 0 or invalid
            if amount_for_cashback <= 0:
                logger.warning(f"Skipping rewards for order {order_id} - invalid amount: {amount_for_cashback}")
                return False

            # Check if rewards already generated for this order
            if order.get("rewards_generated", False):
                logger.debug(f"Rewards already generated for order {order_id}")
                return True

            # Calculate configurable cashback percentage with proper rounding (in rupees)
            cashback_amount = self._calculate_cashback(amount_for_cashback)

            if cashback_amount <= 0:
                logger.warning(f"Skipping rewards for order {order_id} - no cashback calculated")
                return False

            cashback_percentage = self.settings.reward_cashback_percentage
            logger.info(f"Processing {cashback_percentage}% cashback for order {order_id}: Final amount paid ₹{amount_for_cashback/100:.2f} → Cashback ₹{cashback_amount}")

            # Create cashback transaction (with built-in duplicate prevention)
            # The create_transaction method automatically handles duplicates and updates wallet balance
            transaction_id = self.reward_operations.create_transaction(
                user_id=user_id,
                transaction_type=RewardTransactionTypeEnum.CREDIT,
                amount=cashback_amount,
                source=RewardSourceEnum.CASHBACK,
                description=f"{cashback_percentage}% cashback for workshop booking (Order: {order.get('order_id', order_id)})",
                reference_id=order_id
            )

            # Mark order as having rewards generated
            success = self._mark_order_rewards_generated(order_id, cashback_amount)

            if success:
                logger.info(f"Generated ₹{cashback_amount} cashback for order {order_id} (user: {user_id})")
                return True
            else:
                logger.error(f"Failed to mark order {order_id} as rewards generated")
                return False

        except Exception as e:
            logger.error(f"Error generating rewards for order {order.get('_id')}: {e}")
            return False
            
    def _calculate_cashback(self, order_amount: float) -> float:
        """Calculate configurable cashback percentage with proper rounding.
        
        Args:
            order_amount: Order amount in paise
            
        Returns:
            Cashback amount in rupees (not paise)
        """
        try:
            # Convert paise to rupees first
            order_amount_rupees = order_amount / 100.0
            
            # Calculate configurable cashback percentage in rupees
            cashback_percentage = self.settings.reward_cashback_percentage
            cashback_rupees = order_amount_rupees * (cashback_percentage / 100.0)
            
            # Round to nearest integer using standard rounding
            # 15.13 → 15, 15.5 → 16, 15.76 → 16
            rounded_cashback = round(cashback_rupees)
            
            return float(rounded_cashback)
            
        except Exception as e:
            logger.error(f"Error calculating cashback for amount {order_amount}: {e}")
            return 0.0
            
    def _mark_order_rewards_generated(self, order_id: str, cashback_amount: float):
        """Mark an order as having rewards generated."""
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            orders_collection = client["dance_app"]["orders"]
            
            result = orders_collection.update_one(
                {"_id": ObjectId(order_id)},
                {
                    "$set": {
                        "rewards_generated": True,
                        "cashback_amount": cashback_amount,
                        "rewards_generated_at": datetime.utcnow()
                    }
                }
            )
            
            if result.modified_count == 0:
                logger.warning(f"Failed to mark order {order_id} as rewards generated")
                
        except Exception as e:
            logger.error(f"Error marking order {order_id} as rewards generated: {e}")
            raise
            
    async def trigger_manual_rewards_generation(self) -> dict:
        """Manually trigger rewards generation for testing purposes."""
        try:
            logger.info("Manual rewards generation triggered")
            await self._process_rewards_batch()
            return {"success": True, "message": "Manual rewards generation completed"}
        except Exception as e:
            logger.error(f"Error in manual rewards generation: {e}")
            return {"success": False, "error": str(e)}
            
    async def get_rewards_generation_status(self) -> dict:
        """Get the current status of the rewards generation service."""
        try:
            pending_orders = self._get_paid_orders_without_rewards()
            
            return {
                "service_running": self.is_running,
                "pending_orders_count": len(pending_orders),
                "cashback_percentage": self.settings.reward_cashback_percentage,
                "last_check": datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error(f"Error getting rewards generation status: {e}")
            return {
                "service_running": self.is_running,
                "pending_orders_count": 0,
                "cashback_percentage": self.settings.reward_cashback_percentage,
                "last_check": datetime.utcnow().isoformat(),
                "error": str(e)
            }
