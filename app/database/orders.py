"""Order database operations."""

import secrets
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from bson import ObjectId

from utils.utils import get_mongo_client
from app.models.orders import (
    Order,
    OrderCreate,
    OrderStatusEnum,
    WebhookLog,
    WorkshopDetails
)


class OrderOperations:
    """Database operations for order management."""
    
    @staticmethod
    def generate_order_id() -> str:
        """Generate a unique order ID."""
        return f"ord_{secrets.token_hex(16)}"
    
    @staticmethod
    def generate_webhook_id() -> str:
        """Generate a unique webhook ID."""
        return f"whk_{secrets.token_hex(16)}"
    
    @staticmethod
    def create_order(order_data: OrderCreate) -> str:
        """Create a new order in the database.
        
        Args:
            order_data: Order creation data
            
        Returns:
            order_id: Generated order ID
        """
        client = get_mongo_client()
        
        order_id = OrderOperations.generate_order_id()
        now = datetime.utcnow()
        
        order_doc = {
            "order_id": order_id,
            "user_id": order_data.user_id,
            "workshop_uuid": order_data.workshop_uuid,
            "workshop_details": order_data.workshop_details.dict(),
            "amount": order_data.amount,
            "currency": order_data.currency,
            "status": OrderStatusEnum.CREATED.value,
            "payment_gateway": order_data.payment_gateway.value,
            "payment_link_id": None,
            "payment_link_url": None,
            "expires_at": None,
            "payment_gateway_details": None,
            "created_at": now,
            "updated_at": now
        }
        
        result = client["dance_app"]["orders"].insert_one(order_doc)
        return order_id
    
    @staticmethod
    def get_order_by_id(order_id: str) -> Optional[Dict[str, Any]]:
        """Get order by order_id.
        
        Args:
            order_id: Order identifier
            
        Returns:
            Order document or None
        """
        client = get_mongo_client()
        return client["dance_app"]["orders"].find_one({"order_id": order_id})
    
    @staticmethod
    def get_active_order_for_user_workshop(user_id: str, workshop_uuid: str) -> Optional[Dict[str, Any]]:
        """Get active order for user and workshop combination.
        
        Args:
            user_id: User identifier
            workshop_uuid: Workshop UUID
            
        Returns:
            Active order document or None
        """
        client = get_mongo_client()
        
        # Look for orders that are not expired/failed/cancelled
        active_statuses = [
            OrderStatusEnum.CREATED.value,
            OrderStatusEnum.PAID.value
        ]
        
        order = client["dance_app"]["orders"].find_one({
            "user_id": user_id,
            "workshop_uuid": workshop_uuid,
            "status": {"$in": active_statuses}
        }, sort=[("created_at", -1)])  # Get the most recent one
        
        # Check if the order is expired
        if order and order.get("expires_at"):
            if datetime.utcnow() > order["expires_at"]:
                # Mark as expired
                OrderOperations.update_order_status(order["order_id"], OrderStatusEnum.EXPIRED)
                return None
        
        return order
    
    @staticmethod
    def update_order_payment_link(
        order_id: str,
        payment_link_id: str,
        payment_link_url: str,
        expires_at: datetime,
        payment_gateway_details: Dict[str, Any]
    ) -> bool:
        """Update order with payment link details.
        
        Args:
            order_id: Order identifier
            payment_link_id: Razorpay payment link ID
            payment_link_url: Payment link URL
            expires_at: Link expiration time
            payment_gateway_details: Complete gateway response
            
        Returns:
            Success status
        """
        client = get_mongo_client()
        
        update_data = {
            "payment_link_id": payment_link_id,
            "payment_link_url": payment_link_url,
            "expires_at": expires_at,
            "payment_gateway_details": payment_gateway_details,
            "updated_at": datetime.utcnow()
        }
        
        result = client["dance_app"]["orders"].update_one(
            {"order_id": order_id},
            {"$set": update_data}
        )
        return result.modified_count > 0
    
    @staticmethod
    def update_order_status(order_id: str, status: OrderStatusEnum, additional_data: Optional[Dict[str, Any]] = None) -> bool:
        """Update order status.
        
        Args:
            order_id: Order identifier
            status: New status
            additional_data: Additional data to update
            
        Returns:
            Success status
        """
        client = get_mongo_client()
        
        update_data = {
            "status": status.value,
            "updated_at": datetime.utcnow()
        }
        
        if additional_data:
            update_data.update(additional_data)
        
        result = client["dance_app"]["orders"].update_one(
            {"order_id": order_id},
            {"$set": update_data}
        )
        return result.modified_count > 0
    
    @staticmethod
    def get_user_orders(
        user_id: str,
        status_filter: Optional[List[str]] = None,
        limit: int = 20,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get orders for a specific user.
        
        Args:
            user_id: User identifier
            status_filter: Optional list of statuses to filter by
            limit: Maximum number of orders to return
            offset: Number of orders to skip
            
        Returns:
            List of order documents
        """
        client = get_mongo_client()
        
        query = {"user_id": user_id}
        if status_filter:
            query["status"] = {"$in": status_filter}
        
        orders = list(client["dance_app"]["orders"]
                     .find(query)
                     .sort("created_at", -1)
                     .skip(offset)
                     .limit(limit))
        
        return orders
    
    @staticmethod
    def get_user_orders_count(user_id: str, status_filter: Optional[List[str]] = None) -> int:
        """Get total count of orders for a user.
        
        Args:
            user_id: User identifier
            status_filter: Optional list of statuses to filter by
            
        Returns:
            Total count of orders
        """
        client = get_mongo_client()
        
        query = {"user_id": user_id}
        if status_filter:
            query["status"] = {"$in": status_filter}
        
        return client["dance_app"]["orders"].count_documents(query)


class WebhookOperations:
    """Database operations for webhook log management."""
    
    @staticmethod
    def log_webhook(
        razorpay_payment_id: Optional[str],
        razorpay_payment_link_id: Optional[str],
        razorpay_payment_link_reference_id: Optional[str],
        razorpay_payment_link_status: Optional[str],
        razorpay_signature: Optional[str],
        raw_webhook_data: Dict[str, Any]
    ) -> str:
        """Log webhook data to database.
        
        Args:
            razorpay_payment_id: Razorpay payment ID
            razorpay_payment_link_id: Razorpay payment link ID
            razorpay_payment_link_reference_id: Reference ID (our order_id)
            razorpay_payment_link_status: Payment status
            razorpay_signature: Webhook signature
            raw_webhook_data: Complete webhook payload
            
        Returns:
            webhook_id: Generated webhook ID
        """
        client = get_mongo_client()
        
        webhook_id = OrderOperations.generate_webhook_id()
        
        webhook_doc = {
            "webhook_id": webhook_id,
            "razorpay_payment_id": razorpay_payment_id,
            "razorpay_payment_link_id": razorpay_payment_link_id,
            "razorpay_payment_link_reference_id": razorpay_payment_link_reference_id,
            "razorpay_payment_link_status": razorpay_payment_link_status,
            "razorpay_signature": razorpay_signature,
            "raw_webhook_data": raw_webhook_data,
            "processed": False,
            "order_updated": False,
            "processing_error": None,
            "created_at": datetime.utcnow()
        }
        
        client["dance_app"]["razorpay_webhook_logs"].insert_one(webhook_doc)
        return webhook_id
    
    @staticmethod
    def update_webhook_processing_status(
        webhook_id: str,
        processed: bool,
        order_updated: bool,
        processing_error: Optional[str] = None
    ) -> bool:
        """Update webhook processing status.
        
        Args:
            webhook_id: Webhook identifier
            processed: Whether webhook was processed
            order_updated: Whether order was updated
            processing_error: Error message if any
            
        Returns:
            Success status
        """
        client = get_mongo_client()
        
        update_data = {
            "processed": processed,
            "order_updated": order_updated,
            "processing_error": processing_error
        }
        
        result = client["dance_app"]["razorpay_webhook_logs"].update_one(
            {"webhook_id": webhook_id},
            {"$set": update_data}
        )
        return result.modified_count > 0
