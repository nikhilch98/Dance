import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import './auth_service.dart';
import './notification_service.dart';

class GlobalConfig {
  static final GlobalConfig _instance = GlobalConfig._internal();
  factory GlobalConfig() => _instance;
  GlobalConfig._internal();

  // Configuration keys
  static const String _deviceTokenKey = 'global_device_token';
  static const String _authTokenKey = 'global_auth_token';
  static const String _userIdKey = 'global_user_id';
  static const String _isNotificationsEnabledKey = 'global_notifications_enabled';
  static const String _lastUpdatedKey = 'global_last_updated';

  // In-memory config
  String? _deviceToken;
  String? _authToken;
  String? _userId;
  bool _isNotificationsEnabled = false;
  DateTime? _lastUpdated;

  // Getters
  String? get deviceToken => _deviceToken;
  String? get authToken => _authToken;
  String? get userId => _userId;
  bool get isNotificationsEnabled => _isNotificationsEnabled;
  DateTime? get lastUpdated => _lastUpdated;

  /// Initialize global config - load from persistent storage
  Future<void> initialize() async {
    print('[GlobalConfig] ===== INITIALIZING GLOBAL CONFIG =====');
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _deviceToken = prefs.getString(_deviceTokenKey);
      _authToken = prefs.getString(_authTokenKey);
      _userId = prefs.getString(_userIdKey);
      _isNotificationsEnabled = prefs.getBool(_isNotificationsEnabledKey) ?? false;
      
      final lastUpdatedString = prefs.getString(_lastUpdatedKey);
      if (lastUpdatedString != null) {
        _lastUpdated = DateTime.tryParse(lastUpdatedString);
      }

      print('[GlobalConfig] Loaded from storage:');
      print('[GlobalConfig] - Device Token: ${_deviceToken?.substring(0, 20) ?? 'null'}...');
      print('[GlobalConfig] - Auth Token: ${_authToken?.substring(0, 20) ?? 'null'}...');
      print('[GlobalConfig] - User ID: $_userId');
      print('[GlobalConfig] - Notifications Enabled: $_isNotificationsEnabled');
      print('[GlobalConfig] - Last Updated: $_lastUpdated');
    } catch (e) {
      print('[GlobalConfig] Error loading config: $e');
    }
  }

  /// Update device token in global config
  Future<void> updateDeviceToken(String? deviceToken) async {
    if (_deviceToken != deviceToken) {
      print('[GlobalConfig] Updating device token: ${deviceToken?.substring(0, 20) ?? 'null'}...');
      _deviceToken = deviceToken;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Update auth token and user ID in global config
  Future<void> updateAuthToken(String? authToken, String? userId) async {
    if (_authToken != authToken || _userId != userId) {
      print('[GlobalConfig] Updating auth token and user ID');
      print('[GlobalConfig] - Auth Token: ${authToken?.substring(0, 20) ?? 'null'}...');
      print('[GlobalConfig] - User ID: $userId');
      _authToken = authToken;
      _userId = userId;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Update notification enabled status
  Future<void> updateNotificationStatus(bool isEnabled) async {
    if (_isNotificationsEnabled != isEnabled) {
      print('[GlobalConfig] Updating notification status: $isEnabled');
      _isNotificationsEnabled = isEnabled;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Clear all config (on logout)
  Future<void> clearConfig() async {
    print('[GlobalConfig] Clearing all config');
    _deviceToken = null;
    _authToken = null;
    _userId = null;
    _isNotificationsEnabled = false;
    _lastUpdated = DateTime.now();
    await _persistConfig();
  }

  /// Check and update device token if notifications are enabled
  Future<void> syncDeviceTokenIfNeeded() async {
    print('[GlobalConfig] ===== SYNCING DEVICE TOKEN IF NEEDED =====');
    
    try {
      // Check if notifications are enabled for the app
      final notificationService = NotificationService();
      final isRegistered = await notificationService.isRegisteredForNotifications();
      
      print('[GlobalConfig] App registered for notifications: $isRegistered');
      await updateNotificationStatus(isRegistered);
      
      if (isRegistered) {
        // Get current device token
        final currentDeviceToken = notificationService.deviceToken;
        print('[GlobalConfig] Current device token: ${currentDeviceToken?.substring(0, 20) ?? 'null'}...');
        
        if (currentDeviceToken != null) {
          await updateDeviceToken(currentDeviceToken);
        } else {
          // Try to initialize notifications to get token
          print('[GlobalConfig] No device token found, initializing notifications...');
          final token = await notificationService.initialize();
          if (token != null) {
            await updateDeviceToken(token);
          }
        }
      } else {
        // Clear device token if notifications are disabled
        await updateDeviceToken(null);
      }
    } catch (e) {
      print('[GlobalConfig] Error syncing device token: $e');
    }
  }

  /// Check and update auth token from current auth state
  Future<void> syncAuthTokenIfNeeded() async {
    print('[GlobalConfig] ===== SYNCING AUTH TOKEN IF NEEDED =====');
    
    try {
      final isAuthenticated = await AuthService.isAuthenticated();
      print('[GlobalConfig] User authenticated: $isAuthenticated');
      
      if (isAuthenticated) {
        final currentAuthToken = await AuthService.getToken();
        final currentUser = await AuthService.getStoredUser();
        
        print('[GlobalConfig] Current auth token: ${currentAuthToken?.substring(0, 20) ?? 'null'}...');
        print('[GlobalConfig] Current user ID: ${currentUser?.userId}');
        
        await updateAuthToken(currentAuthToken, currentUser?.userId);
      } else {
        // Clear auth data if not authenticated
        await updateAuthToken(null, null);
      }
    } catch (e) {
      print('[GlobalConfig] Error syncing auth token: $e');
    }
  }

  /// Full sync of both device token and auth token
  Future<void> fullSync() async {
    print('[GlobalConfig] ===== PERFORMING FULL SYNC =====');
    await syncAuthTokenIfNeeded();
    await syncDeviceTokenIfNeeded();
    print('[GlobalConfig] ===== FULL SYNC COMPLETE =====');
  }

  /// Cross-check device token with server and register if different
  Future<bool> crossCheckDeviceTokenWithServer() async {
    print('[GlobalConfig] ===== CROSS-CHECKING DEVICE TOKEN WITH SERVER =====');
    
    try {
      // Only proceed if we have both auth token and device token
      if (_authToken == null || _userId == null) {
        print('[GlobalConfig] No auth token or user ID - skipping device token cross-check');
        return false;
      }
      
      if (_deviceToken == null) {
        print('[GlobalConfig] No local device token - skipping cross-check');
        return false;
      }
      
      // Call the sync method to cross-check and register if needed
      final result = await AuthService.syncDeviceTokenWithServer(
        localDeviceToken: _deviceToken!,
        platform: 'ios', // TODO: Detect platform dynamically if needed
      );
      
      final syncStatus = result['token_sync_status'] as String?;
      final serverDeviceToken = result['device_token'] as String?;
      
      print('[GlobalConfig] Device token sync result: $syncStatus');
      
      // Update local device token if server has a different one
      if (serverDeviceToken != null && serverDeviceToken != _deviceToken) {
        await updateDeviceToken(serverDeviceToken);
      }
      
      return syncStatus == 'matched' || syncStatus == 'updated';
    } catch (e) {
      print('[GlobalConfig] Error cross-checking device token: $e');
      return false;
    }
  }

  /// Enhanced sync that includes device token cross-checking with server
  Future<void> syncWithServerDeviceTokenCheck() async {
    print('[GlobalConfig] ===== SYNCING WITH SERVER DEVICE TOKEN CHECK =====');
    
    try {
      // First do local sync
      await syncAuthTokenIfNeeded();
      await syncDeviceTokenIfNeeded();
      
      // Then cross-check with server if authenticated
      if (_authToken != null && _userId != null && _deviceToken != null) {
        final success = await crossCheckDeviceTokenWithServer();
        if (success) {
          print('[GlobalConfig] Device token successfully synced with server');
        } else {
          print('[GlobalConfig] Device token sync with server failed or was skipped');
        }
      }
    } catch (e) {
      print('[GlobalConfig] Error during server sync with device token check: $e');
    }
  }

  /// Persist config to shared preferences
  Future<void> _persistConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_deviceToken != null) {
        await prefs.setString(_deviceTokenKey, _deviceToken!);
      } else {
        await prefs.remove(_deviceTokenKey);
      }
      
      if (_authToken != null) {
        await prefs.setString(_authTokenKey, _authToken!);
      } else {
        await prefs.remove(_authTokenKey);
      }
      
      if (_userId != null) {
        await prefs.setString(_userIdKey, _userId!);
      } else {
        await prefs.remove(_userIdKey);
      }
      
      await prefs.setBool(_isNotificationsEnabledKey, _isNotificationsEnabled);
      
      if (_lastUpdated != null) {
        await prefs.setString(_lastUpdatedKey, _lastUpdated!.toIso8601String());
      }
      
      print('[GlobalConfig] Config persisted to storage');
    } catch (e) {
      print('[GlobalConfig] Error persisting config: $e');
    }
  }

  /// Get config as map for admin panel display
  Map<String, dynamic> getConfigForAdmin() {
    return {
      'device_token': _deviceToken,
      'auth_token': _authToken,
      'user_id': _userId,
      'notifications_enabled': _isNotificationsEnabled,
      'last_updated': _lastUpdated?.toIso8601String(),
      'device_token_preview': _deviceToken?.substring(0, 20),
      'auth_token_preview': _authToken?.substring(0, 20),
    };
  }

  /// Debug method to print current config
  void debugPrintConfig() {
    print('[GlobalConfig] ===== CURRENT CONFIG =====');
    print('[GlobalConfig] Device Token: ${_deviceToken?.substring(0, 20) ?? 'null'}...');
    print('[GlobalConfig] Auth Token: ${_authToken?.substring(0, 20) ?? 'null'}...');
    print('[GlobalConfig] User ID: $_userId');
    print('[GlobalConfig] Notifications Enabled: $_isNotificationsEnabled');
    print('[GlobalConfig] Last Updated: $_lastUpdated');
    print('[GlobalConfig] ==============================');
  }
} 