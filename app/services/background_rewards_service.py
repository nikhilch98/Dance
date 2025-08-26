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

logger = logging.getLogger(__name__)

class BackgroundRewardsService:
    """Service for generating rewards for paid orders in the background."""
    
    def __init__(self):
        self.order_operations = OrderOperations()
        self.reward_operations = RewardOperations()
        self.is_running = False
        
    async def start_rewards_generation_service(self):
        """Start the background rewards generation service."""
        if self.is_running:
            logger.info("Background rewards generation service is already running")
            return
            
        self.is_running = True
        logger.info("Starting background rewards generation service...")
        
        try:
            while self.is_running:
                await self._process_rewards_batch()
                # Wait 30 seconds before next batch
                await asyncio.sleep(30)
        except asyncio.CancelledError:
            logger.info("Background rewards generation service cancelled")
        except Exception as e:
            logger.error(f"Critical error in rewards generation service: {e}")
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
            
            if not orders:
                logger.debug("No orders found requiring rewards generation")
                return
                
            logger.info(f"Processing {len(orders)} orders for rewards generation")
            
            for order in orders:
                try:
                    self._generate_rewards_for_order(order)
                    logger.info(f"Successfully generated rewards for order {order['order_id']}")
                except Exception as e:
                    logger.error(f"Failed to generate rewards for order {order['order_id']}: {e}")
                    
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
            
    def _generate_rewards_for_order(self, order: dict):
        """Generate cashback rewards for a specific order."""
        try:
            user_id = str(order["user_id"])
            order_id = str(order["_id"])
            order_amount = float(order.get("amount", 0))
            
            # Skip if amount is 0 or invalid
            if order_amount <= 0:
                logger.warning(f"Skipping rewards for order {order_id} - invalid amount: {order_amount}")
                return
                
            # Calculate 15% cashback with proper rounding
            cashback_amount = self._calculate_cashback(order_amount)
            
            if cashback_amount <= 0:
                logger.warning(f"Skipping rewards for order {order_id} - no cashback calculated")
                return
                
            # Ensure user has a reward wallet and create cashback transaction
            # The create_transaction method automatically updates the wallet balance
            transaction_id = self.reward_operations.create_transaction(
                user_id=user_id,
                transaction_type=RewardTransactionTypeEnum.CREDIT,
                amount=cashback_amount,
                source=RewardSourceEnum.CASHBACK,
                description=f"15% cashback for workshop booking (Order: {order.get('order_id', order_id)})",
                reference_id=order_id
            )
            
            # Mark order as having rewards generated
            self._mark_order_rewards_generated(order_id, cashback_amount)
            
            logger.info(f"Generated ₹{cashback_amount} cashback for order {order_id} (user: {user_id})")
            
        except Exception as e:
            logger.error(f"Error generating rewards for order {order.get('_id')}: {e}")
            raise
            
    def _calculate_cashback(self, order_amount: float) -> float:
        """Calculate 15% cashback with proper rounding."""
        try:
            # Calculate 15% cashback
            cashback = order_amount * 0.15
            
            # Round to nearest integer using standard rounding
            # 15.13 → 15, 15.5 → 16, 15.76 → 16
            rounded_cashback = round(cashback)
            
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
                "last_check": datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error(f"Error getting rewards generation status: {e}")
            return {
                "service_running": self.is_running,
                "pending_orders_count": 0,
                "last_check": datetime.utcnow().isoformat(),
                "error": str(e)
            }
