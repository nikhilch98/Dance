import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

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

  // Getters
  ConfigState get state => _state;
  AppConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _config?.isAdmin ?? false;
  bool get isLoaded => _state == ConfigState.loaded;

  // Load configuration
  Future<void> loadConfig() async {
    print('[ConfigProvider] loadConfig called - current state: $_state');
    if (_state == ConfigState.loading) {
      print('[ConfigProvider] Already loading, skipping...');
      return; // Prevent multiple concurrent loads
    }
    
    print('[ConfigProvider] Setting state to loading...');
    _setState(ConfigState.loading);
    
    try {
      print('[ConfigProvider] Calling ApiService.getConfig()...');
      final configData = await ApiService.getConfig();
      print('[ConfigProvider] Config data received: $configData');
      _config = AppConfig.fromJson(configData);
      print('[ConfigProvider] Config parsed - isAdmin: ${_config?.isAdmin}');
      _setState(ConfigState.loaded);
      print('[ConfigProvider] Config loaded successfully');
    } catch (e) {
      print('[ConfigProvider] Config loading failed: $e');
      _setError('Failed to load configuration: $e');
    }
  }

  // Refresh configuration
  Future<void> refreshConfig() async {
    await loadConfig();
  }

  // Clear configuration (on logout)
  void clearConfig() {
    _config = null;
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