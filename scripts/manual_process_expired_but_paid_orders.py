import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import razorpay
from pprint import pprint
from app.api.razorpay import map_razorpay_status_to_order_status
from app.database.orders import OrderOperations
from app.models.orders import OrderStatusEnum
from app.services.razorpay_service import get_razorpay_service

service = get_razorpay_service()

for razorpay_order_details in service.get_order_history():

    print("Order ID: ", razorpay_order_details["order_id"])
    razorpay_payment_link_reference_id = razorpay_order_details["order_id"]
    razorpay_payment_link_status = razorpay_order_details["status"]

    if razorpay_payment_link_status != "paid" :
        print(f"We are currently only manually processing razorpay orders which are paid while this order is {razorpay_payment_link_status}")
        continue

    internal_order = OrderOperations.get_order_by_id(razorpay_payment_link_reference_id)
    if not internal_order:
        print(f"URGEEEENTTTTTT: Internal order not found for {razorpay_payment_link_reference_id} | Razorpay order id: {razorpay_order_details['razorpay_order_id']}")
        continue
    if internal_order["status"] != "expired":
        print(f"We are currently only manually processing internal orders which are expired while this order is {internal_order['status']}")
        continue
    new_status = map_razorpay_status_to_order_status(razorpay_payment_link_status)
    additional_data = {}
    # Update payment gateway details with payment ID
    payment_gateway_details = internal_order.get("payment_gateway_details", {})
    payment_gateway_details["razorpay_payment_id"] = None
    payment_gateway_details["webhook_status"] = razorpay_payment_link_status
    payment_gateway_details["webhook_timestamp"] = None
    additional_data["payment_gateway_details"] = payment_gateway_details
    
    # Update order status
    success = OrderOperations.update_order_status(
                        order_id=internal_order["order_id"],
                        status=new_status,
                        additional_data=additional_data
                    )
    if not success:
        print(f"URGEEEENTTTTTT: Failed to update order status for {razorpay_payment_link_reference_id} | Razorpay order id: {razorpay_order_details['razorpay_order_id']}")
        continue
    order_updated = True
    rewards_redeemed = internal_order.get("rewards_redeemed")
    if rewards_redeemed and rewards_redeemed > 0:
        # Payment successful - complete the pending redemption
        try:
            from app.database.rewards import RewardOperations
            success = RewardOperations.complete_pending_redemption(internal_order["order_id"])
            if success:
                print(f"Payment successful for order {internal_order['order_id']} - completed pending redemption of ₹{rewards_redeemed}")
            else:
                print(f"Failed to complete pending redemption for order {internal_order['order_id']}")
        except Exception as e:
            print(f"Error completing pending redemption for order {internal_order['order_id']}: {e}")
    print(f"Order {internal_order['order_id']} processed successfully")