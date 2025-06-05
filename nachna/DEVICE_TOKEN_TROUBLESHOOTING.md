# Device Token Troubleshooting Guide

## 🚨 Most Common Issue: iOS Simulator

### ❌ **Device tokens DO NOT work in iOS Simulator**
The **#1 reason** for not getting device tokens is running the app in iOS Simulator. APNs device tokens are **only generated on physical iOS devices**.

**Solution**: Install and test the app on a **physical iPhone or iPad**.

## 🔍 Debugging Steps

### Step 1: Check Your Testing Environment
```bash
# Are you running on a physical device?
flutter devices

# You should see something like:
# Nikhil's iPhone (mobile) • 00001234-56789ABCDEF0 • ios • iOS 17.0
```

**Required**: Use a **physical iOS device** connected via USB or wireless debugging.

### Step 2: Check Console Logs
When running the app, look for these log messages with `📱` prefix:

#### ✅ **Successful Token Generation:**
```
📱 Initialize notifications called from Flutter
📱 Current authorization status: authorized
📱 Permission granted - registering for remote notifications
📱 APNs Device Token: abc123def456...
```

#### ❌ **Permission Issues:**
```
📱 Current authorization status: denied
📱 Previously denied - directing to Settings
```

#### ❌ **No Token Generated:**
```
📱 Permission granted - registering for remote notifications
(But no "APNs Device Token" message follows)
```

### Step 3: Verify App Permissions

#### Check iOS Settings:
1. Go to **Settings → Notifications → Nachna**
2. Ensure **Allow Notifications** is ON
3. Check that **Banner Style** is set (Temporary/Persistent)

#### Check in App:
1. Open **Admin → Config** tab
2. Look at **Notification Status** indicators:
   - Device Token: Should show ✅ with partial token
   - Auth Token: Should show ✅ 
   - User ID: Should show ✅
   - Notifications: Should show ✅

### Step 4: Force Token Regeneration

#### Method 1: Reset App Permissions
1. Go to **Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy**
2. Reinstall the app
3. Grant permissions when prompted

#### Method 2: Use Admin Tools
1. Open app → **Admin → Config** tab
2. Tap **"Reset First Launch"** button
3. Restart the app
4. Grant permissions in the dialog

#### Method 3: Manual Token Request
```dart
// In the app, call this method:
final result = await NotificationService().requestPermissionsAndGetToken();
print('Token result: $result');
```

## 🔧 Common Issues & Solutions

### Issue 1: "No provisioning profile matches"
**Cause**: App not properly signed for push notifications
**Solution**: 
1. Open Xcode → Runner.xcworkspace
2. Select Runner target → Signing & Capabilities
3. Ensure your team is selected
4. Verify Bundle Identifier matches: `com.nachna.nachna`

### Issue 2: "Entitlement not supported"
**Cause**: Provisioning profile doesn't include push notifications
**Solution**:
1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to Identifiers → App IDs
3. Edit `com.nachna.nachna` app ID
4. Enable **Push Notifications** capability
5. Update provisioning profiles

### Issue 3: "Permission granted but no token"
**Cause**: App not properly registered for remote notifications
**Solution**:
```swift
// Check this is called in AppDelegate:
UIApplication.shared.registerForRemoteNotifications()
```

### Issue 4: Token generated but not stored
**Cause**: Token received but not properly handled by Flutter
**Solution**: Check these logs:
```
[NotificationService] === HANDLING TOKEN RECEIVED ===
[NotificationService] New token: abc123...
[NotificationService] Device token stored locally
```

## 🧪 Testing Methods

### Method 1: Admin Panel Check
1. Open app → **Admin → Config**
2. Check **Device Token** field:
   - ✅ Should show: "abc123...def456 (64 chars)"
   - ❌ Shows: "Not available" or "null"

### Method 2: Console Logging
```bash
# Run app with verbose logging
flutter run --verbose

# Look for notification-related logs
grep "📱\|NotificationService" logs.txt
```

### Method 3: Manual Token Request
In the app, try manually requesting permissions:
1. Go to any screen
2. Add temporary button:
```dart
ElevatedButton(
  onPressed: () async {
    final result = await NotificationService().requestPermissionsAndGetToken();
    print('Manual token request result: $result');
  },
  child: Text('Request Token'),
)
```

## 🔍 Advanced Debugging

### Check iOS Entitlements
```bash
# Extract and check entitlements from built app
cd ios
xcodebuild -project Runner.xcodeproj -target Runner -showBuildSettings | grep ENTITLEMENTS

# Should show:
# CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements
```

### Verify Entitlements Content
```xml
<!-- ios/Runner/Runner.entitlements should contain: -->
<key>aps-environment</key>
<string>development</string>
```

### Check Info.plist Configuration
```xml
<!-- ios/Runner/Info.plist should contain: -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 📱 Device-Specific Issues

### iOS Version Compatibility
- **iOS 10+**: Uses `UNUserNotificationCenter`
- **iOS 9 and below**: Uses legacy `UIUserNotificationSettings`

### Device Restrictions
- **Corporate devices**: May have notification restrictions
- **Parental controls**: Can disable notifications
- **Do Not Disturb**: Doesn't affect token generation

## ⚙️ Xcode Project Verification

### Check Capabilities
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to **Signing & Capabilities**
4. Verify **Push Notifications** capability is added
5. Check **Background Modes** includes:
   - Remote notifications

### Check Build Settings
1. In Xcode, search for "ENTITLEMENTS"
2. Verify `CODE_SIGN_ENTITLEMENTS` points to `Runner/Runner.entitlements`

## 🚀 Quick Fix Checklist

- [ ] **Using physical iOS device** (not simulator)
- [ ] **Permissions granted** in iOS Settings
- [ ] **Push Notifications enabled** in Apple Developer Console
- [ ] **Provisioning profile updated** with push notification entitlement
- [ ] **Bundle ID matches** exactly: `com.nachna.nachna`
- [ ] **Xcode capabilities configured** (Push Notifications + Background Modes)
- [ ] **App properly signed** with valid development team

## 📞 If Still No Token

### Last Resort Steps:
1. **Delete app** from device completely
2. **Clean build** in Xcode: Product → Clean Build Folder
3. **Reset iOS settings**: Settings → General → Reset → Reset All Settings
4. **Rebuild and reinstall** app
5. **Grant permissions** when prompted

### Contact Information:
If following all these steps doesn't work, the issue might be:
- Apple Developer Account limitations
- iOS device management restrictions
- Network connectivity issues preventing APNs registration

### Testing Token Reception:
```dart
// Add this to debug token reception
NotificationService().initialize().then((token) {
  print('🔍 FINAL TOKEN RESULT: $token');
  if (token == null) {
    print('❌ No token received - check troubleshooting guide');
  } else {
    print('✅ Token received successfully: ${token.substring(0, 20)}...');
  }
});
```

Remember: **Device tokens are ONLY available on physical iOS devices with proper APNs setup**. The iOS Simulator will never generate a real device token. 