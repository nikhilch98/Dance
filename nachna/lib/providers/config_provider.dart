import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/global_config.dart';
import '../utils/validators.dart';
import '../utils/logger.dart';

enum ConfigState {
  initial,
  loading,
  loaded,
  error,
}

class ConfigProvider with ChangeNotifier {
  ConfigState _state = ConfigState.initial;
  AppConfig? _config;
  String? _errorMessage;
  DateTime? _lastFailedAttempt;
  bool _isLoadingInProgress = false;

  // Getters
  ConfigState get state => _state;
  AppConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _config?.isAdmin ?? false;
  bool get isLoaded => _state == ConfigState.loaded;

  // Load configuration with device token synchronization
  Future<void> loadConfig() async {
    // Prevent multiple concurrent loads
    if (_isLoadingInProgress) {
      AppLogger.debug('Load already in progress, skipping', tag: 'ConfigProvider');
      return;
    }

    // Prevent rapid retries after failure (cooldown period)
    if (_lastFailedAttempt != null) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailedAttempt!);
      if (timeSinceLastFailure.inSeconds < 10) {
        AppLogger.debug('Cooldown period active, skipping load', tag: 'ConfigProvider');
        return;
      }
    }

    _isLoadingInProgress = true;
    _setState(ConfigState.loading);

    try {
      AppLogger.debug('Loading config and syncing device token', tag: 'ConfigProvider');

      // First sync device token with server if possible
      try {
        await GlobalConfig().syncWithServerDeviceTokenCheck();
      } catch (e) {
        AppLogger.warning('Device token sync failed, continuing with config load', tag: 'ConfigProvider');
      }

      // Load config from auth API (which includes device token info)
      final configData = await AuthService.getAuthConfig();
      _config = AppConfig.fromJson(configData);

      AppLogger.info('Config loaded successfully', tag: 'ConfigProvider');
      AppLogger.debug('Is Admin: ${_config?.isAdmin}', tag: 'ConfigProvider');
      AppLogger.debug('Device Token: ${SecureLogger.maskToken(configData['device_token']?.toString())}', tag: 'ConfigProvider');

      _lastFailedAttempt = null; // Clear failure timestamp on success
      _setState(ConfigState.loaded);
    } catch (e) {
      AppLogger.error('Error loading config', tag: 'ConfigProvider', error: e);
      _lastFailedAttempt = DateTime.now(); // Record failure timestamp
      _setError('Failed to load configuration: $e');
    } finally {
      _isLoadingInProgress = false;
    }
  }

  // Refresh configuration with device token sync
  Future<void> refreshConfig() async {
    AppLogger.debug('Refreshing config', tag: 'ConfigProvider');

    // Reset cooldown for manual refresh
    _lastFailedAttempt = null;

    await loadConfig();
  }

  // Clear configuration (on logout)
  void clearConfig() {
    AppLogger.debug('Clearing config', tag: 'ConfigProvider');
    _config = null;
    _lastFailedAttempt = null;
    _isLoadingInProgress = false;
    _setState(ConfigState.initial);
  }

  // Helper methods
  void _setState(ConfigState newState) {
    if (_state != newState) {
      _state = newState;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    _state = ConfigState.error;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
} 