import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
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
    AppLogger.startOperation('Global config initialization', tag: 'GlobalConfig');
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

      AppLogger.debug('Config loaded: notifications=$_isNotificationsEnabled', tag: 'GlobalConfig');
      AppLogger.endOperation('Global config initialization', tag: 'GlobalConfig', success: true);
    } catch (e) {
      AppLogger.error('Error initializing global config', tag: 'GlobalConfig', error: e);
      // Re-initialize with defaults on error
      _deviceToken = null;
      _authToken = null;
      _userId = null;
      _isNotificationsEnabled = false;
      _lastUpdated = null;
    }
  }

  /// Update device token in global config
  Future<void> updateDeviceToken(String? deviceToken) async {
    if (_deviceToken != deviceToken) {
      AppLogger.debug('Updating device token', tag: 'GlobalConfig');
      _deviceToken = deviceToken;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Update auth token and user ID in global config
  Future<void> updateAuthToken(String? authToken, String? userId) async {
    if (_authToken != authToken || _userId != userId) {
      AppLogger.debug('Updating auth token and user ID', tag: 'GlobalConfig');
      _authToken = authToken;
      _userId = userId;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Update notification enabled status
  Future<void> updateNotificationStatus(bool isEnabled) async {
    if (_isNotificationsEnabled != isEnabled) {
      AppLogger.debug('Updating notification status: $isEnabled', tag: 'GlobalConfig');
      _isNotificationsEnabled = isEnabled;
      _lastUpdated = DateTime.now();
      await _persistConfig();
    }
  }

  /// Clear all config (on logout)
  Future<void> clearConfig() async {
    AppLogger.debug('Clearing all config', tag: 'GlobalConfig');
    _deviceToken = null;
    _authToken = null;
    _userId = null;
    _isNotificationsEnabled = false;
    _lastUpdated = DateTime.now();
    await _persistConfig();
  }

  /// Check and update device token if notifications are enabled
  Future<void> syncDeviceTokenIfNeeded() async {
    AppLogger.debug('Syncing device token if needed', tag: 'GlobalConfig');

    try {
      // Check if notifications are enabled for the app
      final notificationService = NotificationService();
      final isRegistered = await notificationService.isRegisteredForNotifications();

      AppLogger.debug('App registered for notifications: $isRegistered', tag: 'GlobalConfig');
      await updateNotificationStatus(isRegistered);

      if (isRegistered) {
        // Get current device token
        final currentDeviceToken = notificationService.deviceToken;

        if (currentDeviceToken != null) {
          await updateDeviceToken(currentDeviceToken);
        } else {
          // Try to initialize notifications to get token
          AppLogger.debug('No device token found, initializing notifications', tag: 'GlobalConfig');
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
      AppLogger.error('Error syncing device token', tag: 'GlobalConfig', error: e);
      // Continue with current state on error - don't block app initialization
    }
  }

  /// Check and update auth token from current auth state
  Future<void> syncAuthTokenIfNeeded() async {
    AppLogger.debug('Syncing auth token if needed', tag: 'GlobalConfig');

    try {
      final isAuthenticated = await AuthService.isAuthenticated();
      AppLogger.debug('User authenticated: $isAuthenticated', tag: 'GlobalConfig');

      if (isAuthenticated) {
        final currentAuthToken = await AuthService.getToken();
        final currentUser = await AuthService.getStoredUser();

        await updateAuthToken(currentAuthToken, currentUser?.userId);
      } else {
        // Clear auth data if not authenticated
        await updateAuthToken(null, null);
      }
    } catch (e) {
      AppLogger.error('Error syncing auth token', tag: 'GlobalConfig', error: e);
      // Continue with current state on error - don't block app initialization
    }
  }

  /// Full sync of both device token and auth token
  Future<void> fullSync() async {
    AppLogger.startOperation('Full sync', tag: 'GlobalConfig');
    await syncAuthTokenIfNeeded();
    await syncDeviceTokenIfNeeded();
    AppLogger.endOperation('Full sync', tag: 'GlobalConfig', success: true);
  }

  /// Cross-check device token with server and register if different
  Future<bool> crossCheckDeviceTokenWithServer() async {
    AppLogger.debug('Cross-checking device token with server', tag: 'GlobalConfig');

    try {
      // Only proceed if we have both auth token and device token
      if (_authToken == null || _userId == null) {
        AppLogger.debug('No auth token or user ID - skipping device token cross-check', tag: 'GlobalConfig');
        return false;
      }

      if (_deviceToken == null) {
        AppLogger.debug('No local device token - skipping cross-check', tag: 'GlobalConfig');
        return false;
      }

      // Call the sync method to cross-check and register if needed
      final result = await AuthService.syncDeviceTokenWithServer(
        localDeviceToken: _deviceToken!,
        platform: 'ios', // TODO: Detect platform dynamically if needed
      );

      final syncStatus = result['token_sync_status'] as String?;
      final serverDeviceToken = result['device_token'] as String?;

      AppLogger.debug('Device token sync result: $syncStatus', tag: 'GlobalConfig');

      // Update local device token if server has a different one
      if (serverDeviceToken != null && serverDeviceToken != _deviceToken) {
        await updateDeviceToken(serverDeviceToken);
      }

      return syncStatus == 'matched' || syncStatus == 'updated';
    } catch (e) {
      AppLogger.error('Error cross-checking device token', tag: 'GlobalConfig', error: e);
      return false;
    }
  }

  /// Enhanced sync that includes device token cross-checking with server
  Future<void> syncWithServerDeviceTokenCheck() async {
    AppLogger.startOperation('Sync with server device token check', tag: 'GlobalConfig');

    try {
      // First do local sync
      await syncAuthTokenIfNeeded();
      await syncDeviceTokenIfNeeded();

      // Then cross-check with server if authenticated
      if (_authToken != null && _userId != null && _deviceToken != null) {
        final success = await crossCheckDeviceTokenWithServer();
        if (success) {
          AppLogger.info('Device token successfully synced with server', tag: 'GlobalConfig');
        } else {
          AppLogger.warning('Device token sync with server failed or was skipped', tag: 'GlobalConfig');
        }
      }
    } catch (e) {
      AppLogger.error('Error during server sync', tag: 'GlobalConfig', error: e);
      // Continue - sync failures shouldn't block app functionality
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

      AppLogger.debug('Config persisted to storage', tag: 'GlobalConfig');
    } catch (e) {
      AppLogger.error('Error persisting config', tag: 'GlobalConfig', error: e);
      // Continue - persistence failure shouldn't crash the app
      // Config will be re-synced on next app launch
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
      'device_token_preview': AppLogger.truncateToken(_deviceToken),
      'auth_token_preview': AppLogger.truncateToken(_authToken),
    };
  }

  /// Debug method to print current config
  void debugPrintConfig() {
    AppLogger.group('Current GlobalConfig', () {
      AppLogger.debug('Notifications Enabled: $_isNotificationsEnabled', tag: 'GlobalConfig');
      AppLogger.debug('Last Updated: $_lastUpdated', tag: 'GlobalConfig');
    });
  }
} 