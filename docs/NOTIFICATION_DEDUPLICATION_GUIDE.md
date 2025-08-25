# Notification Deduplication System Guide

## Overview

The Nachna app implements a sophisticated notification deduplication system to prevent users from receiving duplicate notifications when workshop data is refreshed every 6 hours. The system uses workshop UUIDs as unique identifiers to track which notifications have been sent.

## Problem Statement

- Workshop data is deleted and refreshed every 6 hours
- Without tracking, users would receive the same notifications repeatedly
- This creates a poor user experience and notification fatigue

## Solution Architecture

### 1. Notification History Tracking

The system maintains a `notification_history` collection in MongoDB that tracks:
- Which notifications have been sent to which users
- For which workshops (using UUID)
- What type of notification was sent
- When it was sent

### 2. Notification Types

The system supports multiple notification types:

1. **`new_workshop`** - When a genuinely new workshop is added
2. **`schedule_change`** - When workshop date/time is modified
3. **`price_drop`** - When workshop price decreases
4. **`reopened`** - When a sold-out workshop has tickets available again
5. **`reminder_24h`** - 24-hour reminder before the workshop

### 3. Key Components

#### NotificationOperations Class

Handles all notification tracking logic:

```python
# Check if notification was already sent
has_notification_been_sent(user_id, workshop_uuid, notification_type)

# Record that a notification was sent
record_notification_sent(user_id, workshop_uuid, artist_id, notification_type, title, body)

# Check if workshop changed significantly
has_workshop_changed_significantly(workshop_uuid) -> (bool, change_type)

# Check if reminder should be sent
should_send_reminder(workshop_uuid, user_id)
```

#### Workshop Notification Watcher

Monitors MongoDB change streams for:
- **Insert operations**: New workshops → send `new_workshop` notifications
- **Update/Replace operations**: Check for significant changes → send appropriate notifications

#### Reminder Scheduler

Runs hourly to check for workshops happening in 24-48 hours and sends reminder notifications.

## How It Works

### 1. New Workshop Detection

```
1. Workshop inserted into database
2. Change stream detects insert operation
3. Extract workshop UUID and artist IDs
4. For each artist:
   - Get users with notifications enabled
   - Filter out users who already received notification
   - Send notification to remaining users
   - Record notification in history
```

### 2. Workshop Update Detection

```
1. Workshop updated in database
2. Change stream detects update operation
3. Check if changes are significant:
   - Time/date changes
   - Price drops
   - Availability changes
4. If significant, send appropriate notification type
5. Record in history to prevent duplicates
```

### 3. Reminder Notifications

```
1. Scheduler runs every hour
2. Find workshops happening in 24-48 hours
3. For each workshop:
   - Get users with notifications enabled for artists
   - Check if reminder already sent
   - Send reminder if not sent
   - Record in history
```

## Database Schema

### notification_history Collection

```javascript
{
  "_id": ObjectId,
  "user_id": "user_123",
  "workshop_uuid": "workshop_abc123",
  "artist_id": "artist_456",
  "notification_type": "new_workshop",
  "title": "🎉 Artist Name is back!",
  "body": "New workshop tickets available...",
  "is_sent": true,
  "sent_at": ISODate("2024-01-15T10:30:00Z"),
  "created_at": ISODate("2024-01-15T10:30:00Z")
}
```

### Indexes

1. **`user_workshop_type_sent_idx`** - Primary deduplication index
2. **`workshop_sent_date_idx`** - For finding latest notifications per workshop
3. **`sent_date_idx`** - For cleanup operations
4. **`user_sent_date_idx`** - For user-specific queries
5. **`artist_type_date_idx`** - For analytics
6. **`ttl_idx`** - Auto-delete after 90 days

## Setup Instructions

1. **Create Indexes**:
   ```bash
   python create_notification_indexes.py
   ```

2. **Start Server**:
   The notification watcher starts automatically when the server starts.

3. **Test Notifications**:
   ```bash
   # Send test notification
   curl -X POST http://localhost:8002/admin/api/send-test-notification \
     -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"artist_id": "artist_123"}'
   ```

## Monitoring & Maintenance

### Check Notification History

```python
# In MongoDB shell
db.notification_history.find({
  "user_id": "user_123",
  "workshop_uuid": "workshop_abc"
}).sort({"sent_at": -1})
```

### Clean Up Old Notifications

Notifications are automatically deleted after 90 days via TTL index, but you can manually clean up:

```python
# Python script
from datetime import datetime, timedelta
NotificationOperations.cleanup_old_notifications(days_to_keep=30)
```

### Debug Duplicate Issues

If users report duplicate notifications:

1. Check notification history:
   ```javascript
   db.notification_history.find({
     "user_id": "USER_ID",
     "sent_at": {$gte: ISODate("2024-01-15")}
   }).sort({"sent_at": -1})
   ```

2. Verify workshop UUID consistency:
   ```javascript
   db.workshops_v2.find({"uuid": "WORKSHOP_UUID"})
   ```

3. Check for multiple notification types for same workshop

## Best Practices

1. **Always use workshop UUID** as the primary identifier
2. **Record notifications immediately** after successful send
3. **Handle failures gracefully** - don't record if send fails
4. **Monitor TTL cleanup** to ensure old records are removed
5. **Test with production-like data** including workshop refreshes

## Troubleshooting

### Common Issues

1. **Notifications not sending**:
   - Check if already sent: `has_notification_been_sent()`
   - Verify user has device token registered
   - Check artist notification preferences

2. **Duplicate notifications**:
   - Verify workshop UUID is consistent
   - Check notification history for multiple entries
   - Ensure notification recording is atomic

3. **Missing notifications**:
   - Check change stream is running
   - Verify artist IDs are properly set
   - Check user reaction status

### Logs to Check

```bash
# Workshop changes
grep "Workshop change detected" server.log

# Notification sends
grep "Sending.*notification to" server.log

# Duplicate prevention
grep "already been notified" server.log
```

## Future Enhancements

1. **Batch notifications** for multiple workshops
2. **User notification preferences** (time of day, frequency)
3. **A/B testing** different notification messages
4. **Analytics dashboard** for notification performance
5. **Smart timing** based on user engagement patterns 