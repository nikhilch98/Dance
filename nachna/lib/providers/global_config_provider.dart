import 'package:flutter/foundation.dart';
import '../services/global_config.dart';
import '../services/first_launch_service.dart';

class GlobalConfigProvider with ChangeNotifier {
  final GlobalConfig _globalConfig = GlobalConfig();
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get deviceToken => _globalConfig.deviceToken;
  String? get authToken => _globalConfig.authToken;
  String? get userId => _globalConfig.userId;
  bool get isNotificationsEnabled => _globalConfig.isNotificationsEnabled;
  DateTime? get lastUpdated => _globalConfig.lastUpdated;

  // Initialize the global config
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      await _globalConfig.initialize();
      _isInitialized = true;
    } catch (e) {
      print('[GlobalConfigProvider] Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update device token
  Future<void> updateDeviceToken(String? deviceToken) async {
    await _globalConfig.updateDeviceToken(deviceToken);
    notifyListeners();
  }

  // Update auth token and user ID
  Future<void> updateAuthToken(String? authToken, String? userId) async {
    await _globalConfig.updateAuthToken(authToken, userId);
    notifyListeners();
  }

  // Update notification status
  Future<void> updateNotificationStatus(bool isEnabled) async {
    await _globalConfig.updateNotificationStatus(isEnabled);
    notifyListeners();
  }

  // Clear all config
  Future<void> clearConfig() async {
    await _globalConfig.clearConfig();
    notifyListeners();
  }

  // Sync device token if needed
  Future<void> syncDeviceTokenIfNeeded() async {
    await _globalConfig.syncDeviceTokenIfNeeded();
    notifyListeners();
  }

  // Sync auth token if needed
  Future<void> syncAuthTokenIfNeeded() async {
    await _globalConfig.syncAuthTokenIfNeeded();
    notifyListeners();
  }

  // Full sync
  Future<void> fullSync() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _globalConfig.fullSync();
    } catch (e) {
      print('[GlobalConfigProvider] Error during full sync: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get config for admin display
  Map<String, dynamic> getConfigForAdmin() {
    return _globalConfig.getConfigForAdmin();
  }

  // Debug print config
  void debugPrintConfig() {
    _globalConfig.debugPrintConfig();
  }

  // Format data for display
  String formatTokenForDisplay(String? token) {
    if (token == null || token.isEmpty) {
      return 'Not set';
    }
    if (token.length <= 20) {
      return token;
    }
    return '${token.substring(0, 10)}...${token.substring(token.length - 10)}';
  }

  String formatDateForDisplay(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Never';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Get status summary
  Map<String, dynamic> getStatusSummary() {
    return {
      'hasDeviceToken': deviceToken != null && deviceToken!.isNotEmpty,
      'hasAuthToken': authToken != null && authToken!.isNotEmpty,
      'hasUserId': userId != null && userId!.isNotEmpty,
      'notificationsEnabled': isNotificationsEnabled,
      'lastSyncAge': lastUpdated != null 
          ? DateTime.now().difference(lastUpdated!).inMinutes
          : null,
    };
  }

  /// Reset first launch status (for testing)
  Future<void> resetFirstLaunchStatus() async {
    try {
      await FirstLaunchService().resetFirstLaunchStatus();
      notifyListeners();
    } catch (e) {
      print('[GlobalConfigProvider] Error resetting first launch status: $e');
    }
  }
} 