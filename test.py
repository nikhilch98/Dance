import razorpay
from app.services.razorpay_service import get_razorpay_service

service = get_razorpay_service()

order = service.create_payment_link(
    amount=100,
    expire_by_mins=20,
    order_id="order_123",
    user_name="John Doe",
    user_email="john.doe@example.com",
    user_phone="+918985374940"
)

print(order)