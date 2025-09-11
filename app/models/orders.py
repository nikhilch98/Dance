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


class BundleWorkshopInfo(BaseModel):
    """Workshop information within a bundle."""
    song: Optional[str] = None
    title: Optional[str] = None
    artist_names: Optional[List[str]] = None
    by: Optional[str] = None  # Alternative artist field
    studio_name: Optional[str] = None
    date: Optional[str] = None
    time: Optional[str] = None


class BundleInfo(BaseModel):
    """Bundle information for bundle orders."""
    name: str
    description: str = ""
    workshops: List[BundleWorkshopInfo] = []
    savings_amount: float = 0.0


class CreatePaymentLinkRequest(BaseModel):
    """Request model for creating payment link."""
    workshop_uuid: str = Field(..., description="Workshop UUID to create payment for")
    points_redeemed: Optional[float] = Field(0.0, description="Reward points redeemed for discount")
    discount_amount: Optional[float] = Field(0.0, description="Discount amount from redeemed points")


class CreateBundlePaymentLinkRequest(BaseModel):
    """Request model for creating bundle payment link."""
    bundle_id: str = Field(..., description="Bundle ID to create payment for")
    workshop_uuids: List[str] = Field(..., description="List of workshop UUIDs in the bundle")
    points_redeemed: Optional[float] = Field(0.0, description="Reward points redeemed for discount")
    discount_amount: Optional[float] = Field(0.0, description="Discount amount from redeemed points")


class OrderCreate(BaseModel):
    """Model for creating a new order."""
    user_id: str
    workshop_uuids: List[str]  # Support multiple workshops for bundles
    workshop_details: WorkshopDetails
    amount: int  # Amount in paise
    currency: str = "INR"
    rewards_redeemed: Optional[float] = None  # Reward points redeemed (in rupees)
    final_amount_paid: Optional[float] = None  # Final amount after discount (in rupees)
    payment_gateway: PaymentGatewayEnum = PaymentGatewayEnum.RAZORPAY
    # Bundle-related fields
    bundle_id: Optional[str] = None
    bundle_payment_id: Optional[str] = None
    is_bundle_order: Optional[bool] = False
    bundle_total_workshops: Optional[int] = None
    bundle_total_amount: Optional[int] = None


class Order(BaseModel):
    """Complete order model."""
    order_id: str
    user_id: str
    workshop_uuids: List[str]  # Support multiple workshops for bundles
    workshop_details: WorkshopDetails
    amount: int  # Amount in paise
    currency: str
    status: OrderStatusEnum
    payment_gateway: PaymentGatewayEnum
    payment_link_id: Optional[str] = None
    payment_link_url: Optional[str] = None
    expires_at: Optional[datetime] = None
    payment_gateway_details: Optional[Dict[str, Any]] = None
    qr_code_data: Optional[str] = None  # Base64 encoded QR code image (legacy single)
    qr_codes_data: Optional[Dict[str, str]] = None  # Multiple QR codes for bundles (workshop_uuid -> qr_data)
    qr_code_generated_at: Optional[datetime] = None
    # Reward-related fields
    rewards_generated: Optional[bool] = False
    cashback_amount: Optional[float] = None  # Cashback amount in rupees
    rewards_generated_at: Optional[datetime] = None
    rewards_redeemed: Optional[float] = None  # Rewards redeemed for this order in rupees
    final_amount_paid: Optional[float] = None  # Final amount after reward redemption in rupees
    # Bundle-related fields
    bundle_id: Optional[str] = None
    bundle_payment_id: Optional[str] = None
    is_bundle_order: Optional[bool] = False
    bundle_total_workshops: Optional[int] = None
    bundle_total_amount: Optional[int] = None
    created_at: datetime
    updated_at: datetime


class OrderResponse(BaseModel):
    """Order response model for API."""
    order_id: str
    workshop_uuids: List[str]  # Support multiple workshops for bundles
    workshop_details: WorkshopDetails
    amount: int
    currency: str
    status: OrderStatusEnum
    payment_link_url: Optional[str] = None
    qr_code_data: Optional[str] = None  # Base64 encoded QR code image (legacy single)
    qr_codes_data: Optional[Dict[str, str]] = None  # Multiple QR codes for bundles (workshop_uuid -> qr_data)
    qr_code_generated_at: Optional[datetime] = None
    # Reward information for order history
    cashback_amount: Optional[float] = None  # Cashback earned in rupees
    rewards_redeemed: Optional[float] = None  # Rewards redeemed in rupees
    final_amount_paid: Optional[float] = None  # Final amount after redemption in rupees
    # Bundle information
    bundle_id: Optional[str] = None
    bundle_payment_id: Optional[str] = None
    is_bundle_order: Optional[bool] = False
    bundle_total_workshops: Optional[int] = None
    bundle_total_amount: Optional[int] = None
    bundle_info: Optional[BundleInfo] = None  # Additional bundle context
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
    # Tiered pricing fields
    tier_info: Optional[str] = None
    is_early_bird: Optional[bool] = False
    pricing_changed: Optional[bool] = False
    # Note: Bundle-related fields removed - bundles are handled through separate APIs


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


class BundleTemplate(BaseModel):
    """Bundle template definition."""
    template_id: str
    name: str
    description: Optional[str] = None
    workshop_ids: List[str]
    bundle_price: int
    individual_prices: List[int]
    currency: str = "INR"
    discount_percentage: Optional[float] = None
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None
    max_participants: Optional[int] = None
    is_active: bool = True
    created_at: datetime


class BundleOrder(BaseModel):
    """Bundle order tracking."""
    bundle_id: str
    name: str
    bundle_payment_id: str
    member_orders: List[Dict[str, Any]]
    total_amount: int
    individual_amount: int
    currency: str = "INR"
    user_id: str
    status: str = "active"  # active, completed, cancelled, expired
    created_at: datetime
    completed_at: Optional[datetime] = None


class BundleMemberOrder(BaseModel):
    """Individual order within a bundle."""
    order_id: str
    workshop_uuid: str
    position: int
    status: str
    qr_generated: bool = False


class BundlePurchaseRequest(BaseModel):
    """Request to purchase a bundle."""
    template_id: str
    user_id: str


class BundlePurchaseResponse(BaseModel):
    """Response for bundle purchase."""
    success: bool
    bundle_id: str
    payment_link_url: str
    payment_link_id: str
    total_amount: int
    currency: str
    individual_orders: List[str]  # List of order IDs
    message: str


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
