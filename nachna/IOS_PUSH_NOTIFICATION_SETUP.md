# iOS Push Notification Setup Guide for Nachna

## Overview
This guide provides complete instructions for enabling and configuring push notifications for the Nachna Flutter app using native iOS APNs (Apple Push Notification service).

## 🍎 Prerequisites

### Apple Developer Account Requirements
- **Active Apple Developer Program membership** ($99/year)
- **Registered App ID** with push notification capability
- **APNs Certificate or Key** for server communication
- **Provisioning Profile** with push notification entitlement

### Development Environment
- **Xcode 15.0+** (latest stable recommended)
- **macOS** (required for iOS development)
- **iOS device** for testing (push notifications don't work in simulator for production)
- **Flutter SDK** with iOS toolchain configured

## 📋 Step-by-Step Setup

### 1. Apple Developer Console Configuration

#### A. Register App ID (if not already done)
1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **App IDs**
4. Register new App ID or edit existing:
   - **Bundle ID**: `com.nachna.nachna` (must match your app)
   - **Capabilities**: Enable **Push Notifications**

#### B. Create APNs Certificate/Key
**Option 1: APNs Key (Recommended - easier to manage)**
1. Go to **Keys** section in Developer Console
2. Click **+** to create new key
3. Give it a name (e.g., "Nachna APNs Key")
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download the .p8 key file** (you can only download once!)
7. Note your **Key ID** and **Team ID**

**Option 2: APNs Certificate**
1. Go to **Certificates** section
2. Click **+** to create new certificate
3. Choose **Apple Push Notification service SSL (Sandbox & Production)**
4. Select your App ID
5. Upload CSR (create via Keychain Access)
6. Download and install certificate

#### C. Update Provisioning Profile
1. Go to **Profiles** section
2. Edit your development/distribution profile
3. Ensure **Push Notifications** capability is included
4. Download and install updated profile

### 2. Xcode Project Configuration

#### A. Enable Push Notifications Capability
1. Open `nachna/ios/Runner.xcworkspace` in Xcode
2. Select **Runner** project in navigator
3. Select **Runner** target
4. Go to **Signing & Capabilities** tab
5. Click **+ Capability**
6. Add **Push Notifications**
7. Add **Background Modes** and check:
   - **Background fetch**
   - **Remote notifications**
   - **Background processing**

#### B. Update Team and Bundle ID
1. In **Signing & Capabilities**:
   - **Team**: Select your Apple Developer team
   - **Bundle Identifier**: `com.nachna.nachna`
   - **Provisioning Profile**: Select profile with push notifications

#### C. Verify Entitlements
The `Runner.entitlements` file should contain:
```xml
<key>aps-environment</key>
<string>development</string>
<key>com.apple.developer.usernotifications.communication</key>
<true/>
<key>com.apple.developer.background-modes</key>
<array>
    <string>background-fetch</string>
    <string>remote-notification</string>
</array>
```

### 3. iOS Code Implementation ✅

The iOS implementation is **already complete** in this project:

#### Features Implemented:
- **Permission Management**: Automatic and manual permission requests
- **Token Management**: Device token generation and refresh handling
- **Notification Handling**: Foreground, background, and tap handling
- **Settings Integration**: Direct link to iOS notification settings
- **Method Channel**: Flutter-iOS communication bridge
- **Error Handling**: Comprehensive error handling and logging

#### Key Files:
- **`ios/Runner/AppDelegate.swift`**: Complete push notification implementation
- **`ios/Runner/Info.plist`**: Notification permissions and background modes
- **`ios/Runner/Runner.entitlements`**: Push notification entitlements
- **`lib/services/notification_service.dart`**: Flutter service for iOS communication

### 4. Server-Side Integration

#### A. Server Requirements
Your server needs to send push notifications to APNs:

**Using APNs Key (.p8 file):**
```bash
# Example using curl (replace with your server implementation)
curl -v \
  -d '{"aps":{"alert":"New workshop available!","badge":1,"sound":"default"}}' \
  -H "apns-topic: com.nachna.nachna" \
  -H "apns-push-type: alert" \
  -H "authorization: bearer $JWT_TOKEN" \
  --http2 \
  https://api.push.apple.com/3/device/$DEVICE_TOKEN
```

**JWT Token Generation:**
- Use your **Key ID**, **Team ID**, and **.p8 key file**
- Libraries available for all major programming languages
- Token valid for 1 hour, can be reused

#### B. Notification Payload Format
```json
{
  "aps": {
    "alert": {
      "title": "New Workshop!",
      "body": "Join the Hip Hop Beginner class by Dance Master Alex"
    },
    "badge": 1,
    "sound": "default"
  },
  "artistId": "artist123",
  "workshopId": "workshop456",
  "customData": "any additional data"
}
```

### 5. Testing Push Notifications

#### A. Development Testing
1. **Build and install** app on physical iOS device
2. **Grant notification permissions** when prompted
3. **Check device token** in Xcode console/app logs
4. **Send test notification** from server or testing tool
5. **Verify notification display** in various app states

#### B. Testing Tools
- **Pusher** (macOS app): Easy GUI for sending test notifications
- **Knuff** (macOS app): Another testing tool
- **Terminal/curl**: Command-line testing
- **Postman**: API testing with APNs endpoints

#### C. Testing Scenarios
- ✅ App in foreground (banner should show)
- ✅ App in background (notification center)
- ✅ App terminated (notification center)
- ✅ Notification tap handling (deep linking)
- ✅ Badge count updates
- ✅ Sound playback

### 6. Production Deployment

#### A. Production APNs
- Change entitlements: `aps-environment` → `production`
- Use production APNs endpoint: `https://api.push.apple.com`
- Update provisioning profile for App Store distribution

#### B. App Store Submission
- Include **notification usage description** in Info.plist ✅
- Test on multiple devices and iOS versions
- Verify notification permissions work correctly
- Test background notification delivery

### 7. Troubleshooting

#### Common Issues:

**Device Token Not Generated:**
- Check Bundle ID matches exactly
- Verify provisioning profile includes push notifications
- Ensure physical device (not simulator for production)
- Check Apple Developer account status

**Notifications Not Delivered:**
- Verify APNs certificate/key is valid
- Check device token format and validity
- Ensure proper payload format
- Check APNs response for error codes

**Permission Issues:**
- Reset iOS simulator/device settings
- Check Info.plist usage descriptions
- Verify entitlements file
- Test permission request flow

#### Debug Logs:
The app logs detailed information with `📱` prefix:
```
📱 APNs Device Token: abc123...
📱 Permission granted - registering for remote notifications
📱 Notification received: {...}
```

### 8. Monitoring & Analytics

#### Server-Side Monitoring:
- Track APNs response codes
- Monitor token refresh rates
- Log notification delivery success/failure
- Track user engagement from notifications

#### App-Side Monitoring:
- Permission grant rates
- Token generation success
- Notification tap-through rates
- Background notification processing

## 🔐 Security Considerations

### APNs Key Management:
- **Never commit .p8 key files** to version control
- Store keys securely on server (environment variables/secrets)
- Rotate keys periodically
- Use different keys for development/production if needed

### Device Token Security:
- Tokens can change, always handle refreshes
- Don't store tokens in insecure locations
- Validate tokens before sending notifications
- Handle token invalidation gracefully

## 📱 iOS-Specific Features

### Rich Notifications (Future Enhancement):
- Add notification service extension for media
- Implement actionable notifications with buttons
- Support for notification categories
- Custom notification sounds

### Integration with iOS Features:
- Siri Shortcuts for notification actions
- Spotlight integration
- Widget notifications
- CarPlay support (if applicable)

## ✅ Current Implementation Status

### ✅ Completed:
- Native iOS APNs integration
- Permission management system
- First-time permission dialog
- Device token handling
- Background notification processing
- Settings deep linking
- Error handling and logging
- Method channel communication

### 🔄 Ready for Production:
- Update entitlements for production
- Configure server with APNs keys
- Test with App Store provisioning profiles
- Submit to App Store

This implementation provides a robust, production-ready push notification system specifically optimized for iOS, following Apple's best practices and guidelines. 