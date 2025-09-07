"""Rewards system models for Pydantic validation and API responses."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field
from enum import Enum


class RewardSourceEnum(str, Enum):
    """Types of reward sources."""
    REFERRAL = "referral"
    CASHBACK = "cashback"
    WELCOME_BONUS = "welcome_bonus"
    SPECIAL_PROMOTION = "special_promotion"
    WORKSHOP_COMPLETION = "workshop_completion"
    ADMIN_BONUS = "admin_bonus"
    REFUND = "refund"


class RewardTransactionTypeEnum(str, Enum):
    """Types of reward transactions."""
    CREDIT = "credit"  # Points earned
    DEBIT = "debit"    # Points redeemed


class RewardTransactionStatusEnum(str, Enum):
    """Status of reward transactions."""
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


# Database Models
class RewardWallet(BaseModel):
    """User's reward wallet."""
    user_id: str
    total_balance: float = Field(default=0.0, description="Total reward points balance")
    available_balance: float = Field(default=0.0, description="Available points for redemption")
    lifetime_earned: float = Field(default=0.0, description="Total points earned lifetime")
    lifetime_redeemed: float = Field(default=0.0, description="Total points redeemed lifetime")
    created_at: datetime
    updated_at: datetime


class RewardTransaction(BaseModel):
    """Individual reward transaction."""
    transaction_id: str
    user_id: str
    transaction_type: RewardTransactionTypeEnum
    amount: float = Field(description="Amount of reward points")
    source: RewardSourceEnum
    status: RewardTransactionStatusEnum
    description: str = Field(description="Human readable description")
    reference_id: Optional[str] = Field(None, description="Reference to order, referral, etc.")
    metadata: Optional[dict] = Field(None, description="Additional transaction data")
    created_at: datetime
    processed_at: Optional[datetime] = None


class RewardRedemption(BaseModel):
    """Reward redemption for workshop booking."""
    redemption_id: str
    user_id: str
    order_id: str
    workshop_uuid: str
    points_redeemed: float
    discount_amount: float = Field(description="Monetary discount equivalent")
    original_amount: float
    final_amount: float
    status: RewardTransactionStatusEnum
    created_at: datetime
    processed_at: Optional[datetime] = None


# API Request Models
class RewardRedemptionRequest(BaseModel):
    """Request to redeem rewards for workshop booking."""
    workshop_uuid: str
    points_to_redeem: float = Field(gt=0, description="Points to redeem (must be positive)")
    order_amount: float = Field(gt=0, description="Original order amount")


class RewardBalanceResponse(BaseModel):
    """Response with user's reward balance information."""
    user_id: str
    total_balance: float
    available_balance: float
    lifetime_earned: float
    lifetime_redeemed: float
    redemption_cap_per_workshop: float = Field(description="Maximum points redeemable per workshop")


class RewardTransactionResponse(BaseModel):
    """Response for reward transaction."""
    transaction_id: str
    transaction_type: RewardTransactionTypeEnum
    amount: float
    source: RewardSourceEnum
    status: RewardTransactionStatusEnum
    description: str
    reference_id: Optional[str]
    created_at: datetime
    processed_at: Optional[datetime]


class RewardTransactionListResponse(BaseModel):
    """Response with list of reward transactions."""
    transactions: List[RewardTransactionResponse]
    total_count: int
    page: int
    page_size: int


class RewardRedemptionResponse(BaseModel):
    """Response for reward redemption."""
    redemption_id: str
    points_redeemed: float
    discount_amount: float
    original_amount: float
    final_amount: float
    savings_percentage: float = Field(description="Percentage saved")
    status: RewardTransactionStatusEnum


class RewardSummaryResponse(BaseModel):
    """Summary response for rewards center."""
    balance: RewardBalanceResponse
    recent_transactions: List[RewardTransactionResponse]
    total_savings: float = Field(description="Total money saved through rewards")
    redemption_history_count: int


# Workshop Redemption Models
class WorkshopRedemptionInfo(BaseModel):
    """Information about reward redemption for a specific workshop."""
    workshop_uuid: str
    workshop_title: str
    original_amount: float
    max_redeemable_points: float
    max_discount_amount: float
    user_available_balance: float
    recommended_redemption: float = Field(description="Recommended points to redeem")


class RedemptionCalculationRequest(BaseModel):
    """Request to calculate redemption for workshop."""
    workshop_uuid: str
    workshop_amount: float


class RedemptionCalculationResponse(BaseModel):
    """Response with redemption calculation."""
    workshop_info: WorkshopRedemptionInfo
    exchange_rate: float = Field(description="Points to currency exchange rate (e.g., 1 point = 1 rupee)")
    can_redeem: bool
    message: Optional[str] = Field(description="Message if redemption not possible")
