"""Order and payment API routes."""

import logging
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.database.orders import OrderOperations, WebhookOperations
from app.database.workshops import DatabaseOperations as WorkshopOperations
from app.database.users import UserOperations
from app.models.orders import (
    CreatePaymentLinkRequest,
    CreatePaymentLinkResponse,
    UnifiedPaymentLinkResponse,
    ExistingPaymentResponse,
    OrderCreate,
    OrderResponse,
    OrderStatusEnum,
    UserOrdersResponse,
    WorkshopDetails,
    RazorpayWebhookRequest,
    WebhookResponse
)
from app.services.auth import verify_token
from app.services.razorpay_service import get_razorpay_service
from app.services.background_qr_service import get_background_qr_service, run_qr_generation_batch
from app.services.background_rewards_service import BackgroundRewardsService

logger = logging.getLogger(__name__)
router = APIRouter()


def extract_pricing_amount(pricing_info: str) -> int:
    """Extract amount in paise from pricing_info string.
    
    Args:
        pricing_info: String like "₹1,500" or "₹500" or "1500"
        
    Returns:
        Amount in paise (e.g., 150000 for ₹1,500)
    """
    if not pricing_info:
        raise ValueError("Pricing information not available")
    
    # Remove currency symbols and commas
    amount_str = pricing_info.replace("₹", "").replace(",", "").strip()
    
    try:
        # Convert to float first (in case of decimal values), then to int
        amount_rupees = float(amount_str)
        amount_paise = int(amount_rupees * 100)
        return amount_paise
    except ValueError:
        raise ValueError(f"Invalid pricing format: {pricing_info}")


def get_workshop_by_uuid(workshop_uuid: str) -> dict:
    """Get workshop details by UUID.
    
    Args:
        workshop_uuid: Workshop UUID
        
    Returns:
        Workshop document
        
    Raises:
        HTTPException: If workshop not found
    """
    from utils.utils import get_mongo_client
    
    client = get_mongo_client()
    workshop = client["discovery"]["workshops_v2"].find_one({"uuid": workshop_uuid})
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workshop with UUID {workshop_uuid} not found"
        )
    
    return workshop


def create_workshop_details(workshop: dict) -> WorkshopDetails:
    """Create WorkshopDetails from workshop document.
    
    Args:
        workshop: Workshop document from database
        
    Returns:
        WorkshopDetails object
    """
    from utils.utils import get_mongo_client
    
    client = get_mongo_client()
    
    # Get studio name
    studio = client["discovery"]["studios"].find_one({"studio_id": workshop["studio_id"]})
    studio_name = studio["studio_name"] if studio else "Unknown Studio"
    
    # Get artist names
    artist_names = []
    if workshop.get("artist_id_list"):
        artists = list(client["discovery"]["artists_v2"].find({
            "artist_id": {"$in": workshop["artist_id_list"]}
        }))
        artist_names = [artist["artist_name"] for artist in artists]
    
    # If no artists found, use the 'by' field
    if not artist_names and workshop.get("by"):
        artist_names = [workshop["by"]]
    
    # Extract date and time from time_details (using first time detail)
    date_str = "Date TBD"
    time_str = "Time TBD"
    
    if workshop.get("time_details") and len(workshop["time_details"]) > 0:
        time_detail = workshop["time_details"][0]
        if time_detail.get("day") and time_detail.get("month") and time_detail.get("year"):
            date_str = f"{time_detail['day']:02d}/{time_detail['month']:02d}/{time_detail['year']}"
        if time_detail.get("start_time"):
            end_time = time_detail.get("end_time", "")
            time_str = f"{time_detail['start_time']}"
            if end_time:
                time_str += f" - {end_time}"
    
    # Create workshop title
    title_parts = []
    if workshop.get("song"):
        title_parts.append(workshop["song"])
    if workshop.get("event_type"):
        title_parts.append(workshop["event_type"].title())
    if not title_parts:
        title_parts.append("Dance Workshop")
    
    title = " - ".join(title_parts)
    
    return WorkshopDetails(
        title=title,
        artist_names=artist_names,
        studio_name=studio_name,
        date=date_str,
        time=time_str,
        uuid=workshop["uuid"]
    )


@router.post("/create-payment-link", response_model=UnifiedPaymentLinkResponse)
async def create_payment_link(
    request: CreatePaymentLinkRequest,
    user_id: str = Depends(verify_token)
):
    """Create a payment link for a workshop.
    
    This endpoint:
    1. Validates the workshop exists and extracts pricing
    2. Checks for existing pending payment links (status=CREATED only)
    3. Creates a new order and Razorpay payment link
    4. Stores the order in database
    5. Returns payment link details
    
    Note: Users who have successfully paid (status=PAID) can make new bookings.
    Only pending payments (status=CREATED) are considered duplicates.
    """
    try:
        logger.info(f"Creating payment link for workshop {request.workshop_uuid}, user {user_id}")
        
        # 1. Get workshop details and validate
        workshop = get_workshop_by_uuid(request.workshop_uuid)
        
        # 2. Extract pricing information
        if not workshop.get("pricing_info"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Workshop pricing information not available"
            )
        
        try:
            amount_paise = extract_pricing_amount(workshop["pricing_info"])
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e)
            )
        
        # 3. Check for existing pending payment link
        existing_order = OrderOperations.get_active_order_for_user_workshop(
            user_id, request.workshop_uuid
        )
        
        # Determine intended final amount (after discount if any)
        intended_final_amount_paise = amount_paise
        rewards_redeemed_rupees = 0.0
        
        if request.discount_amount and request.discount_amount > 0:
            # Perform validation similar to below to compute final amount safely
            from app.database.rewards import RewardOperations
            from app.config.settings import get_settings as _get_settings
            _settings = _get_settings()
            discount_rupees = float(request.discount_amount)
            reward_balance = RewardOperations.get_user_balance(user_id)
            order_amount_rupees = amount_paise / 100.0
            redemption_cap_percentage = getattr(_settings, 'reward_redemption_cap_percentage', 10.0)
            max_discount_allowed = order_amount_rupees * (redemption_cap_percentage / 100.0)
            redemption_cap_per_workshop = getattr(_settings, 'reward_redemption_cap_per_workshop', 500.0)
            if discount_rupees > reward_balance:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient reward balance")
            if discount_rupees > max_discount_allowed:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of order amount (₹{order_amount_rupees:.0f})")
            if discount_rupees > redemption_cap_per_workshop:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Discount amount (₹{discount_rupees}) cannot exceed ₹{redemption_cap_per_workshop} per workshop")
            final_amount_rupees = order_amount_rupees - discount_rupees
            intended_final_amount_paise = int(final_amount_rupees * 100)
            rewards_redeemed_rupees = discount_rupees

        # If we have an existing pending order, decide whether to reuse or cancel
        if existing_order:
            existing_pg = existing_order.get("payment_gateway_details") or {}
            existing_amount_paise = (
                int(existing_order.get("final_amount_paid", 0) * 100)
                if existing_order.get("final_amount_paid") is not None
                else int(existing_pg.get("amount") or existing_order.get("amount", amount_paise))
            )
            if intended_final_amount_paise != existing_amount_paise:
                # Different amount requested → cancel old link and proceed to new order
                try:
                    rp = get_razorpay_service()
                    pl_id = existing_order.get("payment_link_id")
                    if pl_id:
                        rp.cancel_payment_link(pl_id)
                except Exception as e:
                    logger.warning(f"Failed to cancel existing payment link: {e}")
                # Mark old order cancelled and continue
                OrderOperations.update_order_status(
                    existing_order["order_id"],
                    OrderStatusEnum.CANCELLED,
                    additional_data={"cancellation_reason": "replaced_by_new_amount"}
                )
            else:
                # Same amount → reuse existing link
                logger.info(
                    f"Reusing pending payment link for user {user_id}, workshop {request.workshop_uuid} (same amount)"
                )
                workshop_details = create_workshop_details(workshop)
                return UnifiedPaymentLinkResponse(
                    is_existing=True,
                    message="Pending payment link found for this workshop",
                    order_id=existing_order["order_id"],
                    payment_link_url=existing_order.get("payment_link_url", ""),
                    payment_link_id=existing_order.get("payment_link_id"),
                    amount=existing_order.get("amount", amount_paise),
                    currency=existing_order.get("currency", "INR"),
                    expires_at=existing_order.get("expires_at"),
                    workshop_details=workshop_details
                )
        
        # 4. Handle reward redemption if provided
        final_amount_paise = intended_final_amount_paise
        
        if rewards_redeemed_rupees > 0:
            logger.info(f"Processing reward redemption: ₹{request.discount_amount} discount for user {user_id}")
            
            # Validate and process redemption using rewards service
            from app.database.rewards import RewardOperations
            from app.config.settings import get_settings
            
            settings = get_settings()
            
            # Convert discount amount to rupees if needed (ensure it's in rupees)
            discount_rupees = rewards_redeemed_rupees
            
            # Validate user has sufficient balance
            try:
                reward_balance = RewardOperations.get_user_balance(user_id)
                if reward_balance < discount_rupees:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Insufficient reward balance. Available: ₹{reward_balance}, Requested: ₹{discount_rupees}"
                    )
                
                # Calculate final amount after discount
                order_amount_rupees = amount_paise / 100.0
                
                # Validate against configurable redemption cap percentage
                redemption_cap_percentage = getattr(settings, 'reward_redemption_cap_percentage', 10.0)
                max_discount_allowed = order_amount_rupees * (redemption_cap_percentage / 100.0)
                
                if discount_rupees > max_discount_allowed:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of order amount (₹{order_amount_rupees:.0f})"
                    )
                
                # Validate against absolute redemption cap
                redemption_cap_per_workshop = getattr(settings, 'reward_redemption_cap_per_workshop', 500.0)
                if discount_rupees > redemption_cap_per_workshop:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Discount amount (₹{discount_rupees}) cannot exceed ₹{redemption_cap_per_workshop} per workshop"
                    )
                
                # Apply discount
                final_amount_rupees = order_amount_rupees - discount_rupees
                final_amount_paise = int(final_amount_rupees * 100)
                
                logger.info(f"Applied reward discount: ₹{discount_rupees} → Final amount: ₹{final_amount_rupees:.0f}")
                
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Error processing reward redemption: {e}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Failed to process reward redemption"
                )
        
        # 5. Get user details for payment link
        user = UserOperations.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # 6. Create workshop details object
        workshop_details = create_workshop_details(workshop)
        
        # 7. Create order in database with redemption info
        order_data = OrderCreate(
            user_id=user_id,
            workshop_uuid=request.workshop_uuid,
            workshop_details=workshop_details,
            amount=amount_paise,  # Original amount in paise
            currency="INR",
            rewards_redeemed=rewards_redeemed_rupees if rewards_redeemed_rupees > 0 else None,
            final_amount_paid=final_amount_rupees if rewards_redeemed_rupees > 0 else None
        )
        
        order_id = OrderOperations.create_order(order_data)
        logger.info(f"Created order {order_id} for user {user_id}")
        
        # 7. Create Razorpay payment link
        razorpay_service = get_razorpay_service()
        
        # Prepare user details for Razorpay
        user_name = user.get("name") or "Customer"
        user_email = f"{user['mobile_number']}@nachna.com"  # Placeholder email
        user_phone = f"+91{user['mobile_number']}"
        
        # Update workshop title to show discount if applied
        payment_title = workshop_details.title
        if rewards_redeemed_rupees > 0:
            payment_title += f" (₹{rewards_redeemed_rupees} reward discount applied)"
        
        try:
            razorpay_response = razorpay_service.create_order_payment_link(
                order_id=order_id,
                amount=final_amount_paise,  # Use final amount after discount
                user_name=user_name,
                user_email=user_email,
                user_phone=user_phone,
                workshop_title=payment_title,
                expire_by_mins=60  # 1 hour expiry
            )
            
            logger.info(f"Created Razorpay payment link {razorpay_response['id']} for order {order_id}")
            
        except Exception as e:
            logger.error(f"Failed to create Razorpay payment link for order {order_id}: {str(e)}")
            # Clean up the order if payment link creation fails
            OrderOperations.update_order_status(order_id, OrderStatusEnum.FAILED)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create payment link"
            )
        
        # 8. Update order with payment link details
        expires_at = datetime.fromtimestamp(razorpay_response["expire_by"])
        
        success = OrderOperations.update_order_payment_link(
            order_id=order_id,
            payment_link_id=razorpay_response["id"],
            payment_link_url=razorpay_response["short_url"],
            expires_at=expires_at,
            payment_gateway_details=razorpay_response
        )
        
        if not success:
            logger.error(f"Failed to update order {order_id} with payment link details")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save payment link details"
            )
        
        # 9. Return success response
        return UnifiedPaymentLinkResponse(
            is_existing=False,
            message="Payment link created successfully",
            order_id=order_id,
            payment_link_url=razorpay_response["short_url"],
            payment_link_id=razorpay_response["id"],
            amount=amount_paise,
            currency="INR",
            expires_at=expires_at,
            workshop_details=workshop_details
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error creating payment link: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )


@router.get("/{order_id}/status")
async def get_order_status(
    order_id: str,
    user_id: str = Depends(verify_token)
):
    """Get status of a specific order for the authenticated user.
    
    This endpoint is optimized for order status polling from the frontend.
    It only returns the order if it belongs to the authenticated user.
    
    Args:
        order_id: The order ID to check
        user_id: User ID from authentication token
        
    Returns:
        Order details with current status from internal database
    """
    try:
        logger.info(f"Getting order status for order {order_id}, user {user_id}")
        
        # Get the specific order
        order = OrderOperations.get_order_by_id(order_id)
        
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
        
        # Verify the order belongs to the authenticated user
        if order["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"  # Don't reveal it exists for security
            )
        
        # Return order details
        order_response = OrderResponse(
            order_id=order["order_id"],
            workshop_uuid=order["workshop_uuid"],
            workshop_details=WorkshopDetails(**order["workshop_details"]),
            amount=order["amount"],
            currency=order["currency"],
            status=OrderStatusEnum(order["status"]),
            payment_link_url=order.get("payment_link_url"),
            qr_code_data=order.get("qr_code_data"),
            qr_code_generated_at=order.get("qr_code_generated_at"),
            # Reward-related fields
            cashback_amount=order.get("cashback_amount"),
            rewards_redeemed=order.get("rewards_redeemed"),
            final_amount_paid=order.get("final_amount_paid"),
            created_at=order["created_at"],
            updated_at=order["updated_at"]
        )
        
        logger.info(f"Order {order_id} status: {order['status']}")
        return {
            "success": True,
            "order": order_response
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting order status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve order status"
        )


@router.get("/user", response_model=UserOrdersResponse)
async def get_user_orders(
    status: Optional[str] = Query(None, description="Comma-separated list of order statuses to filter by"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of orders to return"),
    offset: int = Query(0, ge=0, description="Number of orders to skip"),
    user_id: str = Depends(verify_token)
):
    """Get orders for the authenticated user.
    
    Query Parameters:
    - status: Optional comma-separated list of statuses (e.g., "paid,created")
    - limit: Maximum number of orders to return (1-100, default 20)
    - offset: Number of orders to skip for pagination (default 0)
    """
    try:
        logger.info(f"Getting orders for user {user_id}, status: {status}, limit: {limit}, offset: {offset}")
        
        # Parse status filter
        status_filter = None
        if status:
            status_list = [s.strip() for s in status.split(",")]
            # Validate statuses
            valid_statuses = [s.value for s in OrderStatusEnum]
            invalid_statuses = [s for s in status_list if s not in valid_statuses]
            if invalid_statuses:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid status values: {invalid_statuses}. Valid values: {valid_statuses}"
                )
            status_filter = status_list
        
        # Default behavior: exclude cancelled orders from regular list
        if status_filter is None:
            status_filter = [s.value for s in OrderStatusEnum if s != OrderStatusEnum.CANCELLED]

        # Get orders from database
        orders = OrderOperations.get_user_orders(
            user_id=user_id,
            status_filter=status_filter,
            limit=limit,
            offset=offset
        )
        
        # Get total count for pagination
        total_count = OrderOperations.get_user_orders_count(
            user_id=user_id,
            status_filter=status_filter
        )
        
        # Convert to response format
        order_responses = []
        for order in orders:
            order_response = OrderResponse(
                order_id=order["order_id"],
                workshop_uuid=order["workshop_uuid"],
                workshop_details=WorkshopDetails(**order["workshop_details"]),
                amount=order["amount"],
                currency=order["currency"],
                status=OrderStatusEnum(order["status"]),
                payment_link_url=order.get("payment_link_url"),
                qr_code_data=order.get("qr_code_data"),
                qr_code_generated_at=order.get("qr_code_generated_at"),
                # Reward-related fields
                cashback_amount=order.get("cashback_amount"),
                rewards_redeemed=order.get("rewards_redeemed"),
                final_amount_paid=order.get("final_amount_paid"),
                created_at=order["created_at"],
                updated_at=order["updated_at"]
            )
            order_responses.append(order_response)
        
        # Determine if there are more results
        has_more = (offset + limit) < total_count
        
        return UserOrdersResponse(
            success=True,
            orders=order_responses,
            total_count=total_count,
            has_more=has_more
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user orders: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve orders"
        )


@router.post("/qr-generation/trigger")
async def trigger_qr_generation(
    user_id: str = Depends(verify_token)
):
    """Manually trigger QR code generation for paid orders.
    
    This endpoint allows admins to manually trigger the QR generation process.
    Only admin users can access this endpoint.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        QR generation batch results
    """
    try:
        # Note: Add admin check if needed
        # For now, any authenticated user can trigger (adjust as needed)
        
        logger.info(f"Manual QR generation triggered by user {user_id}")
        
        # Run QR generation batch
        result = await run_qr_generation_batch()
        
        logger.info(f"QR generation batch result: {result}")
        
        return {
            "success": True,
            "message": "QR generation batch completed",
            "batch_result": result
        }
        
    except Exception as e:
        logger.error(f"Error triggering QR generation: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger QR generation"
        )


@router.get("/qr-generation/status")
async def get_qr_generation_status(
    user_id: str = Depends(verify_token)
):
    """Get QR generation service status.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        QR generation service status
    """
    try:
        qr_service = get_background_qr_service()
        status_info = qr_service.get_processing_status()
        
        # Get count of orders needing QR codes
        pending_orders = OrderOperations.get_paid_orders_without_qr(limit=1000)
        pending_count = len(pending_orders)
        
        return {
            "success": True,
            "service_status": status_info,
            "pending_qr_count": pending_count
        }
        
    except Exception as e:
        logger.error(f"Error getting QR generation status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get QR generation status"
        )


@router.post("/rewards-generation/trigger")
async def trigger_rewards_generation(
    user_id: str = Depends(verify_token)
):
    """Manually trigger rewards generation for paid orders.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        Trigger confirmation and processing status
    """
    try:
        logger.info(f"Manual rewards generation triggered by user {user_id}")
        
        # Create rewards service instance and trigger manual generation
        rewards_service = BackgroundRewardsService()
        result = await rewards_service.trigger_manual_rewards_generation()
        
        return {
            "success": True,
            "message": "Rewards generation triggered manually",
            "result": result
        }
        
    except Exception as e:
        logger.error(f"Error triggering rewards generation: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger rewards generation"
        )


@router.get("/rewards-generation/status")
async def get_rewards_generation_status(
    user_id: str = Depends(verify_token)
):
    """Get rewards generation service status.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        Rewards generation service status
    """
    try:
        rewards_service = BackgroundRewardsService()
        status_info = await rewards_service.get_rewards_generation_status()
        
        return {
            "success": True,
            "service_status": status_info
        }
        
    except Exception as e:
        logger.error(f"Error getting rewards generation status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get rewards generation status"
        )
