"""Order and payment-related data models."""

from datetime import datetime
from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class OrderStatusEnum(str, Enum):
    """Order status enumeration."""
    CREATED = "created"
    PAID = "paid"
    FAILED = "failed"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class PaymentGatewayEnum(str, Enum):
    """Payment gateway enumeration."""
    RAZORPAY = "razorpay"


class WorkshopDetails(BaseModel):
    """Workshop details for orders."""
    title: Optional[str] = None
    artist_names: List[str] = []
    studio_name: str
    date: str
    time: str
    uuid: str


class CreatePaymentLinkRequest(BaseModel):
    """Request model for creating payment link."""
    workshop_uuid: str = Field(..., description="Workshop UUID to create payment for")


class OrderCreate(BaseModel):
    """Model for creating a new order."""
    user_id: str
    workshop_uuid: str
    workshop_details: WorkshopDetails
    amount: int  # Amount in paise
    currency: str = "INR"
    payment_gateway: PaymentGatewayEnum = PaymentGatewayEnum.RAZORPAY


class Order(BaseModel):
    """Complete order model."""
    order_id: str
    user_id: str
    workshop_uuid: str
    workshop_details: WorkshopDetails
    amount: int  # Amount in paise
    currency: str
    status: OrderStatusEnum
    payment_gateway: PaymentGatewayEnum
    payment_link_id: Optional[str] = None
    payment_link_url: Optional[str] = None
    expires_at: Optional[datetime] = None
    payment_gateway_details: Optional[Dict[str, Any]] = None
    qr_code_data: Optional[str] = None  # Base64 encoded QR code image
    qr_code_generated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class OrderResponse(BaseModel):
    """Order response model for API."""
    order_id: str
    workshop_uuid: str
    workshop_details: WorkshopDetails
    amount: int
    currency: str
    status: OrderStatusEnum
    payment_link_url: Optional[str] = None
    qr_code_data: Optional[str] = None  # Base64 encoded QR code image
    qr_code_generated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


class CreatePaymentLinkResponse(BaseModel):
    """Response model for create payment link API."""
    success: bool
    order_id: str
    payment_link_url: str
    payment_link_id: str
    amount: int
    currency: str
    expires_at: datetime
    workshop_details: WorkshopDetails


class UnifiedPaymentLinkResponse(BaseModel):
    """Unified response for payment link creation (new or existing)."""
    success: bool = True
    is_existing: bool = False
    message: str = "Payment link created successfully"
    order_id: str
    payment_link_url: str
    payment_link_id: Optional[str] = None
    amount: int
    currency: str
    expires_at: Optional[datetime] = None
    workshop_details: WorkshopDetails


class ExistingPaymentResponse(BaseModel):
    """Response when active payment already exists."""
    success: bool = True
    is_existing: bool = True
    message: str = "Active payment link found for this workshop"
    order_id: str
    payment_link_url: str
    payment_link_id: Optional[str] = None
    amount: int
    currency: str
    expires_at: Optional[datetime] = None
    workshop_details: WorkshopDetails


class RazorpayWebhookRequest(BaseModel):
    """Razorpay webhook request parameters."""
    razorpay_payment_id: Optional[str] = None
    razorpay_payment_link_id: Optional[str] = None
    razorpay_payment_link_reference_id: Optional[str] = None
    razorpay_payment_link_status: Optional[str] = None
    razorpay_signature: Optional[str] = None


class WebhookLog(BaseModel):
    """Webhook log model."""
    webhook_id: str
    razorpay_payment_id: Optional[str] = None
    razorpay_payment_link_id: Optional[str] = None
    razorpay_payment_link_reference_id: Optional[str] = None
    razorpay_payment_link_status: Optional[str] = None
    razorpay_signature: Optional[str] = None
    raw_webhook_data: Dict[str, Any]
    processed: bool = False
    order_updated: bool = False
    processing_error: Optional[str] = None
    created_at: datetime


class UserOrdersResponse(BaseModel):
    """Response model for user orders API."""
    success: bool
    orders: List[OrderResponse]
    total_count: int
    has_more: bool


class WebhookResponse(BaseModel):
    """Response model for webhook processing."""
    success: bool
    message: str
    order_updated: bool = False
