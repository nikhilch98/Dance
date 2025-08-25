"""Razorpay webhook and callback API routes."""

import logging
from typing import Optional

from fastapi import APIRouter, Query, HTTPException, Request, status

from app.database.orders import OrderOperations, WebhookOperations
from app.models.orders import (
    OrderStatusEnum,
    RazorpayWebhookRequest,
    WebhookResponse
)

logger = logging.getLogger(__name__)
router = APIRouter()


def map_razorpay_status_to_order_status(razorpay_status: str) -> OrderStatusEnum:
    """Map Razorpay payment status to our order status.
    
    Args:
        razorpay_status: Razorpay payment status
        
    Returns:
        OrderStatusEnum: Corresponding order status
    """
    status_mapping = {
        "paid": OrderStatusEnum.PAID,
        "created": OrderStatusEnum.CREATED,
        "attempted": OrderStatusEnum.CREATED,  # Keep as created if just attempted
        "cancelled": OrderStatusEnum.CANCELLED,
        "expired": OrderStatusEnum.EXPIRED,
        "failed": OrderStatusEnum.FAILED
    }
    
    return status_mapping.get(razorpay_status.lower(), OrderStatusEnum.FAILED)


@router.get("/webhook", response_model=WebhookResponse)
async def razorpay_webhook(
    request: Request,
    razorpay_payment_id: Optional[str] = Query(None),
    razorpay_payment_link_id: Optional[str] = Query(None),
    razorpay_payment_link_reference_id: Optional[str] = Query(None),
    razorpay_payment_link_status: Optional[str] = Query(None),
    razorpay_signature: Optional[str] = Query(None)
):
    """Handle Razorpay webhook callbacks.
    
    This endpoint:
    1. Logs all webhook data for audit purposes
    2. Finds the corresponding order by reference_id
    3. Updates the order status based on payment status
    4. Returns success response to Razorpay
    
    Query Parameters:
    - razorpay_payment_id: Razorpay payment ID
    - razorpay_payment_link_id: Razorpay payment link ID
    - razorpay_payment_link_reference_id: Our order ID
    - razorpay_payment_link_status: Payment status from Razorpay
    - razorpay_signature: Webhook signature for verification
    """
    try:
        logger.info(f"Received Razorpay webhook: payment_id={razorpay_payment_id}, "
                   f"link_id={razorpay_payment_link_id}, "
                   f"reference_id={razorpay_payment_link_reference_id}, "
                   f"status={razorpay_payment_link_status}")
        
        # 1. Get all query parameters and headers for logging
        raw_webhook_data = {
            "query_params": dict(request.query_params),
            "headers": dict(request.headers),
            "method": request.method,
            "url": str(request.url),
            "timestamp": str(request.headers.get("date", ""))
        }
        
        # 2. Log webhook to database for audit
        webhook_id = WebhookOperations.log_webhook(
            razorpay_payment_id=razorpay_payment_id,
            razorpay_payment_link_id=razorpay_payment_link_id,
            razorpay_payment_link_reference_id=razorpay_payment_link_reference_id,
            razorpay_payment_link_status=razorpay_payment_link_status,
            razorpay_signature=razorpay_signature,
            raw_webhook_data=raw_webhook_data
        )
        
        logger.info(f"Logged webhook with ID: {webhook_id}")
        
        order_updated = False
        processing_error = None
        
        try:
            # 3. Process the webhook if we have the necessary data
            if razorpay_payment_link_reference_id and razorpay_payment_link_status:
                # Find the order by reference_id (our order_id)
                order = OrderOperations.get_order_by_id(razorpay_payment_link_reference_id)
                
                if order:
                    logger.info(f"Found order {order['order_id']} for webhook processing")
                    
                    # Map Razorpay status to our order status
                    new_status = map_razorpay_status_to_order_status(razorpay_payment_link_status)
                    
                    # Prepare additional data to store with the order
                    additional_data = {}
                    if razorpay_payment_id:
                        # Update payment gateway details with payment ID
                        payment_gateway_details = order.get("payment_gateway_details", {})
                        payment_gateway_details["razorpay_payment_id"] = razorpay_payment_id
                        payment_gateway_details["webhook_status"] = razorpay_payment_link_status
                        payment_gateway_details["webhook_timestamp"] = raw_webhook_data["timestamp"]
                        additional_data["payment_gateway_details"] = payment_gateway_details
                    
                    # Update order status
                    success = OrderOperations.update_order_status(
                        order_id=order["order_id"],
                        status=new_status,
                        additional_data=additional_data
                    )
                    
                    if success:
                        order_updated = True
                        logger.info(f"Updated order {order['order_id']} status to {new_status.value}")
                    else:
                        processing_error = "Failed to update order status in database"
                        logger.error(f"Failed to update order {order['order_id']} status")
                
                else:
                    processing_error = f"Order not found with reference_id: {razorpay_payment_link_reference_id}"
                    logger.warning(processing_error)
            
            else:
                processing_error = "Missing required webhook parameters"
                logger.warning(f"Incomplete webhook data: reference_id={razorpay_payment_link_reference_id}, "
                              f"status={razorpay_payment_link_status}")
        
        except Exception as e:
            processing_error = f"Error processing webhook: {str(e)}"
            logger.error(processing_error)
        
        # 4. Update webhook processing status
        WebhookOperations.update_webhook_processing_status(
            webhook_id=webhook_id,
            processed=True,
            order_updated=order_updated,
            processing_error=processing_error
        )
        
        # 5. Return success response to Razorpay
        response_message = "Webhook processed successfully"
        if processing_error:
            response_message += f" with warnings: {processing_error}"
        
        return WebhookResponse(
            success=True,
            message=response_message,
            order_updated=order_updated
        )
        
    except Exception as e:
        logger.error(f"Critical error in webhook processing: {str(e)}")
        
        # Even if there's an error, we should return success to Razorpay
        # to prevent them from retrying the webhook
        return WebhookResponse(
            success=True,
            message=f"Webhook received but processing failed: {str(e)}",
            order_updated=False
        )