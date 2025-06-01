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
    if (_state == ConfigState.loading) return; // Prevent multiple concurrent loads
    
    _setState(ConfigState.loading);
    
    try {
      final configData = await ApiService.getConfig();
      _config = AppConfig.fromJson(configData);
      _setState(ConfigState.loaded);
    } catch (e) {
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