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
        max_discount_amount_percentage = request.workshop_amount * (redemption_cap_percentage / 100.0)
        max_redeemable_points_percentage = max_discount_amount_percentage / exchange_rate

        # Also consider the fixed redemption cap (maximum points per workshop)
        max_redeemable_points_fixed = redemption_cap

        # Use the more restrictive cap (whichever is smaller)
        max_redeemable_points = min(max_redeemable_points_percentage, max_redeemable_points_fixed)
        max_discount_amount = max_redeemable_points * exchange_rate

        # Consider user's available balance
        actual_max_redeemable = min(max_redeemable_points, available_balance)
        
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
            max_discount_amount=max_discount_amount,
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


@router.post("/admin/test-qr-logo")
async def test_qr_logo_generation(user_id: str = Depends(verify_token)):
    """Test endpoint to verify QR code logo generation is working."""
    try:
        from ..services.qr_service import get_qr_service

        qr_service = get_qr_service()

        # Test logo generation
        logo_test_result = qr_service.test_logo_generation()

        # Generate a test QR code with sample data
        test_qr_data = qr_service.generate_order_qr_code(
            order_id="test_order_123",
            workshop_title="Test Workshop",
            amount=150000,  # ₹1,500 in paise
            user_name="Test User",
            user_phone="9999999999",
            workshop_uuid="test-workshop-uuid",
            artist_names=["Test Artist"],
            studio_name="Test Studio",
            workshop_date="25/12/2024",
            workshop_time="10:00 AM - 12:00 PM",
            payment_gateway_details={"payment_id": "test_payment_123"}
        )

        return {
            "success": True,
            "logo_test_passed": logo_test_result,
            "qr_code_generated": test_qr_data is not None and len(test_qr_data) > 100,
            "qr_code_length": len(test_qr_data) if test_qr_data else 0,
            "logo_size_ratio": qr_service.logo_size_ratio,
            "error_correction": "High (for logo embedding)",
            "message": "QR logo generation test completed"
        }

    except Exception as e:
        logger.error(f"Error testing QR logo generation: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to test QR logo generation: {str(e)}")


@router.post("/admin/regenerate-qr-codes")
async def regenerate_qr_codes(
    mode: str = "regenerate",
    limit: Optional[int] = None,
    user_id: str = Depends(verify_token)
):
    """Regenerate QR codes for existing orders with the updated logo.

    Args:
        mode: "regenerate" for existing QR codes, "missing" for orders without QR codes
        limit: Optional limit on number of orders to process
    """
    try:
        logger.info(f"QR code regeneration requested by user {user_id}, mode: {mode}, limit: {limit}")

        # Import the regenerator class
        from app.database.orders import OrderOperations
        from app.database.users import UserOperations
        from app.services.qr_service import get_qr_service
        from app.models.orders import OrderStatusEnum
        from utils.utils import get_mongo_client
        import asyncio

        class QuickQRRegenerator:
            """Quick QR regeneration service for API use."""

            def __init__(self):
                self.qr_service = get_qr_service()
                self.client = get_mongo_client()
                self.orders_collection = self.client["dance_app"]["orders"]

            def get_orders_with_qr_codes(self, limit: Optional[int] = None):
                query = {
                    "status": OrderStatusEnum.PAID.value,
                    "qr_codes_data": {"$exists": True, "$ne": None, "$ne": {}}
                }
                return list(self.orders_collection.find(query).limit(limit) if limit else self.orders_collection.find(query))

            def get_orders_without_qr_codes(self, limit: Optional[int] = None):
                query = {
                    "status": OrderStatusEnum.PAID.value,
                    "$or": [
                        {"qr_codes_data": {"$exists": False}},
                        {"qr_codes_data": None},
                        {"qr_codes_data": {"$eq": {}}}
                    ]
                }
                return list(self.orders_collection.find(query).limit(limit) if limit else self.orders_collection.find(query))

            async def regenerate_qr_for_order(self, order_doc: dict) -> dict:
                try:
                    order_id = order_doc['order_id']
                    user_id = order_doc['user_id']
                    workshop_details = order_doc['workshop_details']
                    amount = order_doc['amount']
                    payment_gateway_details = order_doc.get('payment_gateway_details', {})

                    # Get user details
                    user_data = UserOperations.get_user_by_id(user_id)
                    if not user_data:
                        return {"order_id": order_id, "success": False, "error": "User not found"}

                    user_name = user_data.get('name', 'Unknown User')
                    user_phone = user_data.get('phone', 'Unknown Phone')

                    # Extract workshop details
                    workshop_title = workshop_details.get('title', 'Unknown Workshop')
                    artist_names = workshop_details.get('artist_names', [])
                    studio_name = workshop_details.get('studio_name', 'Unknown Studio')
                    workshop_date = workshop_details.get('date', 'Unknown Date')
                    workshop_time = workshop_details.get('time', 'Unknown Time')
                    # Handle both single workshop and bundle orders
                    workshop_uuids = order_doc.get('workshop_uuids', [])
                    if not workshop_uuids and order_doc.get('workshop_uuid'):
                        # Backward compatibility for old single workshop orders
                        workshop_uuids = [order_doc['workshop_uuid']]

                    workshop_uuid = workshop_uuids[0] if workshop_uuids else 'UNKNOWN'

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

                    # Update order with new QR code data (convert to qr_codes_data format)
                    success = OrderOperations.update_order_qr_codes(order_id, {"default": qr_code_data})

                    return {
                        "order_id": order_id,
                        "success": success,
                        "qr_code_length": len(qr_code_data) if success else 0
                    }

                except Exception as e:
                    return {
                        "order_id": order_doc.get('order_id', 'unknown'),
                        "success": False,
                        "error": str(e)
                    }

        regenerator = QuickQRRegenerator()

        if mode == "regenerate":
            orders = regenerator.get_orders_with_qr_codes(limit)
            operation = "regeneration"
        elif mode == "missing":
            orders = regenerator.get_orders_without_qr_codes(limit)
            operation = "generation for missing"
        else:
            raise HTTPException(status_code=400, detail="Invalid mode. Use 'regenerate' or 'missing'")

        if not orders:
            return {
                "success": True,
                "message": f"No orders found for {operation}",
                "total_orders": 0,
                "processed": 0,
                "successful": 0,
                "failed": 0
            }

        logger.info(f"Starting {operation} of {len(orders)} QR codes...")

        # Process in smaller batches for API (limit concurrency)
        batch_size = 5  # Smaller batch for API to avoid timeouts
        processed = 0
        successful = 0
        failed = 0

        for i in range(0, len(orders), batch_size):
            batch = orders[i:i + batch_size]

            # Process batch concurrently
            tasks = [regenerator.regenerate_qr_for_order(order) for order in batch]
            batch_results = await asyncio.gather(*tasks, return_exceptions=True)

            # Process results
            for result in batch_results:
                processed += 1
                if isinstance(result, Exception):
                    failed += 1
                    logger.error(f"Exception in batch processing: {result}")
                elif result.get("success"):
                    successful += 1
                else:
                    failed += 1

        result = {
            "success": True,
            "message": f"QR code {operation} completed",
            "total_orders": len(orders),
            "processed": processed,
            "successful": successful,
            "failed": failed,
            "success_rate": round((successful / processed * 100), 2) if processed > 0 else 0
        }

        logger.info(f"QR code {operation} completed: {successful}/{processed} successful")
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in QR code regeneration API: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to regenerate QR codes: {str(e)}")


@router.get("/admin/qr-statistics")
async def get_qr_statistics(user_id: str = Depends(verify_token)):
    """Get QR code statistics for the system."""
    try:
        from app.models.orders import OrderStatusEnum
        from utils.utils import get_mongo_client

        client = get_mongo_client()
        orders_collection = client["dance_app"]["orders"]

        # Total paid orders
        total_paid = orders_collection.count_documents({
            "status": OrderStatusEnum.PAID.value
        })

        # Orders with QR codes
        with_qr = orders_collection.count_documents({
            "status": OrderStatusEnum.PAID.value,
            "qr_codes_data": {"$exists": True, "$ne": None, "$ne": {}}
        })

        # Orders without QR codes
        without_qr = orders_collection.count_documents({
            "status": OrderStatusEnum.PAID.value,
            "$or": [
                {"qr_codes_data": {"$exists": False}},
                {"qr_codes_data": None},
                {"qr_codes_data": {"$eq": {}}}
            ]
        })

        return {
            "success": True,
            "total_paid_orders": total_paid,
            "orders_with_qr_codes": with_qr,
            "orders_without_qr_codes": without_qr,
            "qr_coverage_percentage": round((with_qr / total_paid * 100), 2) if total_paid > 0 else 0,
            "needs_regeneration": with_qr,  # All existing QR codes might need regeneration
            "needs_generation": without_qr
        }

    except Exception as e:
        logger.error(f"Error getting QR statistics: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get QR statistics: {str(e)}")
