import 'package:shared_preferences/shared_preferences.dart';

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
      print('[FirstLaunchService] Error checking first launch: $e');
      return false;
    }
  }

  /// Mark the first launch as completed
  Future<void> markFirstLaunchCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, true);
      await prefs.setString(_appVersionKey, '1.0.0'); // Update as needed
      print('[FirstLaunchService] First launch marked as completed');
    } catch (e) {
      print('[FirstLaunchService] Error marking first launch completed: $e');
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
      print('[FirstLaunchService] Error checking notification permission request: $e');
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
        print('[FirstLaunchService] Notification permission marked as requested for user: $userId');
      } else {
        // Fallback to global key for backward compatibility
        await prefs.setBool(_notificationPermissionRequestedKey, true);
        print('[FirstLaunchService] Notification permission marked as requested (global)');
      }
    } catch (e) {
      print('[FirstLaunchService] Error marking notification permission requested: $e');
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
      
      print('[FirstLaunchService] First launch status reset');
    } catch (e) {
      print('[FirstLaunchService] Error resetting first launch status: $e');
    }
  }

  /// Reset notification permission for a specific user (useful for testing)
  Future<void> resetNotificationPermissionForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = '${_notificationPermissionRequestedKey}_$userId';
      await prefs.remove(userKey);
      print('[FirstLaunchService] Notification permission reset for user: $userId');
    } catch (e) {
      print('[FirstLaunchService] Error resetting notification permission for user: $e');
    }
  }

  /// Get app version from preferences
  Future<String?> getStoredAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_appVersionKey);
    } catch (e) {
      print('[FirstLaunchService] Error getting stored app version: $e');
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