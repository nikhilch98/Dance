"""Database operations for rewards system."""

import uuid
from datetime import datetime
from typing import List, Dict, Any, Optional
from pymongo import DESCENDING
from pymongo.errors import PyMongoError

from ..config.settings import get_settings
from ..models.rewards import (
    RewardWallet, RewardTransaction, RewardRedemption,
    RewardSourceEnum, RewardTransactionTypeEnum, RewardTransactionStatusEnum
)
from utils.utils import get_mongo_client

import logging
logger = logging.getLogger(__name__)

settings = get_settings()


class RewardOperations:
    """Database operations for rewards system."""

    @staticmethod
    def get_or_create_wallet(user_id: str) -> Dict[str, Any]:
        """Get user's reward wallet or create if doesn't exist."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_wallets"]
            
            # Try to find existing wallet
            wallet = collection.find_one({"user_id": user_id})
            
            if not wallet:
                # Create new wallet
                wallet_data = {
                    "user_id": user_id,
                    "total_balance": 0.0,
                    "available_balance": 0.0,
                    "lifetime_earned": 0.0,
                    "lifetime_redeemed": 0.0,
                    "created_at": datetime.utcnow(),
                    "updated_at": datetime.utcnow()
                }
                result = collection.insert_one(wallet_data)
                wallet_data["_id"] = result.inserted_id
                logger.info(f"Created new reward wallet for user: {user_id}")
                return wallet_data
            
            return wallet
            
        except Exception as e:
            logger.error(f"Error getting/creating wallet for user {user_id}: {e}")
            raise

    @staticmethod
    def update_wallet_balance(user_id: str, amount: float, transaction_type: RewardTransactionTypeEnum) -> bool:
        """Update user's wallet balance."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_wallets"]
            
            # Determine update operations based on transaction type
            if transaction_type == RewardTransactionTypeEnum.CREDIT:
                update_ops = {
                    "$inc": {
                        "total_balance": amount,
                        "available_balance": amount,
                        "lifetime_earned": amount
                    },
                    "$set": {"updated_at": datetime.utcnow()}
                }
            else:  # DEBIT
                update_ops = {
                    "$inc": {
                        "available_balance": -amount,
                        "lifetime_redeemed": amount
                    },
                    "$set": {"updated_at": datetime.utcnow()}
                }
            
            result = collection.update_one(
                {"user_id": user_id},
                update_ops
            )
            
            if result.modified_count > 0:
                logger.info(f"Updated wallet balance for user {user_id}: {transaction_type.value} {amount}")
                return True
            else:
                logger.warning(f"No wallet found to update for user: {user_id}")
                return False
                
        except Exception as e:
            logger.error(f"Error updating wallet balance for user {user_id}: {e}")
            raise

    @staticmethod
    def create_transaction(
        user_id: str,
        transaction_type: RewardTransactionTypeEnum,
        amount: float,
        source: RewardSourceEnum,
        description: str,
        reference_id: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None
    ) -> str:
        """Create a new reward transaction with enhanced duplicate prevention."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_transactions"]

            # Enhanced duplicate prevention: Check for existing transaction with same parameters
            if reference_id and source:
                # For cashback transactions, be more strict about duplicates
                if source == RewardSourceEnum.CASHBACK:
                    existing_transaction = collection.find_one({
                        "reference_id": reference_id,
                        "source": source.value,
                        "user_id": user_id,
                        "transaction_type": transaction_type.value
                    })
                else:
                    # For other sources, allow multiple transactions with same reference
                    existing_transaction = collection.find_one({
                        "reference_id": reference_id,
                        "source": source.value,
                        "user_id": user_id,
                        "transaction_type": transaction_type.value,
                        "amount": amount  # Same amount to be more restrictive
                    })

                if existing_transaction:
                    logger.warning(f"Duplicate transaction prevented for reference_id {reference_id}, source {source.value}, user {user_id}, amount {amount}")
                    return existing_transaction["transaction_id"]

            transaction_id = str(uuid.uuid4())
            transaction_data = {
                "transaction_id": transaction_id,
                "user_id": user_id,
                "transaction_type": transaction_type.value,
                "amount": amount,
                "source": source.value,
                "status": RewardTransactionStatusEnum.COMPLETED.value,
                "description": description,
                "reference_id": reference_id,
                "metadata": metadata or {},
                "created_at": datetime.utcnow(),
                "processed_at": datetime.utcnow()
            }

            collection.insert_one(transaction_data)

            # Update wallet balance
            RewardOperations.update_wallet_balance(user_id, amount, transaction_type)

            logger.info(f"Created reward transaction {transaction_id} for user {user_id} - Amount: ₹{amount}, Source: {source.value}")
            return transaction_id

        except Exception as e:
            logger.error(f"Error creating reward transaction for user {user_id}: {e}")
            raise

    @staticmethod
    def get_user_transactions(
        user_id: str,
        page: int = 1,
        page_size: int = 20,
        transaction_type: Optional[RewardTransactionTypeEnum] = None
    ) -> Dict[str, Any]:
        """Get user's reward transactions with pagination."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_transactions"]
            
            # Build query
            query = {"user_id": user_id}
            if transaction_type:
                query["transaction_type"] = transaction_type.value
            
            # Calculate skip value
            skip = (page - 1) * page_size
            
            # Get total count
            total_count = collection.count_documents(query)
            
            # Get transactions
            transactions = list(
                collection.find(query)
                .sort("created_at", DESCENDING)
                .skip(skip)
                .limit(page_size)
            )
            
            return {
                "transactions": transactions,
                "total_count": total_count,
                "page": page,
                "page_size": page_size,
                "total_pages": (total_count + page_size - 1) // page_size
            }
            
        except Exception as e:
            logger.error(f"Error getting transactions for user {user_id}: {e}")
            raise

    @staticmethod
    def create_pending_redemption(
        user_id: str,
        order_id: str,
        workshop_uuid: str,
        points_redeemed: float,
        discount_amount: float,
        original_amount: float,
        final_amount: float
    ) -> str:
        """Create a pending reward redemption record without deducting balance."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            redemption_id = str(uuid.uuid4())
            redemption_data = {
                "redemption_id": redemption_id,
                "user_id": user_id,
                "order_id": order_id,
                "workshop_uuid": workshop_uuid,
                "points_redeemed": points_redeemed,
                "discount_amount": discount_amount,
                "original_amount": original_amount,
                "final_amount": final_amount,
                "status": RewardTransactionStatusEnum.PENDING.value,  # PENDING status
                "created_at": datetime.utcnow(),
                "processed_at": None  # Will be set when completed
            }
            
            collection.insert_one(redemption_data)
            logger.info(f"Created pending redemption {redemption_id} for order {order_id}")
            
            return redemption_id
            
        except Exception as e:
            logger.error(f"Error creating pending redemption: {e}")
            raise

    @staticmethod
    def create_redemption(
        user_id: str,
        order_id: str,
        workshop_uuid: str,
        points_redeemed: float,
        discount_amount: float,
        original_amount: float,
        final_amount: float
    ) -> str:
        """Create a completed reward redemption record with immediate balance deduction."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            redemption_id = str(uuid.uuid4())
            redemption_data = {
                "redemption_id": redemption_id,
                "user_id": user_id,
                "order_id": order_id,
                "workshop_uuid": workshop_uuid,
                "points_redeemed": points_redeemed,
                "discount_amount": discount_amount,
                "original_amount": original_amount,
                "final_amount": final_amount,
                "status": RewardTransactionStatusEnum.COMPLETED.value,
                "created_at": datetime.utcnow(),
                "processed_at": datetime.utcnow()
            }
            
            collection.insert_one(redemption_data)
            
            # Create corresponding debit transaction
            RewardOperations.create_transaction(
                user_id=user_id,
                transaction_type=RewardTransactionTypeEnum.DEBIT,
                amount=points_redeemed,
                source=RewardSourceEnum.CASHBACK,  # This represents redemption
                description=f"Redeemed for workshop booking - {workshop_uuid}",
                reference_id=order_id,
                metadata={
                    "redemption_id": redemption_id,
                    "workshop_uuid": workshop_uuid,
                    "discount_amount": discount_amount
                }
            )
            
            logger.info(f"Created redemption {redemption_id} for user {user_id}")
            return redemption_id
            
        except Exception as e:
            logger.error(f"Error creating redemption: {e}")
            raise

    @staticmethod
    def get_user_redemptions(user_id: str, page: int = 1, page_size: int = 20) -> Dict[str, Any]:
        """Get user's reward redemptions with pagination."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            # Calculate skip value
            skip = (page - 1) * page_size
            
            # Get total count
            total_count = collection.count_documents({"user_id": user_id})
            
            # Get redemptions
            redemptions = list(
                collection.find({"user_id": user_id})
                .sort("created_at", DESCENDING)
                .skip(skip)
                .limit(page_size)
            )
            
            return {
                "redemptions": redemptions,
                "total_count": total_count,
                "page": page,
                "page_size": page_size,
                "total_pages": (total_count + page_size - 1) // page_size
            }
            
        except Exception as e:
            logger.error(f"Error getting redemptions for user {user_id}: {e}")
            raise

    @staticmethod
    def get_user_balance(user_id: str) -> float:
        """Get user's available reward balance."""
        try:
            wallet = RewardOperations.get_or_create_wallet(user_id)
            return wallet.get("available_balance", 0.0)

        except Exception as e:
            logger.error(f"Error getting user balance for {user_id}: {e}")
            return 0.0

    @staticmethod
    def complete_pending_redemption(order_id: str) -> bool:
        """Complete a pending redemption after successful payment."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            # Find the pending redemption for this order
            redemption = collection.find_one({
                "order_id": order_id,
                "status": RewardTransactionStatusEnum.PENDING.value
            })
            
            if not redemption:
                logger.warning(f"No pending redemption found for order {order_id}")
                return False
            
            # Update redemption status to completed
            collection.update_one(
                {"order_id": order_id, "status": RewardTransactionStatusEnum.PENDING.value},
                {
                    "$set": {
                        "status": RewardTransactionStatusEnum.COMPLETED.value,
                        "processed_at": datetime.utcnow()
                    }
                }
            )
            
            # Now deduct from user's balance
            RewardOperations.create_transaction(
                user_id=redemption["user_id"],
                transaction_type=RewardTransactionTypeEnum.DEBIT,
                amount=redemption["points_redeemed"],
                source=RewardSourceEnum.CASHBACK,
                description=f"Redeemed for workshop booking - {redemption['workshop_uuid']}",
                reference_id=order_id,
                metadata={
                    "redemption_id": redemption["redemption_id"],
                    "workshop_uuid": redemption["workshop_uuid"],
                    "discount_amount": redemption["discount_amount"]
                }
            )
            
            logger.info(f"Completed pending redemption for order {order_id}: ₹{redemption['points_redeemed']} deducted")
            return True
            
        except Exception as e:
            logger.error(f"Error completing pending redemption for order {order_id}: {e}")
            return False

    @staticmethod
    def rollback_pending_redemption(order_id: str) -> bool:
        """Rollback/cancel a pending redemption."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            # Find the pending redemption for this order
            redemption = collection.find_one({
                "order_id": order_id,
                "status": RewardTransactionStatusEnum.PENDING.value
            })
            
            if not redemption:
                logger.warning(f"No pending redemption found for order {order_id}")
                return False
            
            # Update redemption status to cancelled
            collection.update_one(
                {"order_id": order_id, "status": RewardTransactionStatusEnum.PENDING.value},
                {
                    "$set": {
                        "status": RewardTransactionStatusEnum.CANCELLED.value,
                        "processed_at": datetime.utcnow()
                    }
                }
            )
            
            logger.info(f"Rolled back pending redemption for order {order_id}: ₹{redemption['points_redeemed']} reservation cancelled")
            return True
            
        except Exception as e:
            logger.error(f"Error rolling back pending redemption for order {order_id}: {e}")
            return False

    @staticmethod
    def get_available_balance_for_redemption(user_id: str) -> float:
        """Get user's available balance for redemption, excluding pending redemptions."""
        try:
            # Get base wallet balance
            base_balance = RewardOperations.get_user_balance(user_id)

            # Check for any recent pending redemptions (within last 10 minutes)
            # This prevents double-booking with rewards
            from datetime import datetime, timedelta
            cutoff_time = datetime.utcnow() - timedelta(minutes=10)

            client = get_mongo_client()
            redemptions_collection = client["dance_app"]["reward_redemptions"]

            # Find pending redemptions that might still be processing
            pending_redemptions = list(redemptions_collection.find({
                "user_id": user_id,
                "status": {"$in": ["pending", "completed"]},  # Include completed to be safe
                "created_at": {"$gte": cutoff_time}
            }))

            # Calculate total pending redemption amount
            total_pending = sum(redemption.get("points_redeemed", 0) for redemption in pending_redemptions)

            # Return available balance minus pending redemptions
            available_for_redemption = max(0, base_balance - total_pending)

            logger.debug(f"User {user_id}: Base balance ₹{base_balance}, Pending redemptions ₹{total_pending}, Available for redemption ₹{available_for_redemption}")

            return available_for_redemption

        except Exception as e:
            logger.error(f"Error getting available balance for redemption for {user_id}: {e}")
            return 0.0

    @staticmethod
    def validate_redemption(user_id: str, points_to_redeem: float) -> bool:
        """Validate if user can redeem the specified points."""
        try:
            wallet = RewardOperations.get_or_create_wallet(user_id)
            available_balance = wallet.get("available_balance", 0.0)

            return available_balance >= points_to_redeem

        except Exception as e:
            logger.error(f"Error validating redemption for user {user_id}: {e}")
            return False

    @staticmethod
    def get_redemption_cap() -> float:
        """Get the maximum points redeemable per workshop."""
        # Use configurable setting
        return getattr(settings, 'reward_redemption_cap_per_workshop', 50.0)

    @staticmethod
    def get_exchange_rate() -> float:
        """Get points to currency exchange rate."""
        # Use configurable setting
        return getattr(settings, 'reward_exchange_rate', 1.0)  # 1 point = 1 rupee

    @staticmethod
    def get_redemption_cap_percentage() -> float:
        """Get the maximum percentage of workshop cost that can be redeemed."""
        # Use configurable setting
        return getattr(settings, 'reward_redemption_cap_percentage', 10.0)  # 10%

    @staticmethod
    def award_welcome_bonus(user_id: str, amount: float = None) -> str:
        """Award welcome bonus to new user."""
        try:
            # Check if user already has a welcome bonus
            client = get_mongo_client()
            collection = client["dance_app"]["reward_transactions"]

            existing_welcome_bonus = collection.find_one({
                "user_id": user_id,
                "source": RewardSourceEnum.WELCOME_BONUS.value,
                "transaction_type": RewardTransactionTypeEnum.CREDIT.value,
                "status": RewardTransactionStatusEnum.COMPLETED.value
            })

            if existing_welcome_bonus:
                logger.info(f"Welcome bonus already exists for user {user_id}, skipping duplicate")
                return existing_welcome_bonus["transaction_id"]

            # Use configurable welcome bonus amount
            if amount is None:
                amount = getattr(settings, 'reward_welcome_bonus', 100.0)

            return RewardOperations.create_transaction(
                user_id=user_id,
                transaction_type=RewardTransactionTypeEnum.CREDIT,
                amount=amount,
                source=RewardSourceEnum.WELCOME_BONUS,
                description=f"Welcome bonus - {amount} points",
                metadata={"bonus_type": "welcome"}
            )
        except Exception as e:
            logger.error(f"Error awarding welcome bonus to user {user_id}: {e}")
            raise

    @staticmethod
    def calculate_total_savings(user_id: str) -> float:
        """Calculate total money saved through reward redemptions."""
        try:
            client = get_mongo_client()
            collection = client["dance_app"]["reward_redemptions"]
            
            pipeline = [
                {"$match": {"user_id": user_id, "status": RewardTransactionStatusEnum.COMPLETED.value}},
                {"$group": {"_id": None, "total_savings": {"$sum": "$discount_amount"}}}
            ]
            
            result = list(collection.aggregate(pipeline))
            return result[0]["total_savings"] if result else 0.0
            
        except Exception as e:
            logger.error(f"Error calculating total savings for user {user_id}: {e}")
            return 0.0
