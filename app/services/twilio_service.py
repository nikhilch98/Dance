"""Twilio OTP service for authentication."""

import logging
from typing import Optional
from twilio.rest import Client
from twilio.base.exceptions import TwilioException

from app.config.settings import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class TwilioOTPService:
    """Service for handling OTP operations with Twilio."""
    
    def __init__(self):
        """Initialize Twilio client."""
        if not all([settings.twilio_account_sid, settings.twilio_auth_token, settings.twilio_verify_service_sid]):
            raise ValueError("Twilio credentials not properly configured")
        
        self.client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
        self.verify_service_sid = settings.twilio_verify_service_sid
    
    def send_otp(self, mobile_number: str) -> dict:
        """
        Send OTP to mobile number.
        
        Args:
            mobile_number: 10-digit mobile number without country code
            
        Returns:
            dict: Response with status and message
        """
        try:
            # Format mobile number with +91 country code
            formatted_number = f"+91{mobile_number}"
            
            # Send OTP using Twilio Verify
            verification = self.client.verify.v2.services(
                self.verify_service_sid
            ).verifications.create(
                to=formatted_number,
                channel="sms"
            )
            
            if verification.status == "pending":
                logger.info(f"OTP sent successfully to {mobile_number}")
                return {
                    "success": True,
                    "message": "OTP sent successfully",
                    "sid": verification.sid
                }
            else:
                logger.error(f"Failed to send OTP to {mobile_number}: {verification.status}")
                return {
                    "success": False,
                    "message": "Failed to send OTP"
                }
                
        except TwilioException as e:
            logger.error(f"Twilio error sending OTP to {mobile_number}: {str(e)}")
            return {
                "success": False,
                "message": f"Failed to send OTP: {str(e)}"
            }
        except Exception as e:
            logger.error(f"Unexpected error sending OTP to {mobile_number}: {str(e)}")
            return {
                "success": False,
                "message": "An unexpected error occurred"
            }
    
    def verify_otp(self, mobile_number: str, otp_code: str) -> dict:
        """
        Verify OTP code.
        
        Args:
            mobile_number: 10-digit mobile number without country code
            otp_code: 6-digit OTP code
            
        Returns:
            dict: Response with verification status
        """
        try:
            # Format mobile number with +91 country code
            formatted_number = f"+91{mobile_number}"
            
            # Verify OTP using Twilio Verify
            verification_check = self.client.verify.v2.services(
                self.verify_service_sid
            ).verification_checks.create(
                to=formatted_number,
                code=otp_code
            )
            
            if verification_check.status == "approved":
                logger.info(f"OTP verified successfully for {mobile_number}")
                return {
                    "success": True,
                    "message": "OTP verified successfully",
                    "sid": verification_check.sid
                }
            else:
                logger.warning(f"OTP verification failed for {mobile_number}: {verification_check.status}")
                return {
                    "success": False,
                    "message": "Invalid or expired OTP"
                }
                
        except TwilioException as e:
            logger.error(f"Twilio error verifying OTP for {mobile_number}: {str(e)}")
            return {
                "success": False,
                "message": f"OTP verification failed: {str(e)}"
            }
        except Exception as e:
            logger.error(f"Unexpected error verifying OTP for {mobile_number}: {str(e)}")
            return {
                "success": False,
                "message": "An unexpected error occurred"
            }


# Global instance with lazy initialization
def get_twilio_service() -> TwilioOTPService:
    """Get Twilio service instance."""
    return TwilioOTPService() 