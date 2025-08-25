"""Razorpay API models and response structures."""

from enum import Enum
from typing import Optional, List, Dict, Any
from pydantic import BaseModel

class PaymentLinkStatusEnum(str, Enum):
    CREATED = "created"
    PAID = "paid"
    ATTEMPTED = "attempted"
    CANCELLED = "cancelled"
    EXPIRED = "expired"

class NotifyChannels(BaseModel):
    email: bool
    sms: bool
    whatsapp: bool

class CustomerInfo(BaseModel):
    contact: str
    email: str
    name: str

class PaymentLinkResponse(BaseModel):
    accept_partial: bool
    amount: int
    amount_paid: int
    callback_method: Optional[str] = None
    callback_url: Optional[str] = None
    cancelled_at: Optional[int] = None
    created_at: int
    currency: str
    customer: CustomerInfo
    description: str
    expire_by: int
    expired_at: int
    first_min_partial_amount: int
    id: str
    notes: Optional[Dict] = None
    notify: NotifyChannels
    payments: Optional[List] = None
    reference_id: str
    reminder_enable: bool
    reminders: List = []
    short_url: str
    status: PaymentLinkStatusEnum
    updated_at: int
    upi_link: bool
    user_id: str
    whatsapp_link: bool