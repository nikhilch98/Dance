from twilio.rest import Client
import os

# Find your Account SID and Auth Token at twilio.com/console
# and set the environment variables. See http://twil.io/secure

# Send OTP flow

account_sid = os.environ["TWILIO_ACCOUNT_SID"]
auth_token = os.environ["TWILIO_AUTH_TOKEN"]
mobile_number = "8985374940"
client = Client(account_sid, auth_token)
verification = client.verify.v2.services(
    os.environ["TWILIO_VERIFY_SERVICE_SID"]
).verifications.create(to=f"+91{mobile_number}", channel="sms")
if verification.status == "pending":
    print("OTP sent successfully")
else:
    print("Error sending OTP")

# Verification check flow
verification_check = client.verify.v2.services(
    os.environ["TWILIO_VERIFY_SERVICE_SID"]
).verification_checks.create(to=f"+91{mobile_number}", code="657316")

if verification_check.status == "approved":
    print("OTP verified successfully")
else:
    print("Error verifying OTP")