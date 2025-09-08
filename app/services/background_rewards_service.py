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
        logger.info("Starting background rewards generation service with enhanced duplicate prevention...")

        try:
            # Clean up any inconsistent state on startup
            logger.info("Cleaning up inconsistent orders on startup...")
            cleanup_count = self._cleanup_inconsistent_orders()
            if cleanup_count > 0:
                logger.info(f"Cleaned up {cleanup_count} inconsistent orders on startup")

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
        """Get all paid orders that don't have rewards generated yet.

        This method includes enhanced duplicate prevention by checking both:
        1. The rewards_generated flag
        2. Whether a cashback transaction already exists for the order
        """
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            orders_collection = client["dance_app"]["orders"]
            transactions_collection = client["dance_app"]["reward_transactions"]

            # First, get orders that are paid and don't have rewards_generated flag
            candidate_orders = list(orders_collection.find({
                "status": OrderStatusEnum.PAID.value,
                "rewards_generated": {"$ne": True}
            }).limit(200))  # Get more candidates to account for filtering

            if not candidate_orders:
                return []

            # Extract order IDs to check for existing transactions
            order_ids = [str(order["_id"]) for order in candidate_orders]

            # Find orders that already have cashback transactions
            existing_transaction_orders = set()
            for order_id in order_ids:
                # Check if there's already a cashback transaction for this order
                existing_tx = transactions_collection.find_one({
                    "reference_id": order_id,
                    "source": RewardSourceEnum.CASHBACK.value,
                    "transaction_type": RewardTransactionTypeEnum.CREDIT.value
                })
                if existing_tx:
                    existing_transaction_orders.add(order_id)
                    logger.debug(f"Order {order_id} already has cashback transaction {existing_tx['transaction_id']}")

            # Filter out orders that already have transactions
            filtered_orders = [
                order for order in candidate_orders
                if str(order["_id"]) not in existing_transaction_orders
            ]

            # Return only orders that truly need processing
            result_orders = filtered_orders[:100]  # Limit to 100 for processing

            if existing_transaction_orders:
                logger.info(f"Filtered out {len(existing_transaction_orders)} orders that already have cashback transactions")

            logger.info(f"Found {len(result_orders)} orders requiring rewards generation after duplicate check")
            return result_orders

        except Exception as e:
            logger.error(f"Error fetching orders for rewards generation: {e}")
            return []

    def _order_has_existing_cashback_transaction(self, order_id: str) -> bool:
        """Check if an order already has a cashback transaction.

        Args:
            order_id: The order ID to check

        Returns:
            True if cashback transaction exists, False otherwise
        """
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            transactions_collection = client["dance_app"]["reward_transactions"]

            # Check if there's already a cashback transaction for this order
            existing_tx = transactions_collection.find_one({
                "reference_id": order_id,
                "source": RewardSourceEnum.CASHBACK.value,
                "transaction_type": RewardTransactionTypeEnum.CREDIT.value
            })

            if existing_tx:
                logger.debug(f"Found existing cashback transaction {existing_tx['transaction_id']} for order {order_id}")
                return True

            return False

        except Exception as e:
            logger.error(f"Error checking for existing cashback transaction for order {order_id}: {e}")
            # If we can't check, assume no transaction exists to avoid blocking processing
            return False

    def _generate_rewards_for_order(self, order: dict) -> bool:
        """Generate cashback rewards for a specific order with enhanced duplicate prevention."""
        try:
            user_id = str(order["user_id"])
            order_id = str(order["_id"])

            # Additional duplicate check: Verify no existing cashback transaction
            if self._order_has_existing_cashback_transaction(order_id):
                logger.info(f"Order {order_id} already has cashback transaction, skipping")
                # Mark as processed to prevent future reprocessing
                self._mark_order_rewards_generated(order_id, 0.0)
                return True

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
                # Still mark as processed to avoid reprocessing
                self._mark_order_rewards_generated(order_id, 0.0)
                return True

            cashback_percentage = self.settings.reward_cashback_percentage
            logger.info(f"Processing {cashback_percentage}% cashback for order {order_id}: Final amount paid ₹{amount_for_cashback/100:.2f} → Cashback ₹{cashback_amount}")

            # Create cashback transaction with error handling and rollback
            transaction_id = None
            try:
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
                    logger.info(f"Successfully generated ₹{cashback_amount} cashback for order {order_id} (user: {user_id})")
                    return True
                else:
                    logger.error(f"Failed to mark order {order_id} as rewards generated after creating transaction")
                    # Transaction was created but order marking failed - this is a problem
                    # The transaction exists but order will be reprocessed
                    # This should be handled by the duplicate check on next run
                    return False

            except Exception as transaction_error:
                logger.error(f"Failed to create cashback transaction for order {order_id}: {transaction_error}")
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
            
    def _mark_order_rewards_generated(self, order_id: str, cashback_amount: float) -> bool:
        """Mark an order as having rewards generated.

        Args:
            order_id: The order ID to mark
            cashback_amount: The cashback amount awarded (0.0 for no rewards)

        Returns:
            True if successfully marked, False otherwise
        """
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            orders_collection = client["dance_app"]["orders"]

            update_data = {
                "rewards_generated": True,
                "rewards_generated_at": datetime.utcnow()
            }

            # Only set cashback_amount if it's greater than 0
            if cashback_amount > 0:
                update_data["cashback_amount"] = cashback_amount

            result = orders_collection.update_one(
                {"_id": ObjectId(order_id)},
                {"$set": update_data}
            )

            if result.modified_count == 0:
                logger.warning(f"Failed to mark order {order_id} as rewards generated (modified_count: 0)")
                return False
            else:
                logger.debug(f"Successfully marked order {order_id} as rewards generated")
                return True

        except Exception as e:
            logger.error(f"Error marking order {order_id} as rewards generated: {e}")
            return False
            
    async def trigger_manual_rewards_generation(self) -> dict:
        """Manually trigger rewards generation for testing purposes."""
        try:
            logger.info("Manual rewards generation triggered")

            # First, clean up any inconsistent state
            cleanup_count = self._cleanup_inconsistent_orders()
            if cleanup_count > 0:
                logger.info(f"Cleaned up {cleanup_count} inconsistent orders before processing")

            await self._process_rewards_batch()
            return {"success": True, "message": f"Manual rewards generation completed (cleaned up {cleanup_count} inconsistent orders)"}
        except Exception as e:
            logger.error(f"Error in manual rewards generation: {e}")
            return {"success": False, "error": str(e)}

    def _cleanup_inconsistent_orders(self) -> int:
        """Clean up orders that have cashback transactions but are not marked as processed.

        Returns:
            Number of orders cleaned up
        """
        try:
            from utils.utils import get_mongo_client
            client = get_mongo_client()
            orders_collection = client["dance_app"]["orders"]
            transactions_collection = client["dance_app"]["reward_transactions"]

            # Find orders that have cashback transactions but are not marked as rewards_generated
            pipeline = [
                {
                    "$match": {
                        "status": OrderStatusEnum.PAID.value,
                        "rewards_generated": {"$ne": True}
                    }
                },
                {
                    "$lookup": {
                        "from": "reward_transactions",
                        "let": {"order_id": {"$toString": "$_id"}},
                        "pipeline": [
                            {
                                "$match": {
                                    "$expr": {
                                        "$and": [
                                            {"$eq": ["$reference_id", "$$order_id"]},
                                            {"$eq": ["$source", RewardSourceEnum.CASHBACK.value]},
                                            {"$eq": ["$transaction_type", RewardTransactionTypeEnum.CREDIT.value]}
                                        ]
                                    }
                                }
                            }
                        ],
                        "as": "cashback_transactions"
                    }
                },
                {
                    "$match": {
                        "cashback_transactions": {"$ne": []}
                    }
                }
            ]

            inconsistent_orders = list(orders_collection.aggregate(pipeline))

            if not inconsistent_orders:
                return 0

            logger.info(f"Found {len(inconsistent_orders)} orders with cashback transactions but not marked as processed")

            cleaned_count = 0
            for order in inconsistent_orders:
                order_id = str(order["_id"])
                transactions = order.get("cashback_transactions", [])

                if transactions:
                    # Get the total cashback amount
                    total_cashback = sum(tx.get("amount", 0) for tx in transactions)

                    # Mark the order as processed with the total cashback amount
                    success = self._mark_order_rewards_generated(order_id, total_cashback)

                    if success:
                        cleaned_count += 1
                        logger.info(f"Cleaned up order {order_id} with total cashback ₹{total_cashback}")
                    else:
                        logger.error(f"Failed to clean up order {order_id}")

            return cleaned_count

        except Exception as e:
            logger.error(f"Error cleaning up inconsistent orders: {e}")
            return 0
            
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
