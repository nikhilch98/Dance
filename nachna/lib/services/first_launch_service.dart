import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class FirstLaunchService {
  static final FirstLaunchService _instance = FirstLaunchService._internal();
  factory FirstLaunchService() => _instance;
  FirstLaunchService._internal();

  static const String _firstLaunchKey = 'first_launch_completed';
  static const String _notificationPermissionRequestedKey = 'notification_permission_requested';
  static const String _appVersionKey = 'app_version';

  /// Check if this is the first time the app is being launched
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasLaunchedBefore = prefs.getBool(_firstLaunchKey) ?? false;
      return !hasLaunchedBefore;
    } catch (e) {
      AppLogger.error('Error checking first launch', tag: 'FirstLaunch', error: e);
      return false;
    }
  }

  /// Mark the first launch as completed
  Future<void> markFirstLaunchCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, true);
      await prefs.setString(_appVersionKey, '1.0.0'); // Update as needed
      AppLogger.info('First launch marked as completed', tag: 'FirstLaunch');
    } catch (e) {
      AppLogger.error('Error marking first launch completed', tag: 'FirstLaunch', error: e);
    }
  }

  /// Check if notification permission has already been requested for a specific user
  Future<bool> hasRequestedNotificationPermission({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        // Per-user notification permission tracking
        final userKey = '${_notificationPermissionRequestedKey}_$userId';
        return prefs.getBool(userKey) ?? false;
      } else {
        // Fallback to global key for backward compatibility
        return prefs.getBool(_notificationPermissionRequestedKey) ?? false;
      }
    } catch (e) {
      AppLogger.error('Error checking notification permission request', tag: 'FirstLaunch', error: e);
      return false;
    }
  }

  /// Mark notification permission as requested for a specific user
  Future<void> markNotificationPermissionRequested({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        // Per-user notification permission tracking
        final userKey = '${_notificationPermissionRequestedKey}_$userId';
        await prefs.setBool(userKey, true);
        AppLogger.info('Notification permission marked as requested', tag: 'FirstLaunch');
      } else {
        // Fallback to global key for backward compatibility
        await prefs.setBool(_notificationPermissionRequestedKey, true);
        AppLogger.info('Notification permission marked as requested (global)', tag: 'FirstLaunch');
      }
    } catch (e) {
      AppLogger.error('Error marking notification permission requested', tag: 'FirstLaunch', error: e);
    }
  }

  /// Reset first launch status (useful for testing)
  Future<void> resetFirstLaunchStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_firstLaunchKey);
      await prefs.remove(_notificationPermissionRequestedKey);
      await prefs.remove(_appVersionKey);

      // Also remove all user-specific notification permission keys
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('${_notificationPermissionRequestedKey}_')) {
          await prefs.remove(key);
        }
      }

      AppLogger.info('First launch status reset', tag: 'FirstLaunch');
    } catch (e) {
      AppLogger.error('Error resetting first launch status', tag: 'FirstLaunch', error: e);
    }
  }

  /// Reset notification permission for a specific user (useful for testing)
  Future<void> resetNotificationPermissionForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = '${_notificationPermissionRequestedKey}_$userId';
      await prefs.remove(userKey);
      AppLogger.info('Notification permission reset for user', tag: 'FirstLaunch');
    } catch (e) {
      AppLogger.error('Error resetting notification permission for user', tag: 'FirstLaunch', error: e);
    }
  }

  /// Get app version from preferences
  Future<String?> getStoredAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_appVersionKey);
    } catch (e) {
      AppLogger.error('Error getting stored app version', tag: 'FirstLaunch', error: e);
      return null;
    }
  }

  /// Check if we should show the notification permission request for a specific user
  /// This considers whether permission was already requested for this user
  Future<bool> shouldRequestNotificationPermission({String? userId}) async {
    final hasRequested = await hasRequestedNotificationPermission(userId: userId);
    
    // Show if we haven't requested before for this user
    // This ensures each new user gets prompted for notification permissions
    return !hasRequested;
  }
} 