# APNs (Apple Push Notifications) Setup Guide

## 🍎 Overview

Apple Push Notification service (APNs) allows your server to send push notifications to iOS devices. Here's how it works with your Nachna app.

## 📱 Device Token Management

### **Q: Do we save an individual device token for each device and user?**

**A: YES, absolutely!** Here's why and how:

### Device Token Strategy:

1. **One Device Token per Device**: Each iOS device generates a unique device token
2. **User-Device Mapping**: One user can have multiple devices (iPhone, iPad, etc.)
3. **Token Updates**: Device tokens can change when:
   - App is restored from backup
   - iOS is updated
   - App is reinstalled
   - Device is reset

### Current Database Schema:
```javascript
// device_tokens collection
{
  "_id": ObjectId("..."),
  "user_id": "683cdbb39caf05c68764cde4",
  "device_token": "a1b2c3d4e5f6...", // 64 hex characters
  "platform": "ios", // or "android"
  "created_at": ISODate("..."),
  "updated_at": ISODate("..."),
  "is_active": true
}
```

### Benefits of This Approach:
- ✅ Send notifications to all user's devices
- ✅ Handle token updates gracefully
- ✅ Remove inactive tokens automatically
- ✅ Platform-specific handling (iOS vs Android)

## 🔧 APNs Configuration

### Environment Variables Set:
```bash
APNS_AUTH_KEY_ID=W5H5A6ZUS2
APNS_TEAM_ID=3N4P4C85F3
APNS_BUNDLE_ID=com.nikhilchatragadda.dance-workshop-app
APNS_KEY_PATH=./nachna/AuthKey_W5H5A6ZUS2.p8
```

### What These Mean:
- **AUTH_KEY_ID**: Your APNs authentication key identifier
- **TEAM_ID**: Your Apple Developer Team ID
- **BUNDLE_ID**: Your iOS app's bundle identifier
- **KEY_PATH**: Path to your .p8 private key file

## 🧪 Testing APNs

### 1. **Sandbox vs Production**
- **Sandbox**: For development/testing (`api.sandbox.push.apple.com`)
- **Production**: For live app (`api.push.apple.com`)
- Currently configured for **Sandbox**

### 2. **Getting Device Tokens**

Add this to your iOS app's `AppDelegate.swift`:

```swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }
    
    // This method is called when device token is received
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device Token: \(tokenString)")
        
        // Send this token to your server
        sendDeviceTokenToServer(tokenString)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    private func sendDeviceTokenToServer(_ token: String) {
        // Call your API endpoint
        let url = URL(string: "https://nachna.com/api/notifications/register-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer YOUR_AUTH_TOKEN", forHTTPHeaderField: "Authorization")
        
        let body = [
            "device_token": token,
            "platform": "ios"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Failed to register device token: \(error)")
            } else {
                print("✅ Device token registered successfully")
            }
        }.resume()
    }
}
```

### 3. **Testing Workflow**

#### Step 1: Run the APNs Test Script
```bash
python test_apns_notifications.py
```

#### Step 2: Get Real Device Token
1. Run your iOS app on a physical device (not simulator)
2. Grant notification permissions
3. Copy the device token from console logs
4. Use it in the test script

#### Step 3: Send Test Notification
```bash
# Using curl directly
curl -X POST https://nachna.com/api/admin/api/test-apns \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_DEVICE_TOKEN",
    "title": "Test from Nachna!",
    "body": "This is a test notification 🎉"
  }'
```

## 🔄 Notification Flow

### Artist Notification Workflow:
1. User taps "🔔 Notify" button on artist profile
2. Creates `NOTIFY` reaction in database
3. When artist adds new workshop:
   ```python
   # Get all users with NOTIFY reactions for this artist
   notified_users = ReactionOperations.get_notified_users_of_artist(artist_id)
   
   # Get device tokens for these users
   device_tokens = PushNotificationOperations.get_device_tokens(notified_users)
   
   # Send notifications
   for token_data in device_tokens:
       await apns_service.send_notification(
           device_token=token_data['device_token'],
           title=f"🎉 {artist_name} is back!",
           body="New workshop tickets available! Book ASAP 💃",
           data={
               'artist_id': artist_id,
               'workshop_id': workshop_id,
               'type': 'new_workshop'
           }
       )
   ```

## 🚨 Common Issues & Solutions

### 1. **Invalid Device Token**
- **Error**: `BadDeviceToken`
- **Solution**: Token might be from production app but sending to sandbox (or vice versa)

### 2. **Invalid Topic**
- **Error**: `TopicDisallowed`
- **Solution**: Check bundle ID matches your app

### 3. **Token Expired**
- **Error**: `ExpiredProviderToken`
- **Solution**: JWT tokens expire, regenerate automatically

### 4. **Device Not Active**
- **Error**: `Unregistered`
- **Solution**: Remove inactive tokens from database

## 📊 Monitoring & Analytics

### Track Notification Success:
```python
# Add to your notification sending function
async def send_notification_with_tracking(device_token, title, body):
    success = await apns_service.send_notification(device_token, title, body)
    
    # Log results
    client = get_mongo_client()
    client["dance_app"]["notification_logs"].insert_one({
        "device_token": device_token[:10] + "...",  # Don't store full token
        "title": title,
        "success": success,
        "timestamp": datetime.utcnow(),
        "error": None if success else "Check server logs"
    })
    
    return success
```

## 🔐 Security Best Practices

1. **Never log full device tokens** - Only log first 10 characters
2. **Rotate JWT tokens** - They expire in 1 hour max
3. **Validate device tokens** - Remove invalid/inactive tokens
4. **Rate limiting** - Don't spam notifications
5. **User preferences** - Respect notification settings

## 📱 Testing Tools

### 1. **Pusher** (macOS App)
- Download from Mac App Store
- Test notifications without coding
- Good for quick validation

### 2. **Command Line Testing**
```bash
# Direct APNs test (requires JWT token)
curl -v \
  -H "authorization: bearer $JWT_TOKEN" \
  -H "apns-topic: com.nikhilchatragadda.dance-workshop-app" \
  -H "apns-push-type: alert" \
  -H "apns-priority: 10" \
  -d '{"aps":{"alert":{"title":"Test","body":"Hello!"}}}' \
  https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN
```

### 3. **Your Custom Test Script**
Use the provided `test_apns_notifications.py` for comprehensive testing.

## 🎯 Next Steps

1. **Test with real device**: Get actual device token from your iOS app
2. **Implement in Flutter**: Add proper Firebase/APNs integration
3. **Add user preferences**: Let users control notification types
4. **Monitor delivery**: Track success/failure rates
5. **Production deployment**: Switch to production APNs URL

## 📞 Troubleshooting

If notifications aren't working:
1. Check device token is 64 hex characters
2. Verify app bundle ID matches APNs configuration
3. Ensure device has notification permissions
4. Check server logs for APNs errors
5. Test with Pusher app to isolate issues

That's it! Your APNs setup is ready for testing. 🚀 