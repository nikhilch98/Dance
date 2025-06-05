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

  /// Check if notification permission has already been requested
  Future<bool> hasRequestedNotificationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_notificationPermissionRequestedKey) ?? false;
    } catch (e) {
      print('[FirstLaunchService] Error checking notification permission request: $e');
      return false;
    }
  }

  /// Mark notification permission as requested
  Future<void> markNotificationPermissionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationPermissionRequestedKey, true);
      print('[FirstLaunchService] Notification permission marked as requested');
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
      print('[FirstLaunchService] First launch status reset');
    } catch (e) {
      print('[FirstLaunchService] Error resetting first launch status: $e');
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

  /// Check if we should show the notification permission request
  /// This considers both first launch and whether permission was already requested
  Future<bool> shouldRequestNotificationPermission() async {
    final isFirst = await isFirstLaunch();
    final hasRequested = await hasRequestedNotificationPermission();
    
    // Show if it's first launch and we haven't requested before
    return isFirst && !hasRequested;
  }
} 