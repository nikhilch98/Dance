# Direct APNs Setup Instructions for Nachna App

## 🚀 Quick Setup Guide (No Firebase Required!)

This setup uses direct APNs integration with your existing server implementation, eliminating the need for Firebase.

### Step 1: iOS Capabilities Setup

1. **Open Xcode**: `open nachna/ios/Runner.xcworkspace`
2. **Select Runner target** → **Signing & Capabilities**
3. **Add capability**: Push Notifications
4. **Add capability**: Background Modes
   - Check "Remote notifications"

### Step 2: APNs Certificate Setup

You already have APNs configured in your server with:
- **APNs Auth Key**: `AuthKey_W5H5A6ZUS2.p8`
- **Team ID**: `3N4P4C85F3`
- **Bundle ID**: `com.nikhilchatragadda.dance-workshop-app`

No additional setup needed - your server is ready!

### Step 3: Build and Deploy

```bash
cd nachna

# Get dependencies (Firebase removed!)
flutter pub get

# Run on physical iOS device (required for APNs)
flutter run --release
```

## 📱 How It Works

### Direct APNs Architecture:
1. **iOS App** requests permission and gets device token
2. **Method Channel** communicates between iOS and Flutter
3. **Flutter Service** registers token with your server
4. **Your Server** sends notifications directly via APNs
5. **iOS App** receives and handles notifications

### No Firebase Needed:
- ✅ Direct APNs communication
- ✅ Uses your existing server infrastructure
- ✅ Simpler setup and maintenance
- ✅ Better control over notification flow

## 📱 Testing Device Token Extraction

### Method 1: Console Logs
1. Run the app on a physical iOS device
2. Grant notification permissions when prompted
3. Check Xcode console for device token:
   ```
   📱 APNs Device Token: a1b2c3d4e5f6789...
   📱 Device Token: (same token)
   ✅ Device token registered with server
   ✅ Notifications initialized with token: a1b2c3d4e5...
   ```

### Method 2: APNs Test Widget
1. Log in as admin user (mobile: 9999999999, password: test123)
2. Go to Admin screen
3. Use APNs Test Widget to see and copy device token

### Method 3: Server Registration
The app automatically registers device tokens with your server at:
`POST https://nachna.com/api/notifications/register-token`

## 🧪 Testing Push Notifications

### Using Python Test Script
```bash
cd .. # Go to parent directory
python test_apns_notifications.py
# Select option 3 and enter your device token
```

### Using Admin Panel
1. Log in as admin user
2. Go to Admin screen
3. Use "Send Test" button in APNs widget

### Using Server API Directly
```bash
curl -X POST https://nachna.com/api/admin/api/test-apns \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_64_CHARACTER_DEVICE_TOKEN",
    "title": "Test Notification",
    "body": "Hello from Nachna! 🎉"
  }'
```

## 🔧 Troubleshooting

### Common Issues

1. **"No device token"**
   - Ensure you're running on a physical device (not simulator)
   - Check notification permissions are granted
   - Verify method channel communication is working

2. **"Failed to register for remote notifications"**
   - Check APNs certificates in Apple Developer Portal
   - Verify bundle ID matches everywhere
   - Ensure Push Notifications capability is enabled

3. **"Invalid device token"**
   - Token should be 64 hex characters
   - Check if using sandbox vs production environment
   - Verify token is not expired

4. **Method channel errors**
   - Check iOS logs for method channel communication
   - Ensure Flutter and iOS sides are properly connected

### Debug Commands

```bash
# Check app configuration
flutter run --debug

# View detailed logs
flutter logs

# Check iOS system logs
# In Xcode: Window → Devices and Simulators → Select device → Open Console
```

## 🎯 Production Deployment

### Before App Store Release

1. **Switch to Production APNs**:
   ```python
   # In server.py, update:
   apns_service = APNsService(use_sandbox=False)  # Production
   ```

2. **Test with TestFlight**:
   - TestFlight builds use production APNs environment
   - Test notifications thoroughly before App Store release

3. **No Firebase Changes Needed**:
   - Your server already handles both sandbox and production
   - Just flip the switch in server configuration

## 🔐 Security Notes

- APNs Auth Key is already securely stored on your server
- Device tokens are handled securely via your existing API
- No third-party dependencies for notifications
- Full control over notification data and privacy

## ✅ Verification Checklist

- [ ] iOS capabilities (Push Notifications, Background Modes) enabled
- [ ] App builds and runs on physical device
- [ ] Device token appears in console logs
- [ ] Notification permissions granted
- [ ] Device token registered with server
- [ ] Test notifications received successfully
- [ ] Method channel communication working
- [ ] No Firebase dependencies

## 📞 Support

If you encounter issues:
1. Check Xcode console for error messages
2. Verify push notification capabilities are enabled
3. Test with Python script using known working device token
4. Check server logs for API registration errors
5. Verify method channel communication in iOS logs

## 🎉 Advantages of Direct APNs

- **Simpler**: No Firebase setup or configuration
- **Faster**: Direct communication with APNs
- **Secure**: Your existing server infrastructure
- **Controlled**: Full control over notification flow
- **Lightweight**: Smaller app size without Firebase SDK

Your direct APNs setup is complete! 🚀 