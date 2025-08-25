"""Razorpay payment service for handling payment links and orders."""

import logging
import time
from typing import Optional
import razorpay

from app.config.settings import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class RazorpayService:
    """Service for handling OTP operations with Razorpay."""
    
    def __init__(self):
        """Initialize Razorpay client."""
        if not all([settings.razorpay_key_id, settings.razorpay_secret_key]):
            raise ValueError("Razorpay credentials not properly configured")
        
        self.client = razorpay.Client(auth=(settings.razorpay_key_id, settings.razorpay_secret_key))
        self.client.set_app_details({"title": "Nachna Dance", "version": "1.0.0"})

    def create_payment_link(self, amount: int, expire_by_mins: int, order_id: str, user_name: str, user_email: str, user_phone: str, notes: Optional[dict] = None):
        """
        Create a Razorpay payment link.

        Args:
            amount (int): Amount in INR paise (e.g., 10000 for ₹100).
            expire_by_mins (int): Minutes after which the link expires.
            order_id (str): Reference/order ID.
            user_name (str): Customer name.
            user_email (str): Customer email.
            user_phone (str): Customer phone (with country code, e.g., +919999999999).
            notes (Optional[dict]): Additional notes.

        Returns:
            dict: Razorpay payment link response.
        """
        # Calculate expiry timestamp (current time + expire_by_mins)
        expire_by = int(time.time()) + (expire_by_mins * 60)

        payload = {
            # "upi_link": True,
            "amount": amount,  # Amount is already in paise
            "currency": "INR",
            "expire_by": expire_by,
            "reference_id": order_id,
            "description": f"Payment for order {order_id}",
            "customer": {
                "name": user_name,
                "email": user_email,
                "contact": user_phone
            },
            "notify": {
                "sms": True,
                "email": True
            },
            "reminder_enable": True,
            "notes": notes or {},
            "callback_url": settings.razorpay_callback_url,
            "callback_method": "get"
        }

        try:
            response = self.client.payment_link.create(payload)
            logger.info(f"Created Razorpay payment link for order {order_id}: {response.get('id')}")
            return response
        except Exception as e:
            logger.error(f"Failed to create Razorpay payment link: {e}")
            raise

    def create_order_payment_link(
        self,
        order_id: str,
        amount: int,  # Amount in paise
        user_name: str,
        user_email: str,
        user_phone: str,
        workshop_title: str,
        expire_by_mins: int = 60
    ):
        """
        Create a payment link for a workshop order.

        Args:
            order_id (str): Our internal order ID
            amount (int): Amount in paise
            user_name (str): Customer name
            user_email (str): Customer email
            user_phone (str): Customer phone (with country code)
            workshop_title (str): Workshop title for description
            expire_by_mins (int): Minutes after which the link expires (default 60 minutes)

        Returns:
            dict: Razorpay payment link response
        """
        notes = {
            "order_id": order_id,
            "workshop_title": workshop_title,
            "created_by": "nachna_app"
        }

        payload = {
            "amount": amount,
            "currency": "INR",
            "expire_by": int(time.time()) + (expire_by_mins * 60),
            "reference_id": order_id,
            "description": f"Workshop Payment - {workshop_title}",
            "customer": {
                "name": user_name,
                "email": user_email,
                "contact": user_phone
            },
            "notify": {
                "sms": True,
                "email": True
            },
            "reminder_enable": True,
            "notes": notes,
            "callback_url": settings.razorpay_callback_url,
            "callback_method": "get"
        }

        try:
            response = self.client.payment_link.create(payload)
            logger.info(f"Created workshop payment link for order {order_id}: {response.get('id')}")
            return response
        except Exception as e:
            logger.error(f"Failed to create workshop payment link for order {order_id}: {e}")
            raise

# Global instance with lazy initialization
def get_razorpay_service() -> RazorpayService:
    """Get Razorpay service instance."""
    return RazorpayService() 