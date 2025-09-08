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

from app.config.settings import get_settings

logger = logging.getLogger(__name__)


class QRCodeService:
    """Service for generating QR codes with nachna branding and cryptographic security."""

    def __init__(self):
        self.logo_size_ratio = 0.20  # Logo will be 20% of QR code size (increased for better visibility)
        self.border_ratio = 0.03     # Border around logo (3% of QR code size)
        # Use app secret key for QR code signing
        app_settings = get_settings()
        self.secret_key = getattr(app_settings, 'secret_key', 'nachna-qr-secret-key-2025').encode('utf-8')
        self.qr_validity_hours = 720  # QR codes valid for 30 days (720 hours)

        # Cache for pre-generated logo to avoid recreation
        self._cached_logo = None
        self._cached_logo_size = None

        # Cache for QR code data to avoid duplicate generation
        self._qr_cache = {}
        self._cache_max_size = 100  # Maximum cached QR codes
    
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
            # Create cache key from order data
            cache_key = self._create_cache_key(
                order_id, workshop_title, amount, user_name, user_phone,
                workshop_uuid, artist_names, studio_name, workshop_date, workshop_time,
                payment_gateway_details
            )

            # Check cache first
            if cache_key in self._qr_cache:
                logger.debug(f"Using cached QR code for order {order_id}")
                return self._qr_cache[cache_key]

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

            # Cache the result (with size limit)
            if len(self._qr_cache) < self._cache_max_size:
                self._qr_cache[cache_key] = base64_image
            elif len(self._qr_cache) >= self._cache_max_size:
                # Remove oldest entry if cache is full
                oldest_key = next(iter(self._qr_cache))
                del self._qr_cache[oldest_key]
                self._qr_cache[cache_key] = base64_image

            logger.info(f"Generated secure QR code for order {order_id} with Nachna logo")
            return base64_image

        except Exception as e:
            logger.error(f"Failed to generate QR code for order {order_id}: {str(e)}")
            raise

    def test_logo_generation(self) -> bool:
        """Test method to verify logo generation is working."""
        try:
            # Test with a standard QR code size
            test_size = (200, 200)
            logo = self._get_cached_logo(test_size)

            if logo is not None:
                logger.info("Logo generation test passed - logo created successfully")
                return True
            else:
                logger.warning("Logo generation test failed - logo creation returned None")
                return False
        except Exception as e:
            logger.error(f"Logo generation test failed with error: {str(e)}")
            return False

    def _create_cache_key(
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
        """Create a cache key from order data."""
        # Create a deterministic string from all parameters
        cache_data = {
            "order_id": order_id,
            "workshop_title": workshop_title,
            "amount": amount,
            "user_name": user_name,
            "user_phone": user_phone,
            "workshop_uuid": workshop_uuid,
            "artist_names": sorted(artist_names) if artist_names else [],
            "studio_name": studio_name,
            "workshop_date": workshop_date,
            "workshop_time": workshop_time,
            "payment_details": payment_gateway_details or {}
        }

        # Create hash for cache key
        import json
        data_str = json.dumps(cache_data, sort_keys=True)
        return hashlib.md5(data_str.encode('utf-8')).hexdigest()
    
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
        """Generate QR code with custom styling - optimized for speed."""
        # Create QR code instance with high error correction for logo embedding
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_H,  # High error correction for logo
            box_size=8,  # Smaller box size for faster generation
            border=4,   # Slightly larger border for better logo placement
        )

        qr.add_data(data)
        qr.make(fit=True)

        # Use simpler image generation for better performance
        qr_image = qr.make_image(
            fill_color="#1A1A2E",      # Dark blue for nachna theme
            back_color="#FFFFFF"       # White background
        )

        return qr_image
    
    def _embed_logo(self, qr_image: Image.Image) -> Image.Image:
        """Embed nachna logo in the center of QR code with proper background and positioning."""
        try:
            # Convert to RGBA if needed
            if qr_image.mode != 'RGBA':
                qr_image = qr_image.convert('RGBA')

            # Get cached logo or create new one
            logo = self._get_cached_logo(qr_image.size)

            if logo is None:
                # If logo creation failed, return plain QR code
                logger.warning("Logo creation failed, returning QR code without logo")
                return qr_image

            # Calculate position to center the logo
            logo_size = logo.size
            qr_size = qr_image.size

            position = (
                (qr_size[0] - logo_size[0]) // 2,
                (qr_size[1] - logo_size[1]) // 2
            )

            # Create a circular background for the logo (white circle with slight transparency)
            background_radius = int(min(logo_size) * 0.6)  # Slightly larger than logo
            background = Image.new('RGBA', qr_image.size, (255, 255, 255, 0))
            bg_draw = ImageDraw.Draw(background)

            # Draw white circular background with slight shadow effect
            bg_center = (qr_size[0] // 2, qr_size[1] // 2)
            bg_bbox = [
                bg_center[0] - background_radius,
                bg_center[1] - background_radius,
                bg_center[0] + background_radius,
                bg_center[1] + background_radius
            ]

            # Draw shadow (dark circle)
            shadow_offset = 2
            shadow_bbox = [bg_bbox[0] + shadow_offset, bg_bbox[1] + shadow_offset,
                          bg_bbox[2] + shadow_offset, bg_bbox[3] + shadow_offset]
            bg_draw.ellipse(shadow_bbox, fill=(0, 0, 0, 60))

            # Draw white background circle
            bg_draw.ellipse(bg_bbox, fill=(255, 255, 255, 220))

            # Composite the background onto the QR code
            qr_image = Image.alpha_composite(qr_image, background)

            # Paste logo onto QR code with proper alpha blending
            qr_image.paste(logo, position, logo)

            logger.debug("Successfully embedded Nachna logo into QR code")
            return qr_image

        except Exception as e:
            logger.warning(f"Failed to embed logo, returning plain QR code: {str(e)}")
            return qr_image

    def _get_cached_logo(self, qr_size: tuple) -> Optional[Image.Image]:
        """Get cached logo or create new one if needed."""
        try:
            # Calculate expected logo size
            logo_size = int(min(qr_size) * self.logo_size_ratio)
            cache_key = (logo_size, logo_size)

            # Check if we have a cached logo of the right size
            if (self._cached_logo is not None and
                self._cached_logo_size == cache_key and
                self._cached_logo.size == cache_key):
                return self._cached_logo.copy()  # Return a copy to avoid modification

            # Create and cache new logo
            logo = self._create_simple_logo(cache_key)
            if logo is not None:
                self._cached_logo = logo
                self._cached_logo_size = cache_key
                return logo.copy()

            return None

        except Exception as e:
            logger.warning(f"Failed to get cached logo: {str(e)}")
            return None
    
    def _create_simple_logo(self, size: tuple) -> Optional[Image.Image]:
        """Create nachna logo for embedding using the actual logo file."""
        try:
            width, height = size

            # Try to load the actual Nachna logo file
            import os
            # Get the absolute path to the logo file from the project root
            project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            logo_path = os.path.join(project_root, "static", "assets", "logo.png")
            try:
                # Load the actual logo
                logo = Image.open(logo_path).convert('RGBA')

                # Resize logo to fit within the QR code (maintain aspect ratio)
                logo.thumbnail((width, height), Image.Resampling.LANCZOS)

                # Create a new image with transparent background
                final_logo = Image.new('RGBA', (width, height), (255, 255, 255, 0))

                # Center the logo
                logo_width, logo_height = logo.size
                x = (width - logo_width) // 2
                y = (height - logo_height) // 2

                # Paste the logo onto the transparent background
                final_logo.paste(logo, (x, y), logo)

                logger.info(f"Successfully loaded and embedded Nachna logo from {logo_path} (resized to {logo.size})")
                return final_logo

            except FileNotFoundError:
                logger.warning(f"Nachna logo file not found at {logo_path}, creating fallback logo")
                return self._create_fallback_logo(size)
            except Exception as e:
                logger.warning(f"Failed to load logo file {logo_path}: {str(e)}, creating fallback logo")
                return self._create_fallback_logo(size)

        except Exception as e:
            logger.warning(f"Failed to create logo: {str(e)}")
            return None

    def _create_fallback_logo(self, size: tuple) -> Optional[Image.Image]:
        """Create a fallback nachna logo when the logo file is not available."""
        try:
            width, height = size

            # Create circular logo with nachna gradient colors
            logo = Image.new('RGBA', (width, height), (255, 255, 255, 0))
            draw = ImageDraw.Draw(logo)

            # Draw gradient circle background (blue to purple)
            for i in range(width):
                for j in range(height):
                    # Calculate distance from center
                    distance = ((i - width/2)**2 + (j - height/2)**2)**0.5
                    if distance <= min(width, height)/2 - 2:
                        # Create gradient from blue to purple
                        ratio = distance / (min(width, height)/2)
                        r = int(0 + (138 - 0) * ratio)  # Blue to purple
                        g = int(212 + (77 - 212) * ratio)  # Blue to purple
                        b = int(255 + (255 - 255) * ratio)  # Blue to purple
                        logo.putpixel((i, j), (r, g, b, 255))

            # Draw "NACHNA" text with white color
            try:
                # Try to use a better font if available
                from PIL import ImageFont
                try:
                    # Try to load a system font
                    font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", int(height * 0.25))
                except:
                    try:
                        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(height * 0.25))
                    except:
                        font = ImageFont.load_default()

                # Calculate text size and position
                text = "NACHNA"
                bbox = draw.textbbox((0, 0), text, font=font)
                text_width = bbox[2] - bbox[0]
                text_height = bbox[3] - bbox[1]

                x = (width - text_width) // 2
                y = (height - text_height) // 2

                # Draw text with white color and slight shadow for better visibility
                # Shadow
                draw.text((x+1, y+1), text, font=font, fill=(0, 0, 0, 128))
                # Main text
                draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

            except ImportError:
                # Fallback if PIL font loading fails
                logger.debug("PIL ImageFont not available, using simple text drawing")

                # Draw simple "N" using lines as fallback
                center_x, center_y = width // 2, height // 2
                n_width = int(width * 0.4)
                n_height = int(height * 0.5)
                n_x = center_x - n_width // 2
                n_y = center_y - n_height // 2

                # Draw N shape with white lines
                draw.line([(n_x, n_y), (n_x, n_y + n_height)], fill=(255, 255, 255, 255), width=max(1, int(width * 0.05)))
                draw.line([(n_x, n_y), (n_x + n_width, n_y + n_height)], fill=(255, 255, 255, 255), width=max(1, int(width * 0.05)))
                draw.line([(n_x + n_width, n_y), (n_x + n_width, n_y + n_height)], fill=(255, 255, 255, 255), width=max(1, int(width * 0.05)))

            logger.debug("Created fallback Nachna logo")
            return logo

        except Exception as e:
            logger.warning(f"Failed to create fallback logo: {str(e)}")
            return None
    
    def _image_to_base64(self, image: Image.Image) -> str:
        """Convert PIL Image to base64 string - optimized version."""
        buffer = BytesIO()

        # Use optimized PNG saving with reduced quality for smaller file size
        image.save(buffer, format='PNG', optimize=True)
        buffer.seek(0)

        # Use base64 encode directly without intermediate decoding
        image_base64 = base64.b64encode(buffer.getvalue()).decode('ascii')
        return f"data:image/png;base64,{image_base64}"


# Global service instance
qr_service = QRCodeService()


def get_qr_service() -> QRCodeService:
    """Get QR code service instance."""
    return qr_service
