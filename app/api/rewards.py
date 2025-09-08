"""Rewards system API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
import logging

from ..models.rewards import (
    RewardBalanceResponse,
    RewardTransactionListResponse,
    RewardTransactionResponse,
    RewardSummaryResponse,
    RedemptionCalculationRequest,
    RedemptionCalculationResponse,
    RewardRedemptionRequest,
    RewardRedemptionResponse,
    WorkshopRedemptionInfo,
    RewardTransactionTypeEnum
)
from ..database.rewards import RewardOperations
from ..services.auth import verify_token
from ..config.settings import get_settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/balance", response_model=RewardBalanceResponse)
async def get_reward_balance(user_id: str = Depends(verify_token)):
    """Get user's reward balance information."""
    try:
        wallet = RewardOperations.get_or_create_wallet(user_id)
        
        return RewardBalanceResponse(
            user_id=user_id,
            total_balance=wallet.get("total_balance", 0.0),
            available_balance=wallet.get("available_balance", 0.0),
            lifetime_earned=wallet.get("lifetime_earned", 0.0),
            lifetime_redeemed=wallet.get("lifetime_redeemed", 0.0),
            redemption_cap_per_workshop=RewardOperations.get_redemption_cap()
        )
        
    except Exception as e:
        logger.error(f"Error getting reward balance for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get reward balance")


@router.get("/transactions", response_model=RewardTransactionListResponse)
async def get_reward_transactions(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    transaction_type: Optional[RewardTransactionTypeEnum] = Query(None, description="Filter by transaction type"),
    user_id: str = Depends(verify_token)
):
    """Get user's reward transactions with pagination."""
    try:
        result = RewardOperations.get_user_transactions(
            user_id=user_id,
            page=page,
            page_size=page_size,
            transaction_type=transaction_type
        )
        
        transactions = [
            RewardTransactionResponse(
                transaction_id=t["transaction_id"],
                transaction_type=RewardTransactionTypeEnum(t["transaction_type"]),
                amount=t["amount"],
                source=t["source"],
                status=t["status"],
                description=t["description"],
                reference_id=t.get("reference_id"),
                created_at=t["created_at"],
                processed_at=t.get("processed_at")
            )
            for t in result["transactions"]
        ]
        
        return RewardTransactionListResponse(
            transactions=transactions,
            total_count=result["total_count"],
            page=result["page"],
            page_size=result["page_size"]
        )
        
    except Exception as e:
        logger.error(f"Error getting reward transactions for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get reward transactions")


@router.get("/summary", response_model=RewardSummaryResponse)
async def get_reward_summary(user_id: str = Depends(verify_token)):
    """Get comprehensive reward summary for rewards center."""
    try:
        
        # Get balance
        wallet = RewardOperations.get_or_create_wallet(user_id)
        balance = RewardBalanceResponse(
            user_id=user_id,
            total_balance=wallet.get("total_balance", 0.0),
            available_balance=wallet.get("available_balance", 0.0),
            lifetime_earned=wallet.get("lifetime_earned", 0.0),
            lifetime_redeemed=wallet.get("lifetime_redeemed", 0.0),
            redemption_cap_per_workshop=RewardOperations.get_redemption_cap()
        )
        
        # Get recent transactions (last 5)
        transactions_result = RewardOperations.get_user_transactions(
            user_id=user_id,
            page=1,
            page_size=5
        )
        
        recent_transactions = [
            RewardTransactionResponse(
                transaction_id=t["transaction_id"],
                transaction_type=RewardTransactionTypeEnum(t["transaction_type"]),
                amount=t["amount"],
                source=t["source"],
                status=t["status"],
                description=t["description"],
                reference_id=t.get("reference_id"),
                created_at=t["created_at"],
                processed_at=t.get("processed_at")
            )
            for t in transactions_result["transactions"]
        ]
        
        # Get total savings and redemption history count
        total_savings = RewardOperations.calculate_total_savings(user_id)
        redemption_history_result = RewardOperations.get_user_redemptions(user_id, page=1, page_size=1)
        
        return RewardSummaryResponse(
            balance=balance,
            recent_transactions=recent_transactions,
            total_savings=total_savings,
            redemption_history_count=redemption_history_result["total_count"]
        )
        
    except Exception as e:
        logger.error(f"Error getting reward summary for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get reward summary")


@router.post("/calculate-redemption", response_model=RedemptionCalculationResponse)
async def calculate_redemption(
    request: RedemptionCalculationRequest,
    user_id: str = Depends(verify_token)
):
    """Calculate available redemption for a workshop."""
    try:
        wallet = RewardOperations.get_or_create_wallet(user_id)
        
        available_balance = wallet.get("available_balance", 0.0)
        redemption_cap = RewardOperations.get_redemption_cap()
        exchange_rate = RewardOperations.get_exchange_rate()
        redemption_cap_percentage = RewardOperations.get_redemption_cap_percentage()
        
        # Calculate maximum redeemable based on workshop amount (configurable percentage cap)
        max_discount_amount = request.workshop_amount * (redemption_cap_percentage / 100.0)
        max_redeemable_points = max_discount_amount / exchange_rate
        
        # Consider user's available balance
        actual_max_redeemable = min(max_redeemable_points, available_balance)
        actual_max_discount = actual_max_redeemable * exchange_rate
        
        # Recommend full available amount up to cap
        recommended_redemption = actual_max_redeemable
        
        can_redeem = available_balance > 0 and actual_max_redeemable > 0
        message = None
        
        if not can_redeem:
            if available_balance <= 0:
                message = "No reward points available for redemption"
            else:
                message = f"Workshop amount too low for redemption (minimum required: ₹{redemption_cap_percentage}% of workshop cost)"
        
        workshop_info = WorkshopRedemptionInfo(
            workshop_uuid=request.workshop_uuid,
            workshop_title="Workshop Booking",  # This could be fetched from workshop data
            original_amount=request.workshop_amount,
            max_redeemable_points=actual_max_redeemable,
            max_discount_amount=actual_max_discount,
            user_available_balance=available_balance,
            recommended_redemption=recommended_redemption
        )
        
        return RedemptionCalculationResponse(
            workshop_info=workshop_info,
            exchange_rate=exchange_rate,
            can_redeem=can_redeem,
            message=message
        )
        
    except Exception as e:
        logger.error(f"Error calculating redemption for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to calculate redemption")


@router.post("/redeem", response_model=RewardRedemptionResponse)
async def redeem_rewards(
    request: RewardRedemptionRequest,
    user_id: str = Depends(verify_token)
):
    """Redeem reward points for workshop booking discount."""
    try:
        
        # Validate redemption amount is positive
        if request.points_to_redeem <= 0:
            raise HTTPException(status_code=400, detail="Points to redeem must be positive")
        
        # Validate user has sufficient balance
        if not RewardOperations.validate_redemption(user_id, request.points_to_redeem):
            wallet = RewardOperations.get_or_create_wallet(user_id)
            available_balance = wallet.get("available_balance", 0.0)
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient reward points. Available: ₹{available_balance}, Requested: ₹{request.points_to_redeem}"
            )
        
        # Get configurable settings
        redemption_cap = RewardOperations.get_redemption_cap()
        exchange_rate = RewardOperations.get_exchange_rate()
        redemption_cap_percentage = RewardOperations.get_redemption_cap_percentage()
        
        # Validate against absolute cap (e.g., ₹500 max per workshop)
        if request.points_to_redeem > redemption_cap:
            raise HTTPException(
                status_code=400, 
                detail=f"Cannot redeem more than ₹{redemption_cap} per workshop"
            )
        
        # Validate against workshop amount cap (configurable percentage max redemption)
        max_discount_allowed = request.order_amount * (redemption_cap_percentage / 100.0)
        discount_amount = request.points_to_redeem * exchange_rate
        
        if discount_amount > max_discount_allowed:
            raise HTTPException(
                status_code=400, 
                detail=f"Cannot redeem more than {redemption_cap_percentage}% of workshop cost (₹{max_discount_allowed:.0f})"
            )
        
        # Calculate final amount and savings
        final_amount = max(0, request.order_amount - discount_amount)
        savings_percentage = (discount_amount / request.order_amount) * 100 if request.order_amount > 0 else 0
        
        # Generate redemption ID (will be used when creating actual order)
        import uuid
        redemption_id = str(uuid.uuid4())
        
        logger.info(f"Calculated redemption for user {user_id}: {request.points_to_redeem} points = ₹{discount_amount} discount (saving {savings_percentage:.1f}%)")
        
        return RewardRedemptionResponse(
            redemption_id=redemption_id,
            points_redeemed=request.points_to_redeem,
            discount_amount=discount_amount,
            original_amount=request.order_amount,
            final_amount=final_amount,
            savings_percentage=round(savings_percentage, 2),
            status="pending"  # Will be completed when order is created
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error redeeming rewards for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to process reward redemption")


@router.get("/redemptions")
async def get_redemption_history(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    user_id: str = Depends(verify_token)
):
    """Get user's reward redemption history."""
    try:
        result = RewardOperations.get_user_redemptions(
            user_id=user_id,
            page=page,
            page_size=page_size
        )
        
        return {
            "redemptions": result["redemptions"],
            "total_count": result["total_count"],
            "page": result["page"],
            "page_size": result["page_size"],
            "total_pages": result["total_pages"]
        }
        
    except Exception as e:
        logger.error(f"Error getting redemption history for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get redemption history")


@router.post("/admin/trigger-rewards-generation")
async def trigger_rewards_generation(user_id: str = Depends(verify_token)):
    """Manually trigger rewards generation for testing purposes with enhanced duplicate prevention."""
    try:
        from ..services.background_rewards_service import BackgroundRewardsService

        logger.info(f"Manual rewards generation triggered by user {user_id}")
        rewards_service = BackgroundRewardsService()
        result = await rewards_service.trigger_manual_rewards_generation()

        logger.info(f"Manual rewards generation completed: {result}")
        return result

    except Exception as e:
        logger.error(f"Error triggering manual rewards generation by user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to trigger rewards generation")


@router.get("/admin/debug-rewards-pending")
async def debug_pending_rewards(user_id: str = Depends(verify_token)):
    """Debug endpoint to see pending orders that need rewards generation with duplicate prevention info."""
    try:
        from ..services.background_rewards_service import BackgroundRewardsService

        rewards_service = BackgroundRewardsService()

        # Get orders before filtering (for comparison)
        from utils.utils import get_mongo_client
        from app.models.orders import OrderStatusEnum
        client = get_mongo_client()
        orders_collection = client["dance_app"]["orders"]

        raw_orders = list(orders_collection.find({
            "status": OrderStatusEnum.PAID.value,
            "rewards_generated": {"$ne": True}
        }).limit(50))

        # Get filtered orders (after duplicate prevention)
        filtered_orders = rewards_service._get_paid_orders_without_rewards()

        # Check for inconsistent orders
        inconsistent_count = rewards_service._cleanup_inconsistent_orders()

        # Get detailed info about each filtered order
        detailed_orders = []
        for order in filtered_orders[:10]:  # Limit to first 10 for readability
            detailed_orders.append({
                "order_id": order.get("order_id", str(order.get("_id", "unknown"))),
                "user_id": order.get("user_id"),
                "amount": order.get("amount"),
                "final_amount_paid": order.get("final_amount_paid"),
                "rewards_redeemed": order.get("rewards_redeemed"),
                "rewards_generated": order.get("rewards_generated", False),
                "status": order.get("status")
            })

        return {
            "success": True,
            "raw_pending_count": len(raw_orders),
            "filtered_pending_count": len(filtered_orders),
            "inconsistent_orders_cleaned": inconsistent_count,
            "duplicate_prevention_active": True,
            "pending_orders": detailed_orders,
            "cashback_percentage": rewards_service.settings.reward_cashback_percentage,
            "message": f"Enhanced duplicate prevention active. Found {len(raw_orders)} raw orders, {len(filtered_orders)} after filtering duplicates."
        }

    except Exception as e:
        logger.error(f"Error getting debug rewards info: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get debug rewards info: {str(e)}")
