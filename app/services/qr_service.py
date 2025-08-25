"""QR Code generation service with custom nachna logo embedding and cryptographic security."""

import base64
import hashlib
import hmac
import json
import logging
import secrets
from datetime import datetime, timedelta
from io import BytesIO
from typing import Dict, Optional, Any

import qrcode
from PIL import Image, ImageDraw
from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.moduledrawers import RoundedModuleDrawer

from app.config.settings import settings

logger = logging.getLogger(__name__)


class QRCodeService:
    """Service for generating QR codes with nachna branding and cryptographic security."""
    
    def __init__(self):
        self.logo_size_ratio = 0.15  # Logo will be 15% of QR code size
        self.border_ratio = 0.02     # Border around logo (2% of QR code size)
        # Use app secret key for QR code signing
        self.secret_key = getattr(settings, 'SECRET_KEY', 'nachna-qr-secret-key-2025').encode('utf-8')
        self.qr_validity_hours = 720  # QR codes valid for 30 days (720 hours)
    
    def generate_order_qr_code(
        self,
        order_id: str,
        workshop_title: str,
        amount: int,
        user_name: str,
        user_phone: str,
        workshop_uuid: str,
        artist_names: list,
        studio_name: str,
        workshop_date: str,
        workshop_time: str,
        payment_gateway_details: Optional[Dict[str, Any]] = None
    ) -> str:
        """Generate secure QR code for an order with embedded nachna logo.
        
        Args:
            order_id: Order identifier
            workshop_title: Workshop title
            amount: Amount in paise
            user_name: User's full name
            user_phone: User's phone number
            workshop_uuid: Workshop unique identifier
            artist_names: List of artist names
            studio_name: Studio name
            workshop_date: Workshop date
            workshop_time: Workshop time
            payment_gateway_details: Payment gateway transaction details
            
        Returns:
            Base64 encoded QR code image
        """
        try:
            # Create secure QR code data with comprehensive details
            qr_data = self._create_secure_qr_data(
                order_id, workshop_title, amount, user_name, user_phone,
                workshop_uuid, artist_names, studio_name, workshop_date, workshop_time,
                payment_gateway_details
            )
            
            # Generate QR code with custom styling
            qr_image = self._generate_styled_qr_code(qr_data)
            
            # Embed nachna logo
            qr_with_logo = self._embed_logo(qr_image)
            
            # Convert to base64
            base64_image = self._image_to_base64(qr_with_logo)
            
            logger.info(f"Generated secure QR code for order {order_id}")
            return base64_image
            
        except Exception as e:
            logger.error(f"Failed to generate QR code for order {order_id}: {str(e)}")
            raise
    
    def _create_secure_qr_data(
        self,
        order_id: str,
        workshop_title: str,
        amount: int,
        user_name: str,
        user_phone: str,
        workshop_uuid: str,
        artist_names: list,
        studio_name: str,
        workshop_date: str,
        workshop_time: str,
        payment_gateway_details: Optional[Dict[str, Any]] = None
    ) -> str:
        """Create secure QR code data with cryptographic verification."""
        # Generate timestamp and expiry
        now = datetime.now()
        expires_at = now + timedelta(hours=self.qr_validity_hours)
        
        # Create comprehensive registration data
        registration_data = {
            "order_id": order_id,
            "workshop": {
                "uuid": workshop_uuid,
                "title": workshop_title,
                "artists": artist_names,
                "studio": studio_name,
                "date": workshop_date,
                "time": workshop_time
            },
            "registration": {
                "user_name": user_name,
                "user_phone": user_phone,
                "amount_paid": amount / 100,  # Convert to rupees
                "currency": "INR"
            },
            "verification": {
                "generated_at": now.isoformat(),
                "expires_at": expires_at.isoformat(),
                "nonce": secrets.token_hex(8)  # Random nonce for uniqueness
            }
        }
        
        # Add payment gateway transaction ID if available
        if payment_gateway_details and "payment_id" in payment_gateway_details:
            registration_data["payment"] = {
                "transaction_id": payment_gateway_details["payment_id"],
                "gateway": "razorpay"
            }
        
        # Create JSON string of the data
        data_json = json.dumps(registration_data, separators=(',', ':'), sort_keys=True)
        
        # Generate cryptographic signature
        signature = self._generate_signature(data_json)
        
        # Create final QR code payload
        qr_payload = {
            "v": "1.0",  # Version
            "t": "nachna_registration",  # Type
            "d": registration_data,  # Data
            "s": signature  # Signature
        }
        
        return json.dumps(qr_payload, separators=(',', ':'))
    
    def _generate_signature(self, data: str) -> str:
        """Generate HMAC signature for QR code data."""
        return hmac.new(
            self.secret_key,
            data.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
    
    def verify_qr_code(self, qr_data: str) -> Dict[str, Any]:
        """Verify QR code authenticity and extract registration data.
        
        Args:
            qr_data: Raw QR code data string
            
        Returns:
            Dictionary containing verification result and registration data
        """
        try:
            # Parse QR code payload
            payload = json.loads(qr_data)
            
            # Validate payload structure
            if not all(key in payload for key in ["v", "t", "d", "s"]):
                return {"valid": False, "error": "Invalid QR code format"}
            
            if payload["t"] != "nachna_registration":
                return {"valid": False, "error": "Not a nachna registration QR code"}
            
            # Extract data and signature
            registration_data = payload["d"]
            provided_signature = payload["s"]
            
            # Recreate data JSON for signature verification
            data_json = json.dumps(registration_data, separators=(',', ':'), sort_keys=True)
            expected_signature = self._generate_signature(data_json)
            
            # Verify signature
            if not hmac.compare_digest(provided_signature, expected_signature):
                return {"valid": False, "error": "Invalid signature - potential fraud"}
            
            # Check expiry
            expires_at = datetime.fromisoformat(registration_data["verification"]["expires_at"])
            if datetime.now() > expires_at:
                return {"valid": False, "error": "QR code has expired"}
            
            # Return valid data
            return {
                "valid": True,
                "registration_data": registration_data,
                "verification_details": {
                    "verified_at": datetime.now().isoformat(),
                    "signature_valid": True,
                    "expires_at": expires_at.isoformat()
                }
            }
            
        except json.JSONDecodeError:
            return {"valid": False, "error": "Invalid QR code format"}
        except Exception as e:
            logger.error(f"QR code verification error: {str(e)}")
            return {"valid": False, "error": f"Verification failed: {str(e)}"}
    
    def _generate_styled_qr_code(self, data: str) -> Image.Image:
        """Generate QR code with custom styling."""
        # Create QR code instance with high error correction for logo embedding
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_H,  # High error correction
            box_size=10,
            border=4,
        )
        
        qr.add_data(data)
        qr.make(fit=True)
        
        # Create QR code image with styled appearance
        qr_image = qr.make_image(
            image_factory=StyledPilImage,
            module_drawer=RoundedModuleDrawer(),
            fill_color="#1A1A2E",      # Dark blue for nachna theme
            back_color="#FFFFFF"       # White background
        )
        
        return qr_image
    
    def _embed_logo(self, qr_image: Image.Image) -> Image.Image:
        """Embed nachna logo in the center of QR code."""
        try:
            # Convert to RGBA if needed
            if qr_image.mode != 'RGBA':
                qr_image = qr_image.convert('RGBA')
            
            # Create nachna logo (since we don't have the actual file, create a styled text logo)
            logo = self._create_nachna_logo(qr_image.size)
            
            # Calculate position to center the logo
            logo_size = logo.size
            qr_size = qr_image.size
            
            position = (
                (qr_size[0] - logo_size[0]) // 2,
                (qr_size[1] - logo_size[1]) // 2
            )
            
            # Paste logo onto QR code
            qr_image.paste(logo, position, logo)
            
            return qr_image
            
        except Exception as e:
            logger.warning(f"Failed to embed logo, returning plain QR code: {str(e)}")
            return qr_image
    
    def _create_nachna_logo(self, qr_size: tuple) -> Image.Image:
        """Create a styled nachna logo for embedding."""
        # Calculate logo size
        logo_size = int(min(qr_size) * self.logo_size_ratio)
        border_size = int(min(qr_size) * self.border_ratio)
        total_size = logo_size + (border_size * 2)
        
        # Create logo image
        logo = Image.new('RGBA', (total_size, total_size), (255, 255, 255, 0))
        draw = ImageDraw.Draw(logo)
        
        # Draw white circle background with border
        circle_bbox = [border_size, border_size, total_size - border_size, total_size - border_size]
        draw.ellipse(circle_bbox, fill=(255, 255, 255, 255), outline=(26, 26, 46, 255), width=2)
        
        # Draw nachna logo elements
        center_x, center_y = total_size // 2, total_size // 2
        
        # Create gradient-like effect with multiple circles
        gradient_colors = [
            (0, 212, 255, 255),    # #00D4FF - nachna blue
            (156, 39, 176, 255),   # #9C27B0 - nachna purple
        ]
        
        # Draw gradient circles
        circle_radius = logo_size // 6
        for i, color in enumerate(gradient_colors):
            offset = (i - 0.5) * circle_radius
            circle_x = center_x + int(offset)
            circle_y = center_y
            
            circle_bbox = [
                circle_x - circle_radius, circle_y - circle_radius,
                circle_x + circle_radius, circle_y + circle_radius
            ]
            draw.ellipse(circle_bbox, fill=color)
        
        # Add "N" text in the center
        try:
            from PIL import ImageFont
            # Try to use a system font
            font_size = logo_size // 4
            font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", font_size)
        except:
            # Fallback to default font
            font = ImageFont.load_default()
        
        # Draw "N" for nachna
        text = "N"
        text_bbox = draw.textbbox((0, 0), text, font=font)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        
        text_x = center_x - (text_width // 2)
        text_y = center_y - (text_height // 2)
        
        draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)
        
        return logo
    
    def _image_to_base64(self, image: Image.Image) -> str:
        """Convert PIL Image to base64 string."""
        buffer = BytesIO()
        image.save(buffer, format='PNG')
        buffer.seek(0)
        
        image_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
        return f"data:image/png;base64,{image_base64}"


# Global service instance
qr_service = QRCodeService()


def get_qr_service() -> QRCodeService:
    """Get QR code service instance."""
    return qr_service
