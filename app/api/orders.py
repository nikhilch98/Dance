"""Order and payment API routes."""

import logging
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.database.orders import OrderOperations, WebhookOperations
from app.database.workshops import DatabaseOperations
from app.database.users import UserOperations
from app.models.orders import (
    CreatePaymentLinkRequest,
    CreatePaymentLinkResponse,
    UnifiedPaymentLinkResponse,
    ExistingPaymentResponse,
    OrderCreate,
    OrderResponse,
    OrderStatusEnum,
    UserOrdersResponse,
    WorkshopDetails,
    BundleInfo,
    BundleWorkshopInfo,
    RazorpayWebhookRequest,
    WebhookResponse,
)
from app.services.auth import verify_token
from app.services.razorpay_service import get_razorpay_service
from app.services.background_qr_service import get_background_qr_service, run_qr_generation_batch
from app.services.background_rewards_service import BackgroundRewardsService

logger = logging.getLogger(__name__)
router = APIRouter()


def parse_tiered_pricing(pricing_info: str, workshop_uuid: str, user_id: str = None) -> dict:
    """Parse tiered pricing information and determine current price.

    Args:
        pricing_info: Tiered pricing string
        workshop_uuid: Workshop UUID to check completed orders
        user_id: User ID for checking existing orders

    Returns:
        dict: {
            'amount_paise': int,
            'tier_info': str,
            'is_early_bird': bool,
            'pricing_changed': bool (if existing order pricing is no longer valid)
        }
    """
    if not pricing_info:
        raise ValueError("Pricing information not available")

    # Check if this contains bundle pricing (look for BUNDLE: in any line)
    lines = pricing_info.split('\n')
    bundle_line = None
    regular_lines = []

    for line in lines:
        if line.strip().startswith('BUNDLE:'):
            bundle_line = line.strip()
        else:
            regular_lines.append(line.strip())

    # If we have bundle pricing, store it but continue with regular pricing
    bundle_info = None
    if bundle_line:
        try:
            bundle_info = parse_bundle_pricing(bundle_line)
            logger.info(f"Bundle pricing detected for workshop {workshop_uuid}: {bundle_info.get('name')}")
        except ValueError as e:
            logger.warning(f"Bundle pricing parse error: {e}")
            bundle_info = None

    # Parse regular pricing lines (time-based or quantity-based)
    current_time = datetime.now()
    current_price = None
    tier_info = "Standard pricing"
    is_early_bird = False

    # Store all valid pricing options
    pricing_options = []

    for line in regular_lines:
        if not line or ':' not in line:
            continue

        try:
            # Parse user-friendly format: "Early Bird (Till 18th Sept): ₹799/-"
            if 'Early Bird' in line and '₹' in line:
                # Extract price from ₹799/-
                price_match = line.split('₹')[1].split('/')[0].strip()
                price = int(price_match)

                # Store pricing option
                pricing_option = {
                    'price_paise': price * 100,
                    'is_early_bird': 'Early Bird' in line and '18th Sept' in line and current_time.day <= 18 and current_time.month == 9,
                    'tier_info': "Early Bird Pricing" if ('Early Bird' in line and '18th Sept' in line and current_time.day <= 18 and current_time.month == 9) else "Standard Pricing",
                    'line': line
                }
                pricing_options.append(pricing_option)

            # Parse quantity-based format: "First 15 spots: ₹999/-"
            elif 'spots:' in line and '₹' in line:
                price_match = line.split('₹')[1].split('/')[0].strip()
                price = int(price_match)

                # Get completed orders count
                completed_count = get_completed_orders_count(workshop_uuid)

                # Store quantity-based pricing option
                pricing_option = {
                    'price_paise': price * 100,
                    'is_early_bird': 'First 15' in line and completed_count < 15,
                    'tier_info': "Early Bird (First 15 spots)" if ('First 15' in line and completed_count < 15) else
                                "Standard (16-20 spots)" if ('16-20' in line and completed_count < 20) else
                                "OTS Pricing",
                    'line': line
                }
                pricing_options.append(pricing_option)

        except (ValueError, IndexError) as e:
            logger.warning(f"Error parsing pricing line '{line}': {e}")
            continue

    # Select the best pricing option
    if pricing_options:
        # Prioritize: Early Bird > Standard > Any available
        early_bird_options = [opt for opt in pricing_options if opt['is_early_bird']]
        if early_bird_options:
            selected_option = early_bird_options[0]  # Take first early bird option
        else:
            # No early bird available, take the first standard option
            standard_options = [opt for opt in pricing_options if not opt['is_early_bird']]
            if standard_options:
                selected_option = standard_options[0]
            else:
                # Fallback to any available option
                selected_option = pricing_options[0]

        return {
            'amount_paise': selected_option['price_paise'],
            'tier_info': selected_option['tier_info'],
            'is_early_bird': selected_option['is_early_bird'],
            'pricing_changed': False,
            'is_bundle': bundle_info is not None,
            'bundle_info': bundle_info
        }

    # Fallback to old format extraction
    try:
        return {
            'amount_paise': extract_pricing_amount(pricing_info),
            'tier_info': 'Standard pricing',
            'is_early_bird': False,
            'pricing_changed': False,
            'is_bundle': bundle_info is not None,
            'bundle_info': bundle_info
        }
    except ValueError:
        raise ValueError(f"Unable to parse pricing information: {pricing_info}")


def evaluate_tier_condition(tier_type: str, condition: str, completed_orders_count: int, workshop: dict = None) -> bool:
    """Evaluate if a tier condition is met."""
    try:
        if tier_type == 'QUANTITY_FIRST':
            limit = int(condition)
            return completed_orders_count < limit

        elif tier_type == 'QUANTITY_AFTER':
            limit = int(condition)
            return completed_orders_count >= limit

        elif tier_type == 'QUANTITY_RANGE':
            # Handle ranges like "16-20"
            if '-' in condition:
                start, end = map(int, condition.split('-'))
                return start <= completed_orders_count + 1 <= end
            return False

        elif tier_type == 'DATE_TILL':
            # Parse date and compare with current date
            from datetime import datetime
            try:
                deadline = datetime.strptime(condition, '%Y-%m-%d').date()
                today = datetime.now().date()
                return today <= deadline
            except ValueError:
                return False

        elif tier_type == 'DATE_AFTER':
            # Parse date and compare with current date
            from datetime import datetime
            try:
                deadline = datetime.strptime(condition, '%Y-%m-%d').date()
                today = datetime.now().date()
                return today > deadline
            except ValueError:
                return False

        elif tier_type == 'FIRST':
            # First N participants
            limit = int(condition)
            return completed_orders_count < limit

        elif tier_type == 'TIME_SLOT':
            # Handle time slot ranges like "09:00-12:00"
            from datetime import datetime
            try:
                if '-' in condition:
                    start_time_str, end_time_str = condition.split('-')
                    start_time = datetime.strptime(start_time_str.strip(), '%H:%M').time()
                    end_time = datetime.strptime(end_time_str.strip(), '%H:%M').time()
                    current_time = datetime.now().time()
                    return start_time <= current_time <= end_time
                return False
            except ValueError:
                return False

        elif tier_type == 'TIME_BEFORE':
            # Handle "book X hours before workshop starts" conditions
            try:
                hours = int(condition)
                if workshop and workshop.get('time'):
                    from datetime import datetime, timedelta
                    try:
                        # Combine workshop date and time
                        workshop_date = workshop.get('date')
                        workshop_time = workshop.get('time')

                        if workshop_date and workshop_time:
                            # Parse workshop datetime
                            workshop_datetime_str = f"{workshop_date} {workshop_time}"
                            workshop_datetime = datetime.strptime(workshop_datetime_str, '%Y-%m-%d %H:%M')

                            # Calculate deadline (X hours before workshop)
                            deadline = workshop_datetime - timedelta(hours=hours)
                            current_time = datetime.now()

                            # Return true if current time is before the deadline
                            return current_time <= deadline
                    except ValueError as e:
                        logger.warning(f"Error parsing workshop time for TIME_BEFORE: {e}")
                        return False
                return False
            except ValueError:
                return False

        elif tier_type == 'TIME_AFTER':
            # Handle "after X hours from now" conditions (for last-minute bookings)
            try:
                hours = int(condition)
                from datetime import datetime, timedelta

                # Calculate if it's within X hours from now
                deadline = datetime.now() + timedelta(hours=hours)
                current_time = datetime.now()

                # Return true if we're past the deadline (for overtime pricing)
                return current_time >= deadline
            except ValueError:
                return False

        return False

    except (ValueError, AttributeError):
        return False


def is_early_bird_tier(tier_type: str, condition: str) -> bool:
    """Check if this is an early bird pricing tier."""
    return tier_type in ['DATE_TILL', 'QUANTITY_FIRST', 'FIRST', 'TIME_BEFORE']


def get_completed_orders_count(workshop_uuid: str) -> int:
    """Get count of completed orders for a workshop."""
    try:
        from utils.utils import get_mongo_client

        client = get_mongo_client()
        db = client["orders"]["orders"]

        # Count orders with status 'paid' for this workshop
        count = db.count_documents({
            "workshop_uuid": workshop_uuid,
            "status": "paid"
        })

        return count

    except Exception as e:
        logger.error(f"Error counting completed orders for workshop {workshop_uuid}: {e}")
        return 0


def parse_bundle_pricing(pricing_info: str) -> dict:
    """Parse bundle pricing information.

    Args:
        pricing_info: Bundle pricing string like "BUNDLE:Weekend Dance Package:WEEKEND_001:WSH_001,WSH_002,WSH_003:2500:INR:Save ₹500"

    Returns:
        dict: Bundle pricing details
    """
    if not pricing_info or not pricing_info.startswith('BUNDLE:'):
        raise ValueError("Invalid bundle pricing format")

    try:
        parts = pricing_info.split(':')
        if len(parts) < 6:
            raise ValueError("Incomplete bundle pricing information")

        return {
            'type': 'bundle',
            'name': parts[1],
            'bundle_id': parts[2],
            'workshop_ids': parts[3].split(','),
            'bundle_price': int(parts[4]),
            'currency': parts[5],
            'description': parts[6] if len(parts) > 6 else "",
            'individual_price': int(parts[4]) // len(parts[3].split(','))  # Divide equally
        }
    except (ValueError, IndexError) as e:
        raise ValueError(f"Invalid bundle pricing format: {e}")


def extract_pricing_amount(pricing_info: str) -> int:
    """Extract amount in paise from pricing_info string.

    Args:
        pricing_info: String like "₹1,500" or "₹500" or "1500"

    Returns:
        Amount in paise (e.g., 150000 for ₹1,500)
    """
    if not pricing_info:
        raise ValueError("Pricing information not available")

    # Remove currency symbols and commas
    amount_str = pricing_info.replace("₹", "").replace(",", "").strip()

    try:
        # Convert to float first (in case of decimal values), then to int
        amount_rupees = float(amount_str)
        amount_paise = int(amount_rupees * 100)
        return amount_paise
    except ValueError:
        raise ValueError(f"Invalid pricing format: {pricing_info}")


def calculate_current_price(pricing_info: str, workshop_uuid: str) -> float:
    """Calculate current price in rupees from pricing_info using tiered pricing logic.

    Args:
        pricing_info: Pricing information string
        workshop_uuid: Workshop UUID for tiered pricing calculation

    Returns:
        Current price in rupees (not paise)
    """
    if not pricing_info:
        return 0.0

    try:
        pricing_result = parse_tiered_pricing(pricing_info, workshop_uuid)
        amount_paise = pricing_result['amount_paise']
        return amount_paise / 100.0  # Convert from paise to rupees
    except (ValueError, KeyError):
        # Fallback to simple extraction if tiered parsing fails
        try:
            return extract_pricing_amount(pricing_info) / 100.0
        except ValueError:
            return 0.0


def get_workshop_by_uuid(workshop_uuid: str) -> dict:
    """Get workshop details by UUID.
    
    Args:
        workshop_uuid: Workshop UUID
        
    Returns:
        Workshop document
        
    Raises:
        HTTPException: If workshop not found
    """
    from utils.utils import get_mongo_client
    
    client = get_mongo_client()
    workshop = client["discovery"]["workshops_v2"].find_one({"uuid": workshop_uuid})
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Workshop with UUID {workshop_uuid} not found"
        )
    
    return workshop


def create_workshop_details(workshop: dict) -> WorkshopDetails:
    """Create WorkshopDetails from workshop document.
    
    Args:
        workshop: Workshop document from database
        
    Returns:
        WorkshopDetails object
    """
    from utils.utils import get_mongo_client
    
    client = get_mongo_client()
    
    # Get studio name
    studio = client["discovery"]["studios"].find_one({"studio_id": workshop["studio_id"]})
    studio_name = studio["studio_name"] if studio else "Unknown Studio"
    
    # Get artist names
    artist_names = []
    if workshop.get("artist_id_list"):
        artists = list(client["discovery"]["artists_v2"].find({
            "artist_id": {"$in": workshop["artist_id_list"]}
        }))
        artist_names = [artist["artist_name"] for artist in artists]
    
    # If no artists found, use the 'by' field
    if not artist_names and workshop.get("by"):
        artist_names = [workshop["by"]]
    
    # Extract date and time from time_details (using first time detail)
    date_str = "Date TBD"
    time_str = "Time TBD"
    
    if workshop.get("time_details") and len(workshop["time_details"]) > 0:
        time_detail = workshop["time_details"][0]
        if time_detail.get("day") and time_detail.get("month") and time_detail.get("year"):
            date_str = f"{time_detail['day']:02d}/{time_detail['month']:02d}/{time_detail['year']}"
        if time_detail.get("start_time"):
            end_time = time_detail.get("end_time", "")
            time_str = f"{time_detail['start_time']}"
            if end_time:
                time_str += f" - {end_time}"
    
    # Create workshop title
    title_parts = []
    if workshop.get("song"):
        title_parts.append(workshop["song"])
    if workshop.get("event_type"):
        title_parts.append(workshop["event_type"].title())
    if not title_parts:
        title_parts.append("Dance Workshop")
    
    title = " - ".join(title_parts)
    
    return WorkshopDetails(
        title=title,
        artist_names=artist_names,
        studio_name=studio_name,
        date=date_str,
        time=time_str,
        uuid=workshop["uuid"]
    )


# Bundle Management Endpoints

@router.get("/bundles/check/{workshop_uuid}")
async def check_available_bundles(workshop_uuid: str):
    """Check if there are available bundles containing a specific workshop."""
    try:
        from app.database.bundles import BundleOperations
        print(workshop_uuid)
        # Get all bundles that contain this specific workshop
        bundles = BundleOperations.get_bundles_containing_workshop(workshop_uuid)

        logger.info(f"Found {len(bundles)} bundles containing workshop {workshop_uuid}")

        # Get bundle details with pricing comparison
        bundle_details = []
        for bundle in bundles:
            # Calculate individual vs bundle pricing
            individual_prices = bundle.get("individual_workshop_prices", {})
            total_individual = sum(individual_prices.values())
            bundle_price = bundle.get("bundle_price", 0)
            savings = total_individual - bundle_price

            bundle_details.append({
                "bundle_id": bundle["bundle_id"],
                "name": bundle["name"],
                "description": bundle.get("description", ""),
                "workshop_count": len(bundle.get("workshop_ids", [])),
                "individual_total_price": total_individual,
                "bundle_price": bundle_price,
                "current_price": bundle_price / 100.0,  # Convert from paise to rupees
                "savings_amount": savings,
                "savings_percentage": round((savings / total_individual * 100), 1) if total_individual > 0 else 0,
                "pricing_info": bundle.get("pricing_info", "")
            })

        return {
            "success": True,
            "bundles_available": len(bundle_details) > 0,
            "bundles": bundle_details
        }

    except Exception as e:
        logger.error(f"Error checking bundles for workshop {workshop_uuid}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check available bundles for workshop"
        )

@router.get("/bundles/{bundle_id}")
async def get_bundle_details(bundle_id: str):
    """Get detailed information about a specific bundle."""
    try:
        from app.database.bundles import BundleOperations
    
        bundle = BundleOperations.get_bundle_with_workshop_details(bundle_id)
        if not bundle:
            raise HTTPException(status_code=404, detail="Bundle not found")

        # Calculate pricing comparison
        individual_prices = bundle.get("individual_workshop_prices", {})
        total_individual = sum(individual_prices.values())
        bundle_price = bundle.get("bundle_price", 0)
        savings = total_individual - bundle_price

        return {
            "success": True,
            "bundle": {
                "bundle_id": bundle["bundle_id"],
                "name": bundle["name"],
                "description": bundle.get("description", ""),
                "studio_id": bundle["studio_id"],
                "workshop_ids": bundle["workshop_ids"],
                "workshops": bundle.get("workshops", []),
                "individual_total_price": total_individual,
                "bundle_price": bundle_price,
                "current_price": bundle_price / 100.0,  # Convert from paise to rupees
                "savings_amount": savings,
                "savings_percentage": round((savings / total_individual * 100), 1) if total_individual > 0 else 0,
                "pricing_info": bundle.get("pricing_info", ""),
                "is_active": bundle.get("is_active", True)
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting bundle details {bundle_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get bundle details"
        )

@router.post("/bundles/{bundle_id}/create-payment-link", response_model=UnifiedPaymentLinkResponse)
async def create_bundle_payment_link(
    bundle_id: str,
    discount_amount: Optional[float] = None,  # Add rewards redemption support
    user_id: str = Depends(verify_token)
):
    """Create payment link for a bundle purchase (single order with multiple workshops)."""
    try:
        from app.database.bundles import BundleOperations
        from app.database.workshops import DatabaseOperations
        from app.database.rewards import RewardOperations

        # Get bundle details
        bundle = BundleOperations.get_bundle_with_workshop_details(bundle_id)
        if not bundle:
            raise HTTPException(status_code=404, detail="Bundle not found")

        if not bundle.get("is_active", True):
            raise HTTPException(status_code=400, detail="Bundle is not active")

        # Validate all workshops in the bundle exist
        workshop_uuids = bundle.get("workshop_ids", [])
        if not workshop_uuids:
            raise HTTPException(status_code=400, detail="Bundle contains no workshops")

        workshop_details_list = []

        for workshop_uuid in workshop_uuids:
            workshop = DatabaseOperations.get_workshop_by_uuid(workshop_uuid)
            if not workshop:
                logger.warning(f"Workshop {workshop_uuid} not found in bundle {bundle_id}")
                raise HTTPException(status_code=400, detail=f"Workshop {workshop_uuid} not found")
            workshop_details_list.append(workshop)

        logger.info(f"Creating single bundle order for {len(workshop_uuids)} workshops in bundle {bundle_id}")

        bundle_price = bundle.get("bundle_price", 0)
        if bundle_price <= 0:
            raise HTTPException(status_code=400, detail="Invalid bundle price")

        # Check for orders containing any of the workshops in this bundle and cancel them
        # This ensures we only cancel orders that conflict with the workshops being booked
        conflicting_orders = OrderOperations.get_active_orders_containing_workshops(user_id, workshop_uuids)

        if conflicting_orders:
            logger.info(f"Found {len(conflicting_orders)} order(s) containing workshops {workshop_uuids} - will cancel them")

            for conflicting_order in conflicting_orders:
                order_type = "bundle" if conflicting_order.get("is_bundle_order") else "individual"
                logger.info(f"Cancelling conflicting {order_type} order {conflicting_order['order_id']}")

                # Get the conflicting workshops for logging
                conflicting_workshops = []
                if conflicting_order.get("workshop_uuids"):
                    conflicting_workshops = [w for w in conflicting_order.get("workshop_uuids", []) if w in workshop_uuids]
                elif conflicting_order.get("workshop_uuid") and conflicting_order.get("workshop_uuid") in workshop_uuids:
                    conflicting_workshops = [conflicting_order.get("workshop_uuid")]

                logger.info(f"Order contains conflicting workshops {conflicting_workshops}: workshops={conflicting_order.get('workshop_uuids', [conflicting_order.get('workshop_uuid')])}")

                # Cancel the order's payment link
                try:
                    rp = get_razorpay_service()
                    pl_id = conflicting_order.get("payment_link_id")
                    if pl_id:
                        rp.cancel_payment_link(pl_id)
                        logger.info(f"Cancelled payment link {pl_id} for {order_type} order {conflicting_order['order_id']}")
                except Exception as e:
                    logger.warning(f"Failed to cancel payment link for {order_type} order {conflicting_order['order_id']}: {e}")

                # Rollback any pending redemptions from the order
                existing_rewards_redeemed = conflicting_order.get("rewards_redeemed")
                if existing_rewards_redeemed and existing_rewards_redeemed > 0:
                    try:
                        logger.info(f"Rolling back pending redemption of ₹{existing_rewards_redeemed} for {order_type} order {conflicting_order['order_id']}")
                        RewardOperations.rollback_pending_redemption(conflicting_order["order_id"])
                    except Exception as e:
                        logger.error(f"Failed to rollback pending redemption for {order_type} order {conflicting_order['order_id']}: {e}")

                # Mark the order as cancelled
                OrderOperations.update_order_status(
                    conflicting_order["order_id"],
                    OrderStatusEnum.CANCELLED,
                    additional_data={
                        "cancellation_reason": "replaced_by_bundle_order",
                        "old_amount": conflicting_order.get("amount", 0) / 100,
                        "new_bundle_id": bundle_id,
                        "new_bundle_name": bundle.get("name", "Bundle"),
                        "old_order_type": order_type,
                        "old_workshop_uuids": conflicting_order.get("workshop_uuids", [conflicting_order.get("workshop_uuid")]),
                        "conflicting_workshops": conflicting_workshops
                    }
                )
                logger.info(f"Cancelled {order_type} order {conflicting_order['order_id']} due to bundle order creation for workshops {workshop_uuids}")

            logger.info(f"Cancelled {len(conflicting_orders)} conflicting order(s) to create new bundle order for {bundle_id}")

        # Check if there's a specific bundle order for this bundle (after cancelling others)
        existing_bundle_order = OrderOperations.get_active_bundle_order_for_user_and_bundle(user_id, bundle_id)

        # If we still have an existing bundle order for this specific bundle, decide whether to reuse or cancel
        if existing_bundle_order:
            existing_pg = existing_bundle_order.get("payment_gateway_details") or {}
            # Use final_amount_paid if available, otherwise use payment gateway amount, otherwise use order amount
            if existing_bundle_order.get("final_amount_paid") is not None:
                existing_amount_paise = int(existing_bundle_order.get("final_amount_paid", 0) * 100)
                logger.debug(f"Using final_amount_paid for existing bundle order: ₹{existing_amount_paise/100}")
            elif existing_pg.get("amount"):
                existing_amount_paise = int(existing_pg.get("amount"))
                logger.debug(f"Using payment gateway amount for existing bundle order: ₹{existing_amount_paise/100}")
            else:
                existing_amount_paise = existing_bundle_order.get("amount", bundle_price * 100)
                logger.debug(f"Using order amount for existing bundle order: ₹{existing_amount_paise/100}")

            # Calculate intended final amount after rewards redemption
            intended_final_amount_paise = bundle_price * 100
            rewards_redeemed_rupees = 0.0

            if discount_amount and discount_amount > 0:
                discount_rupees = float(discount_amount)
                reward_balance = RewardOperations.get_user_balance(user_id)
                settings = get_settings()
                redemption_cap_percentage = getattr(settings, 'reward_redemption_cap_percentage', 10.0)
                max_discount_allowed = bundle_price * (redemption_cap_percentage / 100.0)

                if discount_rupees > reward_balance:
                    raise HTTPException(status_code=400, detail="Insufficient reward balance")

                if discount_rupees > max_discount_allowed:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of bundle amount (₹{bundle_price:.0f})"
                    )

                intended_final_amount_paise = int((bundle_price - discount_rupees) * 100)
                rewards_redeemed_rupees = discount_rupees

            # Check for various reasons to cancel and create new bundle order
            should_cancel_order = False
            cancellation_reason = ""

            # Debug: Log comparison details
            logger.info(f"Comparing existing bundle order {existing_bundle_order['order_id']} with new bundle request:")
            logger.info(f"Existing bundle: amount=₹{existing_amount_paise/100}, rewards=₹{existing_bundle_order.get('rewards_redeemed', 0)}, bundle_id={existing_bundle_order.get('bundle_id')}")
            logger.info(f"New bundle: amount=₹{intended_final_amount_paise/100}, rewards=₹{rewards_redeemed_rupees}, bundle_id={bundle_id}")

            # Check amount difference (includes rewards redemption changes)
            amount_difference = abs(intended_final_amount_paise - existing_amount_paise)
            if amount_difference > 1:  # More than 1 paisa difference
                should_cancel_order = True
                existing_rewards = existing_bundle_order.get("rewards_redeemed") or 0
                new_rewards = rewards_redeemed_rupees
                if existing_rewards != new_rewards:
                    cancellation_reason = "rewards_redemption_changed"
                    logger.info(f"Rewards redemption changed: existing=₹{existing_rewards}, requested=₹{new_rewards}")
                else:
                    cancellation_reason = "amount_changed"
                    logger.info(f"Amount changed: existing=₹{existing_amount_paise/100}, requested=₹{intended_final_amount_paise/100}, difference=₹{amount_difference/100}")

            # Check if bundle ID has changed (shouldn't happen but safety check)
            existing_bundle_id = existing_bundle_order.get("bundle_id")
            if existing_bundle_id and existing_bundle_id != bundle_id:
                should_cancel_order = True
                cancellation_reason = "bundle_changed"
                logger.info(f"Bundle changed: existing={existing_bundle_id}, requested={bundle_id}")

            # Check rewards redemption changes (even if final amount is same)
            existing_rewards = existing_bundle_order.get("rewards_redeemed") or 0
            new_rewards = rewards_redeemed_rupees
            if not should_cancel_order and existing_rewards != new_rewards:
                should_cancel_order = True
                cancellation_reason = "rewards_redemption_changed"
                logger.info(f"Rewards redemption changed: existing=₹{existing_rewards}, requested=₹{new_rewards}")
                logger.info(f"Bundle order will be cancelled to reflect updated rewards redemption")

            # Final decision summary
            logger.info(f"Bundle comparison complete - should_cancel_order: {should_cancel_order}, reason: '{cancellation_reason}'")

            if should_cancel_order:
                # Cancel old bundle link and proceed to new order
                logger.info(f"Decision: CANCEL existing bundle order due to {cancellation_reason}")
                try:
                    rp = get_razorpay_service()
                    pl_id = existing_bundle_order.get("payment_link_id")
                    if pl_id:
                        rp.cancel_payment_link(pl_id)
                except Exception as e:
                    logger.warning(f"Failed to cancel existing bundle payment link: {e}")

                # Rollback any pending redemptions from the existing bundle order
                existing_rewards_redeemed = existing_bundle_order.get("rewards_redeemed")
                if existing_rewards_redeemed and existing_rewards_redeemed > 0:
                    try:
                        logger.info(f"Rolling back pending redemption of ₹{existing_rewards_redeemed} for cancelled bundle order {existing_bundle_order['order_id']}")
                        RewardOperations.rollback_pending_redemption(existing_bundle_order["order_id"])
                    except Exception as e:
                        logger.error(f"Failed to rollback pending redemption for bundle order {existing_bundle_order['order_id']}: {e}")

                # Mark old bundle order cancelled with appropriate reason
                OrderOperations.update_order_status(
                    existing_bundle_order["order_id"],
                    OrderStatusEnum.CANCELLED,
                    additional_data={
                        "cancellation_reason": cancellation_reason,
                        "old_amount": existing_amount_paise / 100,
                        "new_amount": bundle_price,
                        "tier_info": "bundle_pricing",
                        "old_rewards_redeemed": existing_bundle_order.get("rewards_redeemed") or 0,
                        "new_rewards_redeemed": rewards_redeemed_rupees,
                        "old_bundle_id": existing_bundle_id,
                        "new_bundle_id": bundle_id
                    }
                )

                logger.info(f"Cancelled bundle order {existing_bundle_order['order_id']} due to {cancellation_reason}")
            else:
                # Same bundle order details → reuse existing link
                logger.info(f"Decision: REUSE existing bundle order {existing_bundle_order['order_id']} - all details match")
                logger.info(
                    f"Reusing pending bundle payment link for user {user_id}, bundle {bundle_id} (same order details)"
                )
                logger.info(
                    f"Bundle order details match: amount=₹{intended_final_amount_paise/100}, "
                    f"rewards=₹{rewards_redeemed_rupees}, bundle_id={bundle_id}"
                )

                # Create workshop details for the first workshop (for display purposes)
                primary_workshop_details = create_workshop_details(workshop_details_list[0])

                return UnifiedPaymentLinkResponse(
                    success=True,
                    is_existing=True,
                    message="Pending bundle payment link found for this bundle",
                    order_id=existing_bundle_order["order_id"],
                    payment_link_url=existing_bundle_order.get("payment_link_url", ""),
                    payment_link_id=existing_bundle_order.get("payment_link_id"),
                    amount=existing_bundle_order.get("final_amount_paid", existing_bundle_order.get("amount", bundle_price * 100)),
                    currency=existing_bundle_order.get("currency", "INR"),
                    expires_at=existing_bundle_order.get("expires_at"),
                    workshop_details=primary_workshop_details,
                    is_bundle=True,
                    bundle_id=bundle_id,
                    bundle_name=bundle.get("name", "Bundle"),
                    bundle_total_amount=bundle_price
                )

        # If no existing bundle order or existing order was cancelled, proceed to create new bundle order
        logger.info(f"Proceeding to create new bundle order for bundle {bundle_id}")

        # Create workshop details for the first workshop (for display purposes)
        primary_workshop_details = create_workshop_details(workshop_details_list[0])

        # Create single order for the entire bundle
        bundle_payment_id = f"BUNDLE_PAY_{bundle_id}_{user_id}_{int(datetime.now().timestamp())}"

        # Handle rewards redemption for bundle
        rewards_redeemed_rupees = 0.0
        final_amount_rupees = bundle_price
        redemption_info = None

        if discount_amount and discount_amount > 0:
            logger.info(f"Processing reward redemption for bundle {bundle_id}: ₹{discount_amount} discount")

            # Validate user has sufficient balance
            from app.config.settings import get_settings

            settings = get_settings()
            discount_rupees = float(discount_amount)
            reward_balance = RewardOperations.get_user_balance(user_id)

            redemption_cap_percentage = getattr(settings, 'reward_redemption_cap_percentage', 10.0)
            max_discount_allowed = bundle_price * (redemption_cap_percentage / 100.0)

            if discount_rupees > reward_balance:
                raise HTTPException(status_code=400, detail="Insufficient reward balance")

            if discount_rupees > max_discount_allowed:
                raise HTTPException(
                    status_code=400,
                    detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of bundle amount (₹{bundle_price:.0f})"
                )

            # Apply discount
            final_amount_rupees = bundle_price - discount_rupees
            rewards_redeemed_rupees = discount_rupees

            logger.info(f"Applied reward discount to bundle: ₹{discount_rupees} → Final amount: ₹{final_amount_rupees:.0f}")

            # Store redemption info for later processing
            redemption_info = {
                'points_redeemed': discount_rupees,
                'discount_amount': discount_rupees,
                'original_amount': bundle_price,
                'final_amount': final_amount_rupees
            }

        order_create = OrderCreate(
            user_id=user_id,
            workshop_uuids=workshop_uuids,  # Multiple workshops
            workshop_details=primary_workshop_details,
            amount=int(bundle_price * 100),  # Convert original bundle price to paise
            currency="INR",
            rewards_redeemed=rewards_redeemed_rupees if rewards_redeemed_rupees > 0 else None,
            final_amount_paid=final_amount_rupees,  # Final amount after rewards redemption
            bundle_id=bundle_id,
            bundle_payment_id=bundle_payment_id,
            is_bundle_order=True,
            bundle_total_workshops=len(workshop_uuids),
            bundle_total_amount=final_amount_rupees  # Use final amount for display
        )

        # Save single order
        order_id = OrderOperations.create_order(order_create)
        logger.info(f"Created single bundle order {order_id} for bundle {bundle_id}")

        # Handle rewards redemption for bundle orders
        if rewards_redeemed_rupees > 0 and redemption_info is not None:
            try:
                from app.database.rewards import RewardOperations

                # For bundles, create a single pending redemption for the entire bundle
                redemption_id = RewardOperations.create_pending_redemption(
                    user_id=user_id,
                    order_id=order_id,
                    workshop_uuid=bundle_id,  # Use bundle_id as workshop_uuid for bundle orders
                    points_redeemed=redemption_info['points_redeemed'],
                    discount_amount=redemption_info['discount_amount'],
                    original_amount=redemption_info['original_amount'],
                    final_amount=redemption_info['final_amount']
                )

                logger.info(f"Created pending redemption for bundle {bundle_id}: {redemption_id} - ₹{redemption_info['points_redeemed']} reserved")
            except Exception as e:
                logger.error(f"Failed to create pending redemption for bundle order {order_id}: {e}")
                # If redemption setup fails, we should cancel the order
                try:
                    OrderOperations.update_order_status(order_id, OrderStatusEnum.FAILED)
                except Exception as cleanup_error:
                    logger.error(f"Failed to cleanup failed order {order_id}: {cleanup_error}")

                raise HTTPException(
                    status_code=500,
                    detail="Failed to setup reward redemption - order cancelled"
                )

        # Get user details for payment link
        user = UserOperations.get_user_by_id(user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        # Create payment link for the bundle
        razorpay_service = get_razorpay_service()

        # Prepare user details for Razorpay
        user_name = user.get("name") or "Customer"
        user_email = f"{user['mobile_number']}@nachna.com"  # Placeholder email
        user_phone = f"+91{user['mobile_number']}"

        # Create payment link using the correct method
        payment_link_data = razorpay_service.create_order_payment_link(
            order_id=order_id,
            amount=int(final_amount_rupees * 100),  # Use final amount after rewards redemption
            user_name=user_name,
            user_email=user_email,
            user_phone=user_phone,
            workshop_title=f"Bundle Payment - {bundle.get('name', 'Bundle')}" + (f" (₹{rewards_redeemed_rupees} reward discount applied)" if rewards_redeemed_rupees > 0 else ""),
            expire_by_mins=20  # 20 minute expiry
        )

        # Update order with payment link details
        expires_at = datetime.fromtimestamp(payment_link_data["expire_by"])

        success = OrderOperations.update_order_payment_link(
            order_id=order_id,
            payment_link_id=payment_link_data["id"],
            payment_link_url=payment_link_data["short_url"],
            expires_at=expires_at,
            payment_gateway_details=payment_link_data
        )

        if not success:
            logger.error(f"Failed to update payment link for bundle order {order_id}")
            raise HTTPException(status_code=500, detail="Failed to update payment link")

        logger.info(f"Created bundle payment link {payment_link_data['id']} for single order {order_id}")

        return UnifiedPaymentLinkResponse(
            success=True,
            message=f"Bundle payment link created for {bundle.get('name', 'Bundle')}" + (f" with ₹{rewards_redeemed_rupees} reward discount" if rewards_redeemed_rupees > 0 else ""),
            order_id=order_id,
            payment_link_url=payment_link_data["short_url"],
            payment_link_id=payment_link_data["id"],
            amount=int(final_amount_rupees * 100),  # Final amount after rewards redemption
            currency="INR",
            expires_at=expires_at,
            workshop_details=primary_workshop_details,
            is_bundle=True,
            bundle_id=bundle_id,
            bundle_name=bundle.get("name", "Bundle"),
            bundle_total_amount=final_amount_rupees  # Use final amount
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating bundle payment link: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create bundle payment link"
        )





@router.get("/bundles/{bundle_id}")
async def get_bundle_details(bundle_id: str, user_id: str = Depends(verify_token)):
    """Get details of a specific bundle."""
    try:
        from app.database.bundles import BundleOperations

        # Get bundle from database
        bundle = BundleOperations.get_bundle_by_id(bundle_id)
        if not bundle:
            raise HTTPException(status_code=404, detail="Bundle not found")

        # Verify user has access to this bundle
        if bundle["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Access denied")

        # Get member orders with workshop details
        member_orders = BundleOperations.get_bundle_member_orders(bundle_id)

        # Format response
        bundle_info = {
            "bundle_id": bundle["bundle_id"],
            "name": bundle["name"],
            "member_orders": [
                {
                    "order_id": order["order_id"],
                    "workshop_name": order.get("workshop_details", {}).get("title", "Unknown Workshop"),
                    "status": order.get("status", "unknown"),
                    "position": order.get("bundle_position", 0)
                }
                for order in member_orders
            ],
            "total_amount": bundle["total_amount"],
            "status": bundle["status"],
            "created_at": bundle.get("created_at"),
            "completed_at": bundle.get("completed_at")
        }

        return bundle_info

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching bundle details: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch bundle details"
        )


@router.post("/create-payment-link", response_model=UnifiedPaymentLinkResponse)
async def create_payment_link(
    request: CreatePaymentLinkRequest,
    user_id: str = Depends(verify_token)
):
    """Create a payment link for a workshop.
    
    This endpoint:
    1. Validates the workshop exists and extracts pricing
    2. Checks for existing pending payment links (status=CREATED only)
    3. Creates a new order and Razorpay payment link
    4. Stores the order in database
    5. Returns payment link details
    
    Note: Users who have successfully paid (status=PAID) can make new bookings.
    Only pending payments (status=CREATED) are considered duplicates.
    """
    async def internal_create_payment_link(request: CreatePaymentLinkRequest, user_id: str):
        try:
            logger.info(f"Creating payment link for workshop {request.workshop_uuid}, user {user_id}")
            
            # 1. Get workshop details and validate
            workshop = get_workshop_by_uuid(request.workshop_uuid)
            logger.info(f"Fetched workshop data for {request.workshop_uuid}: title='{workshop.get('song') or workshop.get('title')}', artist='{workshop.get('by')}'")
            
            # 2. Extract pricing information with tiered pricing support
            if not workshop.get("pricing_info"):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Workshop pricing information not available"
                )

            try:
                pricing_result = parse_tiered_pricing(workshop["pricing_info"], request.workshop_uuid, user_id)
                amount_paise = pricing_result['amount_paise']
                tier_info = pricing_result['tier_info']
                is_early_bird = pricing_result['is_early_bird']
                pricing_changed = pricing_result['pricing_changed']
                # Note: bundle_info is still parsed but not used for suggestions here
                # Bundle selection is handled through separate bundle APIs

            except ValueError as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=str(e)
                )
            
            # 3. Check for existing pending payment link
            # For bundle orders, we need to handle workshop_uuids differently
            workshop_uuids = [request.workshop_uuid] if not hasattr(request, 'workshop_uuids') or not request.workshop_uuids else request.workshop_uuids
            is_bundle_order = getattr(request, 'is_bundle_order', False)

            # Check for existing orders that might conflict
            existing_order = OrderOperations.get_active_order_for_user_workshops(
                user_id, workshop_uuids, is_bundle_order
            )

            # If no direct match found and this is an individual order, cancel orders containing this workshop
            if not existing_order and not is_bundle_order and len(workshop_uuids) == 1:
                # Check for orders containing this specific workshop UUID and cancel them
                conflicting_orders = OrderOperations.get_active_orders_containing_workshop(user_id, workshop_uuids[0])
                if conflicting_orders:
                    logger.info(f"Found {len(conflicting_orders)} order(s) containing workshop {workshop_uuids[0]} - will cancel them")

                    for conflicting_order in conflicting_orders:
                        order_type = "bundle" if conflicting_order.get("is_bundle_order") else "individual"
                        logger.info(f"Cancelling conflicting {order_type} order {conflicting_order['order_id']}")
                        logger.info(f"Order contains workshop {workshop_uuids[0]}: workshops={conflicting_order.get('workshop_uuids', [conflicting_order.get('workshop_uuid')])}")

                        # Cancel the order's payment link
                        try:
                            rp = get_razorpay_service()
                            pl_id = conflicting_order.get("payment_link_id")
                            if pl_id:
                                rp.cancel_payment_link(pl_id)
                                logger.info(f"Cancelled payment link {pl_id} for {order_type} order {conflicting_order['order_id']}")
                        except Exception as e:
                            logger.warning(f"Failed to cancel payment link for {order_type} order {conflicting_order['order_id']}: {e}")

                        # Rollback any pending redemptions from the order
                        existing_rewards_redeemed = conflicting_order.get("rewards_redeemed")
                        if existing_rewards_redeemed and existing_rewards_redeemed > 0:
                            try:
                                logger.info(f"Rolling back pending redemption of ₹{existing_rewards_redeemed} for {order_type} order {conflicting_order['order_id']}")
                                RewardOperations.rollback_pending_redemption(conflicting_order["order_id"])
                            except Exception as e:
                                logger.error(f"Failed to rollback pending redemption for {order_type} order {conflicting_order['order_id']}: {e}")

                        # Mark the order as cancelled
                        OrderOperations.update_order_status(
                            conflicting_order["order_id"],
                            OrderStatusEnum.CANCELLED,
                            additional_data={
                                "cancellation_reason": "replaced_by_individual_order",
                                "old_amount": conflicting_order.get("amount", 0) / 100,
                                "new_workshop_uuid": workshop_uuids[0],
                                "old_order_type": order_type,
                                "old_workshop_uuids": conflicting_order.get("workshop_uuids", [conflicting_order.get("workshop_uuid")])
                            }
                        )
                        logger.info(f"Cancelled {order_type} order {conflicting_order['order_id']} due to individual order creation for workshop {workshop_uuids[0]}")

                    logger.info(f"Cancelled {len(conflicting_orders)} conflicting order(s) to create individual order for workshop {workshop_uuids[0]}")
            
            # Determine intended final amount (after discount if any)
            intended_final_amount_paise = amount_paise
            rewards_redeemed_rupees = 0.0
            order_amount_rupees = amount_paise / 100.0
            final_amount_rupees = order_amount_rupees  # Initialize with original amount
            
            if request.discount_amount and request.discount_amount > 0:
                # Perform validation similar to below to compute final amount safely
                from app.database.rewards import RewardOperations
                from app.config.settings import get_settings as _get_settings
                _settings = _get_settings()
                discount_rupees = float(request.discount_amount)
                reward_balance = RewardOperations.get_user_balance(user_id)
                redemption_cap_percentage = getattr(_settings, 'reward_redemption_cap_percentage', 10.0)
                max_discount_allowed = order_amount_rupees * (redemption_cap_percentage / 100.0)
                redemption_cap_per_workshop = getattr(_settings, 'reward_redemption_cap_per_workshop', 50.0)
                if discount_rupees > reward_balance:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient reward balance")
                if discount_rupees > max_discount_allowed:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of order amount (₹{order_amount_rupees:.0f})")
                if discount_rupees > redemption_cap_per_workshop:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Discount amount (₹{discount_rupees}) cannot exceed ₹{redemption_cap_per_workshop} per workshop")
                final_amount_rupees = order_amount_rupees - discount_rupees
                intended_final_amount_paise = int(final_amount_rupees * 100)
                rewards_redeemed_rupees = discount_rupees

            # If we have an existing pending order, decide whether to reuse or cancel
            if existing_order:
                existing_pg = existing_order.get("payment_gateway_details") or {}
                # Use final_amount_paid if available, otherwise use payment gateway amount, otherwise use order amount
                if existing_order.get("final_amount_paid") is not None:
                    existing_amount_paise = int(existing_order.get("final_amount_paid", 0) * 100)
                    logger.debug(f"Using final_amount_paid for existing order: ₹{existing_amount_paise/100}")
                elif existing_pg.get("amount"):
                    existing_amount_paise = int(existing_pg.get("amount"))
                    logger.debug(f"Using payment gateway amount for existing order: ₹{existing_amount_paise/100}")
                else:
                    existing_amount_paise = existing_order.get("amount", amount_paise)
                    logger.debug(f"Using order amount for existing order: ₹{existing_amount_paise/100}")

                # Check for various reasons to cancel and create new order
                should_cancel_order = False
                cancellation_reason = ""

                # Debug: Log comparison details
                logger.info(f"Comparing existing order {existing_order['order_id']} with new request:")
                existing_is_bundle = existing_order.get("is_bundle_order", False)  # Define before using in logging
                logger.info(f"Existing: amount=₹{existing_amount_paise/100}, rewards=₹{existing_order.get('rewards_redeemed', 0)}, bundle={existing_is_bundle}, tier='{existing_order.get('tier_info', '')}'")
                logger.info(f"New: amount=₹{intended_final_amount_paise/100}, rewards=₹{rewards_redeemed_rupees}, bundle={is_bundle_order}, tier='{tier_info}'")

                # Check amount difference (includes rewards redemption changes)
                # Allow small tolerance for rounding differences
                amount_difference = abs(intended_final_amount_paise - existing_amount_paise)
                if amount_difference > 1:  # More than 1 paisa difference
                    should_cancel_order = True
                    existing_rewards = existing_order.get("rewards_redeemed") or 0
                    new_rewards = rewards_redeemed_rupees
                    if existing_rewards != new_rewards:
                        cancellation_reason = "rewards_redemption_changed"
                        logger.info(f"Rewards redemption changed: existing=₹{existing_rewards}, requested=₹{new_rewards}")
                    else:
                        cancellation_reason = "amount_changed"
                        logger.info(f"Amount changed: existing=₹{existing_amount_paise/100}, requested=₹{intended_final_amount_paise/100}, difference=₹{amount_difference/100}")

                # Check bundle vs individual order type difference
                if is_bundle_order != existing_is_bundle:
                    should_cancel_order = True
                    cancellation_reason = "order_type_changed"
                    logger.info(f"Order type mismatch: existing={existing_is_bundle}, requested={is_bundle_order}")

                # Check workshop UUID differences (for bundles)
                if is_bundle_order and existing_is_bundle:
                    existing_workshop_uuids = existing_order.get("workshop_uuids", [])
                    if set(workshop_uuids) != set(existing_workshop_uuids):
                        should_cancel_order = True
                        cancellation_reason = "bundle_workshops_changed"
                        logger.info(f"Bundle workshops changed: existing={existing_workshop_uuids}, requested={workshop_uuids}")

                # Skip tier pricing comparison to avoid false cancellations
                # Tier info can change based on time/availability and shouldn't prevent reuse
                # Only cancel if there are actual substantive changes (amount, bundle structure, rewards)

                # Check rewards redemption changes (even if final amount is same)
                # This ensures we always reflect the most current rewards usage
                existing_rewards = existing_order.get("rewards_redeemed") or 0
                new_rewards = rewards_redeemed_rupees
                if not should_cancel_order and existing_rewards != new_rewards:
                    should_cancel_order = True
                    cancellation_reason = "rewards_redemption_changed"
                    logger.info(f"Rewards redemption changed: existing=₹{existing_rewards}, requested=₹{new_rewards}")
                    logger.info(f"Order will be cancelled to reflect updated rewards redemption")

                # Final decision summary
                logger.info(f"Comparison complete - should_cancel_order: {should_cancel_order}, reason: '{cancellation_reason}'")

                if should_cancel_order:
                    # Cancel old link and proceed to new order
                    logger.info(f"Decision: CANCEL existing order due to {cancellation_reason}")
                    try:
                        rp = get_razorpay_service()
                        pl_id = existing_order.get("payment_link_id")
                        if pl_id:
                            rp.cancel_payment_link(pl_id)
                    except Exception as e:
                        logger.warning(f"Failed to cancel existing payment link: {e}")

                    # Rollback any pending redemptions from the existing order
                    existing_rewards_redeemed = existing_order.get("rewards_redeemed")
                    if existing_rewards_redeemed and existing_rewards_redeemed > 0:
                        try:
                            logger.info(f"Rolling back pending redemption of ₹{existing_rewards_redeemed} for cancelled order {existing_order['order_id']}")
                            RewardOperations.rollback_pending_redemption(existing_order["order_id"])
                        except Exception as e:
                            logger.error(f"Failed to rollback pending redemption for order {existing_order['order_id']}: {e}")

                    # Mark old order cancelled with appropriate reason
                    OrderOperations.update_order_status(
                        existing_order["order_id"],
                        OrderStatusEnum.CANCELLED,
                        additional_data={
                            "cancellation_reason": cancellation_reason,
                            "old_amount": existing_amount_paise / 100,
                            "new_amount": amount_paise / 100,
                            "old_final_amount": (existing_order.get("final_amount_paid") or existing_order.get("amount", 0)) / 100,
                            "new_final_amount": final_amount_rupees,
                            "tier_info": tier_info,
                            "old_rewards_redeemed": existing_order.get("rewards_redeemed") or 0,
                            "new_rewards_redeemed": rewards_redeemed_rupees,
                            "old_workshop_uuids": existing_order.get("workshop_uuids", [existing_order.get("workshop_uuid")]),
                            "new_workshop_uuids": workshop_uuids,
                            "old_is_bundle": existing_is_bundle,
                            "new_is_bundle": is_bundle_order
                        }
                    )

                    logger.info(f"Cancelled order {existing_order['order_id']} due to {cancellation_reason}")
                else:
                    # Same order details → reuse existing link
                    logger.info(f"Decision: REUSE existing order {existing_order['order_id']} - all details match")
                    logger.info(
                        f"Reusing pending payment link for user {user_id}, workshops {workshop_uuids} (same order details)"
                    )
                    logger.info(
                        f"Order details match: amount=₹{intended_final_amount_paise/100}, "
                        f"rewards=₹{rewards_redeemed_rupees}, bundle={is_bundle_order}, tier='{tier_info}'"
                    )
                    workshop_details = create_workshop_details(workshop)
                    logger.info(f"Reusing order {existing_order['order_id']} with workshop details: {workshop_details.title}")

                    return UnifiedPaymentLinkResponse(
                        is_existing=True,
                        message="Pending payment link found for this workshop",
                        order_id=existing_order["order_id"],
                        payment_link_url=existing_order.get("payment_link_url", ""),
                        payment_link_id=existing_order.get("payment_link_id"),
                        amount=existing_order.get("final_amount_paid", existing_order.get("amount", amount_paise)),
                        currency=existing_order.get("currency", "INR"),
                        expires_at=existing_order.get("expires_at"),
                        workshop_details=workshop_details,
                        tier_info=tier_info,
                        is_early_bird=is_early_bird,
                        pricing_changed=pricing_changed
                    )
            
            # 4. Handle reward redemption if provided
            final_amount_paise = intended_final_amount_paise

            # Initialize redemption_info outside the conditional block
            redemption_info = None

            if rewards_redeemed_rupees > 0:
                logger.info(f"Processing reward redemption: ₹{request.discount_amount} discount for user {user_id}")

                # Validate and process redemption using rewards service
                from app.database.rewards import RewardOperations
                from app.config.settings import get_settings

                settings = get_settings()

                # Convert discount amount to rupees if needed (ensure it's in rupees)
                discount_rupees = rewards_redeemed_rupees

                # Validate user has sufficient balance (excluding pending redemptions)
                try:
                    reward_balance = RewardOperations.get_available_balance_for_redemption(user_id)
                    if reward_balance < discount_rupees:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Insufficient reward balance. Available: ₹{reward_balance}, Requested: ₹{discount_rupees}"
                        )
                    
                    # Validate against configurable redemption cap percentage
                    redemption_cap_percentage = getattr(settings, 'reward_redemption_cap_percentage', 10.0)
                    max_discount_allowed = order_amount_rupees * (redemption_cap_percentage / 100.0)
                    
                    if discount_rupees > max_discount_allowed:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Discount amount (₹{discount_rupees}) cannot exceed {redemption_cap_percentage}% of order amount (₹{order_amount_rupees:.0f})"
                        )
                    
                    # Validate against absolute redemption cap
                    redemption_cap_per_workshop = getattr(settings, 'reward_redemption_cap_per_workshop', 50.0)
                    if discount_rupees > redemption_cap_per_workshop:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"Discount amount (₹{discount_rupees}) cannot exceed ₹{redemption_cap_per_workshop} per workshop"
                        )
                    
                    # Apply discount
                    final_amount_rupees = order_amount_rupees - discount_rupees
                    final_amount_paise = int(final_amount_rupees * 100)

                    logger.info(f"Applied reward discount: ₹{discount_rupees} → Final amount: ₹{final_amount_rupees:.0f}")

                    # Store redemption info for later processing (after order creation)
                    redemption_info = {
                        'points_redeemed': discount_rupees,
                        'discount_amount': discount_rupees,
                        'original_amount': order_amount_rupees,
                        'final_amount': final_amount_rupees
                    }

                except HTTPException:
                    raise
                except Exception as e:
                    logger.error(f"Error processing reward redemption: {e}")
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Failed to process reward redemption"
                    )
            
            # 5. Get user details for payment link
            user = UserOperations.get_user_by_id(user_id)
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found"
                )
            
            # 6. Create workshop details object
            workshop_details = create_workshop_details(workshop)
            logger.info(f"Created workshop details for workshop {request.workshop_uuid}: {workshop_details.title}")

            # Validate that we're using the correct workshop details
            if existing_order and existing_order.get("is_bundle_order"):
                logger.info(f"Validating workshop details for transition from bundle to individual")
                logger.info(f"Bundle workshops: {existing_order.get('workshop_uuids')}")
                logger.info(f"Individual workshop: {request.workshop_uuid}")
                if request.workshop_uuid not in existing_order.get("workshop_uuids", []):
                    logger.warning(f"Workshop {request.workshop_uuid} not found in bundle {existing_order['order_id']}")
                else:
                    logger.info(f"Workshop {request.workshop_uuid} confirmed in bundle - proceeding with individual order creation")
            
            # 7. Create order in database with redemption info
            order_data = OrderCreate(
                user_id=user_id,
                workshop_uuids=workshop_uuids,  # Use the workshop_uuids list (supports bundles)
                workshop_details=workshop_details,
                amount=amount_paise,  # Original amount in paise
                currency="INR",
                rewards_redeemed=rewards_redeemed_rupees if rewards_redeemed_rupees > 0 else None,
                final_amount_paid=final_amount_rupees,  # Always set the final amount paid
                is_bundle_order=is_bundle_order,  # Add bundle order flag
                bundle_id=getattr(request, 'bundle_id', None),  # Add bundle ID if available
                bundle_total_workshops=len(workshop_uuids) if is_bundle_order else None,
                bundle_total_amount=amount_paise / 100 if is_bundle_order else None
            )
            
            order_id = OrderOperations.create_order(order_data)
            logger.info(f"Created order {order_id} for user {user_id}")
            logger.info(f"New order details: workshop_uuids={workshop_uuids}, is_bundle={is_bundle_order}, amount=₹{amount_paise/100}, final_amount=₹{final_amount_rupees}")
            logger.info(f"Order data saved: rewards_redeemed={order_data.rewards_redeemed}, final_amount_paid={order_data.final_amount_paid}")

            # If this was created after cancelling a bundle order, log the transition
            if existing_order and existing_order.get("is_bundle_order"):
                logger.info(f"Transitioned from bundle order {existing_order['order_id']} to individual order {order_id}")
                logger.info(f"Original bundle: workshops={existing_order.get('workshop_uuids')}, is_bundle={existing_order.get('is_bundle_order')}")
                logger.info(f"New individual: workshop={workshop_uuids[0]}, workshop_details_title='{workshop_details.title}'")

            # Store redemption info in order for later processing (after payment success)
            # Do NOT deduct rewards immediately - this will be done after payment is confirmed
            if rewards_redeemed_rupees > 0 and redemption_info is not None:
                try:
                    # Create pending redemption record without deducting balance
                    # This prevents double-booking while keeping rewards available until payment
                    # For bundles, we need to create pending redemptions for each workshop
                    if is_bundle_order:
                        for workshop_uuid in workshop_uuids:
                            redemption_id = RewardOperations.create_pending_redemption(
                                user_id=user_id,
                                order_id=order_id,
                                workshop_uuid=workshop_uuid,
                                points_redeemed=redemption_info['points_redeemed'] / len(workshop_uuids),  # Split across workshops
                                discount_amount=redemption_info['discount_amount'] / len(workshop_uuids),
                                original_amount=redemption_info['original_amount'] / len(workshop_uuids),
                                final_amount=redemption_info['final_amount'] / len(workshop_uuids)
                            )
                    else:
                        redemption_id = RewardOperations.create_pending_redemption(
                            user_id=user_id,
                            order_id=order_id,
                            workshop_uuid=workshop_uuids[0],
                            points_redeemed=redemption_info['points_redeemed'],
                            discount_amount=redemption_info['discount_amount'],
                            original_amount=redemption_info['original_amount'],
                            final_amount=redemption_info['final_amount']
                        )

                    logger.info(f"Pending redemption created: {redemption_id} - ₹{redemption_info['points_redeemed']} reserved for user {user_id} (will be deducted after payment)")
                except Exception as e:
                    logger.error(f"Failed to create pending redemption for order {order_id}: {e}")
                    # If redemption setup fails, we should cancel the order
                    try:
                        OrderOperations.update_order_status(order_id, OrderStatusEnum.FAILED)
                    except Exception as cleanup_error:
                        logger.error(f"Failed to cleanup failed order {order_id}: {cleanup_error}")

                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Failed to setup reward redemption - order cancelled"
                    )

            # 7. Create Razorpay payment link
            razorpay_service = get_razorpay_service()
            
            # Prepare user details for Razorpay
            user_name = user.get("name") or "Customer"
            user_email = f"{user['mobile_number']}@nachna.com"  # Placeholder email
            user_phone = f"+91{user['mobile_number']}"
            
            # Update workshop title to show discount if applied
            payment_title = workshop_details.title
            if rewards_redeemed_rupees > 0:
                payment_title += f" (₹{rewards_redeemed_rupees} reward discount applied)"
            
            try:
                razorpay_response = razorpay_service.create_order_payment_link(
                    order_id=order_id,
                    amount=final_amount_paise,  # Use final amount after discount
                    user_name=user_name,
                    user_email=user_email,
                    user_phone=user_phone,
                    workshop_title=payment_title,
                    expire_by_mins=20  # 20 minute expiry
                )
                
                logger.info(f"Created Razorpay payment link {razorpay_response['id']} for order {order_id}")
                
            except Exception as e:
                logger.error(f"Failed to create Razorpay payment link for order {order_id}: {str(e)}")
                # Clean up the order if payment link creation fails
                OrderOperations.update_order_status(order_id, OrderStatusEnum.FAILED)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to create payment link"
                )
            
            # 8. Update order with payment link details
            expires_at = datetime.fromtimestamp(razorpay_response["expire_by"])
            
            success = OrderOperations.update_order_payment_link(
                order_id=order_id,
                payment_link_id=razorpay_response["id"],
                payment_link_url=razorpay_response["short_url"],
                expires_at=expires_at,
                payment_gateway_details=razorpay_response
            )
            
            if not success:
                logger.error(f"Failed to update order {order_id} with payment link details")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to save payment link details"
                )
            
            # 9. Return success response
            logger.info(f"Returning payment link response for order {order_id}: amount=₹{final_amount_paise/100}, workshop='{workshop_details.title}'")
            return UnifiedPaymentLinkResponse(
                is_existing=False,
                message="Payment link created successfully" + (f" with ₹{rewards_redeemed_rupees} reward discount" if rewards_redeemed_rupees > 0 else ""),
                order_id=order_id,
                payment_link_url=razorpay_response["short_url"],
                payment_link_id=razorpay_response["id"],
                amount=final_amount_paise,  # Use final amount after rewards redemption
                currency="INR",
                expires_at=expires_at,
                workshop_details=workshop_details,
                tier_info=tier_info,
                is_early_bird=is_early_bird,
                pricing_changed=pricing_changed
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Unexpected error creating payment link: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error"
            )
    try:
        return await internal_create_payment_link(request, user_id)
    except:
        return await internal_create_payment_link(request, user_id)

@router.get("/{order_id}/status")
async def get_order_status(
    order_id: str
):
    """Get status of a specific order.

    This endpoint returns order details with current status from internal database.
    No authentication required - accessible by anyone with the order ID.

    Args:
        order_id: The order ID to check

    Returns:
        Order details with current status from internal database
    """
    try:
        logger.info(f"Getting order status for order {order_id}")

        # Get the specific order
        order = OrderOperations.get_order_by_id(order_id)

        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Order not found"
            )
        
        # Handle both single workshop and bundle orders
        workshop_uuids = order.get("workshop_uuids", [])
        if not workshop_uuids and order.get("workshop_uuid"):
            # For backward compatibility with old single workshop orders
            workshop_uuids = [order["workshop_uuid"]]

        # Debug: Log workshop UUIDs and QR codes data
        qr_codes_data = order.get("qr_codes_data", {})
        logger.info(f"Order {order_id}: workshop_uuids = {workshop_uuids}")
        logger.info(f"Order {order_id}: qr_codes_data keys = {list(qr_codes_data.keys()) if qr_codes_data else 'None'}")
        logger.info(f"Order {order_id}: is_bundle_order = {order.get('is_bundle_order', False)}")

        # Check for missing data
        if not workshop_uuids:
            logger.warning(f"Order {order_id}: No workshop UUIDs found!")
        if not qr_codes_data:
            logger.warning(f"Order {order_id}: No QR codes data found!")
        else:
            # Check if we have QR codes for all workshop UUIDs
            missing_qr_uuids = [uuid for uuid in workshop_uuids if uuid not in qr_codes_data]
            if missing_qr_uuids:
                logger.warning(f"Order {order_id}: Missing QR codes for workshop UUIDs: {missing_qr_uuids}")
            else:
                logger.info(f"Order {order_id}: All workshop UUIDs have QR codes")

        # Get bundle information if this is a bundle order
        bundle_info = None
        if order.get("is_bundle_order"):
            try:
                from app.database.bundles import BundleOperations
                bundle_details = BundleOperations.get_bundle_with_workshop_details(order.get("bundle_id"))
                if bundle_details:
                    # Process workshops and create typed BundleWorkshopInfo objects
                    workshops = bundle_details.get("workshops", [])
                    bundle_workshops = []
                    for workshop in workshops:
                        # Convert ObjectIds to strings
                        processed_workshop = {}
                        for key, value in workshop.items():
                            if hasattr(value, '__class__') and 'ObjectId' in str(type(value)):
                                processed_workshop[key] = str(value)
                            else:
                                processed_workshop[key] = value

                        # Create BundleWorkshopInfo instance
                        bundle_workshop = BundleWorkshopInfo(
                            song=processed_workshop.get("song"),
                            title=processed_workshop.get("title") or processed_workshop.get("song"),
                            artist_names=processed_workshop.get("artist_names"),
                            by=processed_workshop.get("by"),
                            studio_name=processed_workshop.get("studio_name"),
                            date=processed_workshop.get("date"),
                            time=processed_workshop.get("time")
                        )
                        bundle_workshops.append(bundle_workshop)

                    # Calculate savings amount
                    individual_prices = bundle_details.get("individual_workshop_prices", {})
                    bundle_price = bundle_details.get("bundle_price", 0)
                    savings_amount = float(sum(individual_prices.values()) - bundle_price) if individual_prices else 0.0

                    # Create typed BundleInfo object
                    bundle_info = BundleInfo(
                        name=bundle_details.get("name", "Bundle"),
                        description=bundle_details.get("description", ""),
                        workshops=bundle_workshops,
                        savings_amount=savings_amount
                    )
            except Exception as e:
                logger.warning(f"Failed to get bundle details for order {order['order_id']}: {e}")

        # Fetch workshop details for QR code titles (for both bundle and non-bundle orders)
        workshop_details_map = {}
        if workshop_uuids:
            try:
                from app.database.workshops import DatabaseOperations as WorkshopDB
                for workshop_uuid in workshop_uuids:
                    try:
                        workshop = WorkshopDB.get_workshop_by_uuid(workshop_uuid)
                        if workshop:
                            workshop_details_map[workshop_uuid] = {
                                'song': workshop.get('song'),
                                'title': workshop.get('title') or workshop.get('song'),
                                'artist_names': workshop.get('artist_names'),
                                'by': workshop.get('by'),
                                'studio_name': workshop.get('studio_name'),
                                'date': workshop.get('date'),
                                'time': workshop.get('time'),
                                'event_type': workshop.get('event_type')
                            }
                            logger.info(f"Fetched workshop details for {workshop_uuid}: {workshop_details_map[workshop_uuid]['song']}")
                        else:
                            logger.warning(f"Workshop not found: {workshop_uuid}")
                    except Exception as e:
                        logger.warning(f"Failed to fetch workshop {workshop_uuid}: {e}")
            except Exception as e:
                logger.warning(f"Failed to fetch workshop details for order {order['order_id']}: {e}")

        # Return order details
        order_response = OrderResponse(
            order_id=order["order_id"],
            workshop_uuids=workshop_uuids,
            workshop_details=WorkshopDetails(**order["workshop_details"]),
            amount=order["amount"],
            currency=order["currency"],
            status=OrderStatusEnum(order["status"]),
            payment_link_url=order.get("payment_link_url"),
            qr_codes_data=qr_codes_data,  # Include QR codes data
            qr_code_generated_at=order.get("qr_code_generated_at"),
            # Reward-related fields
            cashback_amount=order.get("cashback_amount"),
            rewards_redeemed=order.get("rewards_redeemed"),
            final_amount_paid=order.get("final_amount_paid"),
            # Bundle-related fields
            bundle_id=order.get("bundle_id"),
            bundle_payment_id=order.get("bundle_payment_id"),
            is_bundle_order=order.get("is_bundle_order", False),
            bundle_total_workshops=order.get("bundle_total_workshops"),
            bundle_total_amount=order.get("bundle_total_amount"),
            bundle_info=bundle_info,
            workshop_details_map=workshop_details_map,
            created_at=order["created_at"],
            updated_at=order["updated_at"]
        )
        
        logger.info(f"Order {order_id} status: {order['status']}")
        return {
            "success": True,
            "order": order_response
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting order status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve order status"
        )


@router.get("/user", response_model=UserOrdersResponse)
async def get_user_orders(
    status: Optional[str] = Query(None, description="Comma-separated list of order statuses to filter by"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of orders to return"),
    offset: int = Query(0, ge=0, description="Number of orders to skip"),
    user_id: str = Depends(verify_token)
):
    """Get orders for the authenticated user.
    
    Query Parameters:
    - status: Optional comma-separated list of statuses (e.g., "paid,created")
    - limit: Maximum number of orders to return (1-100, default 20)
    - offset: Number of orders to skip for pagination (default 0)
    """
    try:
        logger.info(f"Getting orders for user {user_id}, status: {status}, limit: {limit}, offset: {offset}")
        
        # Parse status filter
        status_filter = None
        if status:
            status_list = [s.strip() for s in status.split(",")]
            # Validate statuses
            valid_statuses = [s.value for s in OrderStatusEnum]
            invalid_statuses = [s for s in status_list if s not in valid_statuses]
            if invalid_statuses:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid status values: {invalid_statuses}. Valid values: {valid_statuses}"
                )
            status_filter = status_list
        
        # Default behavior: exclude cancelled orders from regular list
        if status_filter is None:
            status_filter = [s.value for s in OrderStatusEnum if s != OrderStatusEnum.CANCELLED]

        # Get orders from database
        orders = OrderOperations.get_user_orders(
            user_id=user_id,
            status_filter=status_filter,
            limit=limit,
            offset=offset
        )
        
        # Get total count for pagination
        total_count = OrderOperations.get_user_orders_count(
            user_id=user_id,
            status_filter=status_filter
        )
        
        # Convert to response format
        order_responses = []
        for order in orders:
            # Handle both single workshop and bundle orders
            workshop_uuids = order.get("workshop_uuids", [])
            if not workshop_uuids and order.get("workshop_uuid"):
                # For backward compatibility with old single workshop orders
                workshop_uuids = [order["workshop_uuid"]]

            # Get bundle information if this is a bundle order
            bundle_info = None
            if order.get("is_bundle_order"):
                try:
                    from app.database.bundles import BundleOperations
                    bundle_details = BundleOperations.get_bundle_with_workshop_details(order.get("bundle_id"))
                    if bundle_details:
                        # Process workshops and create typed BundleWorkshopInfo objects
                        workshops = bundle_details.get("workshops", [])
                        bundle_workshops = []
                        for workshop in workshops:
                            # Convert ObjectIds to strings
                            processed_workshop = {}
                            for key, value in workshop.items():
                                if hasattr(value, '__class__') and 'ObjectId' in str(type(value)):
                                    processed_workshop[key] = str(value)
                                else:
                                    processed_workshop[key] = value

                            # Create BundleWorkshopInfo instance
                            bundle_workshop = BundleWorkshopInfo(
                                song=processed_workshop.get("song"),
                                title=processed_workshop.get("title") or processed_workshop.get("song"),
                                artist_names=processed_workshop.get("artist_names"),
                                by=processed_workshop.get("by"),
                                studio_name=processed_workshop.get("studio_name"),
                                date=processed_workshop.get("date"),
                                time=processed_workshop.get("time")
                            )
                            bundle_workshops.append(bundle_workshop)

                        # Calculate savings amount
                        individual_prices = bundle_details.get("individual_workshop_prices", {})
                        bundle_price = bundle_details.get("bundle_price", 0)
                        savings_amount = float(sum(individual_prices.values()) - bundle_price) if individual_prices else 0.0

                        # Create typed BundleInfo object
                        bundle_info = BundleInfo(
                            name=bundle_details.get("name", "Bundle"),
                            description=bundle_details.get("description", ""),
                            workshops=bundle_workshops,
                            savings_amount=savings_amount
                        )
                except Exception as e:
                    logger.warning(f"Failed to get bundle details for order {order['order_id']}: {e}")

            # Fetch workshop details for QR code titles (for both bundle and non-bundle orders)
            workshop_details_map = {}
            if workshop_uuids:
                try:
                    from app.database.workshops import DatabaseOperations as WorkshopDB
                    for workshop_uuid in workshop_uuids:
                        try:
                            workshop = WorkshopDB.get_workshop_by_uuid(workshop_uuid)
                            if workshop:
                                workshop_details_map[workshop_uuid] = {
                                    'song': workshop.get('song'),
                                    'title': workshop.get('title') or workshop.get('song'),
                                    'artist_names': workshop.get('artist_names'),
                                    'by': workshop.get('by'),
                                    'studio_name': workshop.get('studio_name'),
                                    'date': workshop.get('date'),
                                    'time': workshop.get('time'),
                                    'event_type': workshop.get('event_type')
                                }
                        except Exception as e:
                            logger.warning(f"Failed to fetch workshop {workshop_uuid}: {e}")
                except Exception as e:
                    logger.warning(f"Failed to fetch workshop details for order {order['order_id']}: {e}")

            order_response = OrderResponse(
                order_id=order["order_id"],
                workshop_uuids=workshop_uuids,
                workshop_details=WorkshopDetails(**order["workshop_details"]),
                amount=order["amount"],
                currency=order["currency"],
                status=OrderStatusEnum(order["status"]),
                payment_link_url=order.get("payment_link_url"),
                qr_codes_data=order.get("qr_codes_data"),
                qr_code_generated_at=order.get("qr_code_generated_at"),
                # Reward-related fields
                cashback_amount=order.get("cashback_amount"),
                rewards_redeemed=order.get("rewards_redeemed"),
                final_amount_paid=order.get("final_amount_paid"),
                # Bundle-related fields
                bundle_id=order.get("bundle_id"),
                bundle_payment_id=order.get("bundle_payment_id"),
                is_bundle_order=order.get("is_bundle_order", False),
                bundle_total_workshops=order.get("bundle_total_workshops"),
                bundle_total_amount=order.get("bundle_total_amount"),
                bundle_info=bundle_info,
                workshop_details_map=workshop_details_map,
                created_at=order["created_at"],
                updated_at=order["updated_at"]
            )
            order_responses.append(order_response)
        
        # Determine if there are more results
        has_more = (offset + limit) < total_count
        
        return UserOrdersResponse(
            success=True,
            orders=order_responses,
            total_count=total_count,
            has_more=has_more
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user orders: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve orders"
        )


@router.post("/qr-generation/trigger")
async def trigger_qr_generation(
    user_id: str = Depends(verify_token)
):
    """Manually trigger QR code generation for paid orders.
    
    This endpoint allows admins to manually trigger the QR generation process.
    Only admin users can access this endpoint.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        QR generation batch results
    """
    try:
        # Note: Add admin check if needed
        # For now, any authenticated user can trigger (adjust as needed)
        
        logger.info(f"Manual QR generation triggered by user {user_id}")
        
        # Run QR generation batch
        result = await run_qr_generation_batch()
        
        logger.info(f"QR generation batch result: {result}")
        
        return {
            "success": True,
            "message": "QR generation batch completed",
            "batch_result": result
        }
        
    except Exception as e:
        logger.error(f"Error triggering QR generation: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger QR generation"
        )


@router.get("/qr-generation/status")
async def get_qr_generation_status(
    user_id: str = Depends(verify_token)
):
    """Get QR generation service status.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        QR generation service status
    """
    try:
        qr_service = get_background_qr_service()
        status_info = qr_service.get_processing_status()
        
        # Get count of orders needing QR codes
        pending_orders = OrderOperations.get_paid_orders_without_qr(limit=1000)
        pending_count = len(pending_orders)
        
        return {
            "success": True,
            "service_status": status_info,
            "pending_qr_count": pending_count
        }
        
    except Exception as e:
        logger.error(f"Error getting QR generation status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get QR generation status"
        )


@router.post("/rewards-generation/trigger")
async def trigger_rewards_generation(
    user_id: str = Depends(verify_token)
):
    """Manually trigger rewards generation for paid orders.
    
    Args:
        user_id: User ID from authentication token
        
    Returns:
        Trigger confirmation and processing status
    """
    try:
        logger.info(f"Manual rewards generation triggered by user {user_id}")
        
        # Create rewards service instance and trigger manual generation
        rewards_service = BackgroundRewardsService()
        result = await rewards_service.trigger_manual_rewards_generation()
        
        return {
            "success": True,
            "message": "Rewards generation triggered manually",
            "result": result
        }
        
    except Exception as e:
        logger.error(f"Error triggering rewards generation: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger rewards generation"
        )


@router.get("/rewards-generation/status")
async def get_rewards_generation_status(
    user_id: str = Depends(verify_token)
):
    """Get rewards generation service status.

    Args:
        user_id: User ID from authentication token

    Returns:
        Rewards generation service status
    """
    try:
        rewards_service = BackgroundRewardsService()
        status_info = await rewards_service.get_rewards_generation_status()

        return {
            "success": True,
            "service_status": status_info
        }

    except Exception as e:
        logger.error(f"Error getting rewards generation status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get rewards generation status"
        )


@router.post("/admin/trigger-qr-generation")
async def trigger_qr_generation(user_id: str = Depends(verify_token)):
    """Manually trigger QR code generation for testing purposes."""
    try:
        from ..services.background_qr_service import BackgroundQRService

        qr_service = BackgroundQRService()
        result = await qr_service.process_pending_qr_generation()

        return {
            "success": True,
            "message": "QR generation triggered manually",
            "result": result
        }

    except Exception as e:
        logger.error(f"Error triggering QR generation: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to trigger QR generation"
        )


@router.get("/qr-generation/status")
async def get_qr_generation_status(user_id: str = Depends(verify_token)):
    """Get QR code generation service status."""
    try:
        from ..services.background_qr_service import BackgroundQRService

        qr_service = BackgroundQRService()
        status_info = qr_service.get_processing_status()

        return {
            "success": True,
            "service_status": status_info
        }

    except Exception as e:
        logger.error(f"Error getting QR generation status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get QR generation status"
        )
