# OTP Authentication Implementation Guide

## Overview

The Nachna app has been updated to use Twilio-based OTP (One-Time Password) authentication instead of password-based authentication. This provides better security and user experience.

## Changes Made

### 1. Removed Password-Based Authentication
- ❌ Removed `UserRegistration` model (with password)
- ❌ Removed `UserLogin` model (with password)
- ❌ Removed `PasswordUpdate` model
- ❌ Removed `/register` endpoint
- ❌ Removed `/login` endpoint
- ❌ Removed `/password` endpoint
- ❌ Removed password hashing utilities
- ❌ Removed `passlib[bcrypt]` dependency

### 2. Added OTP Authentication
- ✅ Added `SendOTPRequest` model (10-digit mobile number)
- ✅ Added `VerifyOTPRequest` model (mobile number + 6-digit OTP)
- ✅ Added `/send-otp` endpoint
- ✅ Added `/verify-otp` endpoint (replaces `/login`)
- ✅ Added Twilio integration with `TwilioOTPService`
- ✅ Added `twilio` dependency
- ✅ Updated user creation to be OTP-based

## API Endpoints

### Send OTP
**Endpoint:** `POST /api/auth/send-otp`

**Request Body:**
```json
{
  "mobile_number": "8985374940"
}
```

**Response (Success):**
```json
{
  "message": "OTP sent successfully"
}
```

**Response (Error):**
```json
{
  "detail": "Failed to send OTP: <error_message>"
}
```

### Verify OTP and Login
**Endpoint:** `POST /api/auth/verify-otp`

**Request Body:**
```json
{
  "mobile_number": "8985374940",
  "otp": "123456"
}
```

**Response (Success):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "user_id": "675a1234567890abcdef1234",
    "mobile_number": "8985374940",
    "name": null,
    "date_of_birth": null,
    "gender": null,
    "profile_picture_url": null,
    "profile_picture_id": null,
    "profile_complete": false,
    "is_admin": false,
    "created_at": "2024-12-11T10:30:00Z",
    "updated_at": "2024-12-11T10:30:00Z",
    "device_token": null
  }
}
```

**Response (Error):**
```json
{
  "detail": "Invalid or expired OTP"
}
```

## Environment Setup

### Twilio Configuration
Add these environment variables to your `.env` file:

```env
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_VERIFY_SERVICE_SID=your_verify_service_sid_here
```

### Getting Twilio Credentials

1. **Sign up for Twilio:** https://www.twilio.com/try-twilio
2. **Get Account SID and Auth Token:** https://console.twilio.com/
3. **Create a Verify Service:**
   - Go to https://console.twilio.com/us1/develop/verify/services
   - Click "Create new Service"
   - Set a friendly name (e.g., "Nachna OTP")
   - Copy the Service SID

## Installation

1. **Install Twilio:**
```bash
pip install twilio
```

2. **Update requirements.txt:**
The `twilio` package has been added to `requirements.txt`

3. **Set environment variables:**
Create or update your `.env` file with Twilio credentials

## User Flow Changes

### Old Flow (Password-based)
1. User enters mobile number and password
2. Server validates credentials
3. Server returns access token

### New Flow (OTP-based)
1. User enters mobile number
2. App calls `/send-otp` → Twilio sends SMS
3. User enters received OTP
4. App calls `/verify-otp` → Twilio validates OTP
5. Server creates/gets user and returns access token

## Database Changes

### User Model Updates
- ❌ Removed `password_hash` field
- ✅ User creation is now based only on mobile number
- ✅ `create_or_get_user()` method returns existing user or creates new one

### Migration Notes
- Existing users will not be affected (they can still use OTP)
- No data migration needed as we're not removing users
- `password_hash` field will be ignored if present

## Testing

Use the provided test script:

```bash
python test_otp_api.py
```

This script will:
1. Send OTP to a test mobile number
2. Prompt you to enter the received OTP
3. Verify the OTP and get access token
4. Test profile access with the token

## Security Considerations

### Advantages of OTP
- ✅ No passwords to store or manage
- ✅ Reduced risk of credential stuffing attacks
- ✅ Better user experience (no password to remember)
- ✅ Built-in rate limiting through Twilio
- ✅ Automatic expiration of OTP codes

### Best Practices Implemented
- ✅ Mobile number validation (10 digits only)
- ✅ OTP format validation (6 digits only)
- ✅ Comprehensive error handling
- ✅ Logging for debugging
- ✅ Twilio's built-in fraud protection

## Error Handling

The system handles various error scenarios:

1. **Invalid mobile number format**
2. **Twilio service errors**
3. **Invalid or expired OTP**
4. **Rate limiting (handled by Twilio)**
5. **Network connectivity issues**

## Flutter Integration

To integrate with the Flutter app, update your authentication service to:

1. Replace login with two-step process:
   - Call `/send-otp` endpoint
   - Show OTP input screen
   - Call `/verify-otp` endpoint

2. Remove password-related UI:
   - Registration password field
   - Login password field
   - Change password screen

3. Update models to match new API:
   - `SendOTPRequest`
   - `VerifyOTPRequest`
   - Same `AuthResponse` format

## Rollback Plan

If needed to rollback to password authentication:

1. Restore previous `auth.py` endpoints
2. Restore password-related models
3. Add back `passlib[bcrypt]` dependency
4. Revert user operations methods

All user data remains intact for seamless rollback.

## Support

For Twilio-related issues:
- Twilio Console: https://console.twilio.com/
- Twilio Documentation: https://www.twilio.com/docs/verify/api
- Twilio Support: https://support.twilio.com/

For implementation issues:
- Check server logs for detailed error messages
- Use the test script to verify API functionality
- Ensure environment variables are correctly set 