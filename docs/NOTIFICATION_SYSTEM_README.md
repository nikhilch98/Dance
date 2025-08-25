# Dance Workshop App - Notification System

This document describes the comprehensive notification system implemented for the Dance Workshop app, which allows users to react to artists and receive push notifications when new workshops are added.

## Overview

The notification system consists of three main components:

1. **User Reactions System** - Users can like and enable notifications for artists
2. **Workshop Change Detection** - Server monitors for new workshops and triggers notifications
3. **Push Notification Delivery** - APNs and FCM integration for iOS and Android devices

## 🎯 User Flow

### App Flow

1. **Artist Reactions**
   - Users can view artist profiles in the Artists tab
   - Each artist profile has two reaction buttons:
     - ❤️ **Like** - Express appreciation for the artist
     - 🔔 **Notify** - Enable notifications for new workshops
   - Both reactions can exist simultaneously for a user-artist pair
   - Reactions are stored in the database and sync across devices

2. **Notification Permissions**
   - App prompts users to enable push notifications on first launch
   - Users can enable/disable notifications in device settings
   - App handles permission changes and token updates automatically

3. **Deep Linking**
   - When users tap notifications, app navigates directly to:
     - Artists tab (index 1)
     - Specific artist detail screen
   - Deep linking works from all app states (foreground, background, terminated)

### Server Flow

1. **Reaction Storage**
   - Reactions stored in `reactions` collection with soft delete support
   - Device tokens stored in `device_tokens` collection mapped to user_id
   - Automatic token refresh handling when tokens change

2. **Workshop Monitoring**
   - MongoDB Change Streams monitor `workshops_v2` collection for insertions
   - For each new workshop, extract artist IDs from `artist_id_list`
   - Query users who have NOTIFY reactions for those artists

3. **Notification Delivery**
   - Fetch device tokens for notified users
   - Send APNs notifications to iOS devices with deep linking data
   - Handle token invalidation and cleanup
   - Log delivery statistics

## 📱 Technical Implementation

### Flutter App Components

#### 1. Notification Service (`lib/services/notification_service.dart`)
```dart
class NotificationService {
  // Singleton pattern for app-wide access
  // Handles Firebase messaging setup
  // Manages device token registration
  // Processes deep linking from notifications
}
```

**Key Features:**
- Firebase messaging initialization
- Permission request handling
- Token refresh monitoring  
- Local notification display for foreground messages
- Deep linking payload processing

#### 2. Reaction Models (`lib/models/reaction.dart`)
```dart
enum ReactionType { LIKE, NOTIFY }

class UserReactionsResponse {
  final List<String> likedArtists;
  final List<String> notifiedArtists;
}
```

#### 3. Reaction Provider (`lib/providers/reaction_provider.dart`)
```dart
class ReactionProvider {
  // Manages user reaction state
  // Syncs with server APIs
  // Provides reactive UI updates
}
```

#### 4. Updated UI Components
- **Artist Detail Screen**: Supports loading by artist ID for deep linking
- **Home Screen**: Accepts `initialTabIndex` for navigation
- **Reaction Buttons**: Support both LIKE and NOTIFY reactions

### Server Components

#### 1. Workshop Change Detection (`server.py`)
```python
def start_workshop_notification_watcher():
    # MongoDB Change Streams for workshops_v2 collection
    # Filters for insert operations only
    # Extracts artist IDs and triggers notifications
```

#### 2. APNs Integration
```python
class APNsService:
    # JWT token generation for Apple Push Notifications
    # Secure key management for production
    # Token invalidation handling
```

#### 3. Notification APIs
- `POST /api/notifications/register-token` - Register device tokens
- `POST /admin/api/test-apns` - Test notification sending (admin only)
- `POST /admin/api/send-test-notification` - Test artist notifications

#### 4. Database Collections

**reactions**
```javascript
{
  "_id": ObjectId,
  "user_id": "string",
  "entity_id": "string", // artist_id
  "entity_type": "ARTIST",
  "reaction": "LIKE" | "NOTIFY",
  "created_at": Date,
  "updated_at": Date,
  "is_deleted": false
}
```

**device_tokens**
```javascript
{
  "_id": ObjectId,
  "user_id": "string",
  "device_token": "string",
  "platform": "ios" | "android",
  "created_at": Date,
  "updated_at": Date,
  "is_active": true
}
```

## 🔄 Notification Flow

### 1. Workshop Added
```
New Workshop Inserted → Change Stream Triggers → Extract Artist IDs → 
Query Notified Users → Fetch Device Tokens → Send Push Notifications
```

### 2. Notification Received
```
Push Notification → User Taps → Deep Link Processing → 
Navigate to Artists Tab → Open Artist Detail Screen
```

### 3. Token Management
```
App Launch → Get/Refresh Token → Register with Server → 
Token Change Detected → Update Server → Old Token Deactivated
```

## 🛠️ Configuration

### Firebase Setup
1. Create Firebase project at https://console.firebase.google.com
2. Add iOS and Android apps with proper bundle IDs
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Update `firebase_options.dart` with actual configuration values

### APNs Setup (iOS)
1. Create APNs key in Apple Developer Console
2. Download `.p8` key file
3. Update server configuration:
   ```python
   APNS_AUTH_KEY_ID = "your_key_id"
   APNS_TEAM_ID = "your_team_id"
   APNS_BUNDLE_ID = "com.yourapp.bundleid"
   APNS_KEY_PATH = "./AuthKey_XXXXXXXXXX.p8"
   ```

### Environment Variables
```bash
# Add to your environment
FIREBASE_PROJECT_ID=your_project_id
APNS_KEY_ID=your_apns_key_id
APNS_TEAM_ID=your_team_id
```

## 🧪 Testing

### Test User Credentials
```
Mobile: 9999999999
Password: test123
User ID: 683cdbb39caf05c68764cde4
```

### Testing Workflow

1. **Setup Test User**
   ```bash
   python create_test_user.py
   ```

2. **Test Reactions**
   - Login with test user
   - Navigate to any artist
   - Toggle LIKE and NOTIFY reactions
   - Verify database updates

3. **Test Notifications**
   ```bash
   # Send test notification
   curl -X POST "https://nachna.com/admin/api/test-apns" \
   -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
   -H "Content-Type: application/json" \
   -d '{"device_token": "YOUR_DEVICE_TOKEN"}'
   ```

4. **Test Deep Linking**
   - Send notification with artist_id
   - Tap notification from different app states
   - Verify navigation to correct artist

## 🚀 Deployment

### Production Checklist

- [ ] Update Firebase configuration with production values
- [ ] Add real APNs key file to server
- [ ] Configure FCM for Android notifications
- [ ] Set up monitoring for notification delivery
- [ ] Test with real devices on App Store/Play Store builds
- [ ] Configure server environment variables
- [ ] Set up log aggregation for notification analytics

### Monitoring

Monitor these metrics in production:
- Notification delivery success rate
- Token refresh frequency
- Deep link conversion rate
- User reaction engagement
- Workshop notification effectiveness

## 🔒 Security Considerations

1. **Device Token Security**
   - Tokens are automatically invalidated when users uninstall
   - Old tokens are cleaned up when delivery fails
   - Tokens are tied to user authentication

2. **APNs Key Security**
   - Private key stored securely on server
   - JWT tokens have 1-hour expiration
   - Key rotation should be planned annually

3. **Deep Link Validation**
   - Artist IDs are validated before navigation
   - Malformed payloads are handled gracefully
   - No sensitive data in notification payloads

## 🐛 Troubleshooting

### Common Issues

1. **Notifications Not Received**
   - Check device permissions
   - Verify token registration
   - Check APNs key configuration
   - Test with admin endpoints

2. **Deep Linking Not Working**
   - Verify payload format: `artist|{artist_id}`
   - Check navigation logic in app
   - Test from different app states

3. **Token Registration Fails**
   - Check internet connectivity
   - Verify API authentication
   - Check server logs for errors

### Debug Commands

```bash
# Check notification service status
curl "https://nachna.com/api/config" -H "Authorization: Bearer TOKEN"

# Test device token registration
curl -X POST "https://nachna.com/api/notifications/register-token" \
-H "Authorization: Bearer TOKEN" \
-d '{"device_token":"test","platform":"ios"}'

# Get user reactions
curl "https://nachna.com/api/user/reactions" -H "Authorization: Bearer TOKEN"
```

## 📈 Future Enhancements

1. **Rich Notifications**
   - Workshop images in notifications
   - Action buttons (Book Now, Remind Later)
   - Notification customization

2. **Advanced Targeting**
   - Location-based notifications
   - Time zone aware delivery
   - User preference settings

3. **Analytics**
   - Notification open rates
   - Conversion tracking
   - A/B testing for content

4. **Multi-Platform**
   - Web push notifications
   - Email fallback
   - SMS notifications

## 📞 Support

For technical issues or questions:
- Check server logs for error details
- Use admin test endpoints for debugging
- Monitor MongoDB change streams
- Test with provided test user credentials

---

*This notification system provides a robust foundation for user engagement and workshop discovery in the Dance Workshop app.* 