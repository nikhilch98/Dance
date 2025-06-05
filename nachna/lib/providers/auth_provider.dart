import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/global_config.dart';
import '../main.dart';
import 'dart:async';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  profileIncomplete,
  error,
  authenticatedError,
}

class AuthProvider with ChangeNotifier {
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  bool _internalLoading = false;
  static const Duration _debounceDelay = Duration(milliseconds: 100);
  Timer? _debounceTimer;
  bool _isDisposed = false;

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == AuthState.loading;
  bool get isInternalLoading => _internalLoading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isProfileComplete => _user?.profileComplete ?? false;

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> initializeAuth() async {
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      final isAuth = await AuthService.isAuthenticated();
      if (isAuth) {
        final storedUser = await AuthService.getStoredUser();
        if (storedUser != null) {
          _user = storedUser;
          _state = storedUser.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete;
          
          // Sync global config on successful authentication
          await _syncGlobalConfigOnAuth();
        } else {
          _state = AuthState.unauthenticated;
        }
      } else {
        _state = AuthState.unauthenticated;
      }
      _errorMessage = null;
    } catch (e) {
      _setError('Failed to initialize authentication: $e');
      return;
    }
    _internalLoading = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  Future<bool> register({
    required String mobileNumber,
    required String password,
  }) async {
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      final authResponse = await AuthService.register(
        mobileNumber: mobileNumber,
        password: password,
      );
      _user = authResponse.user;
      _state = AuthState.profileIncomplete;
      _errorMessage = null;
      _internalLoading = false;
      _debounceTimer?.cancel();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String mobileNumber,
    required String password,
  }) async {
    print('[AuthProvider] Starting login with mobile: $mobileNumber');
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      final authResponse = await AuthService.login(
        mobileNumber: mobileNumber,
        password: password,
      );
      print('[AuthProvider] Login successful');
      _user = authResponse.user;
      _state = authResponse.user.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete;
      _errorMessage = null;
      _internalLoading = false;
      _debounceTimer?.cancel();
      
      // Sync global config after successful login
      await _syncGlobalConfigOnAuth();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('[AuthProvider] Login failed with error: $e');
      _setError(e.toString());
      print('[AuthProvider] After _setError - state: $_state, errorMessage: $_errorMessage');
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? dateOfBirth,
    String? gender,
  }) async {
    _setInternalLoading(true);
    try {
      final updatedUser = await AuthService.updateProfile(
        name: name,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );
      _user = updatedUser;
      _setState(updatedUser.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete);
      _setInternalLoading(false);
      return true;
    } catch (e) {
      _setInternalLoading(false);
      _setAuthenticatedError('Failed to update profile: $e');
      return false;
    }
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setInternalLoading(true);
    try {
      await AuthService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setInternalLoading(false);
      return true;
    } catch (e) {
      _setInternalLoading(false);
      _setAuthenticatedError('Failed to update password: $e');
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      _user = currentUser;
      _setState(currentUser.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete);
    } catch (e) {
      if (_state == AuthState.authenticated || _state == AuthState.profileIncomplete) {
        _setAuthenticatedError('Failed to refresh profile: $e');
      } else {
        _setError('Failed to refresh profile: $e');
      }
    }
  }

  Future<void> logout() async {
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      // Clear global config on logout
      await _clearGlobalConfigOnLogout();
      
      await AuthService.logout();
      _user = null;
      _state = AuthState.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _user = null;
      _state = AuthState.unauthenticated;
      _errorMessage = 'Logout API call failed: $e. Logged out locally.';
    } finally {
      _internalLoading = false;
      _debounceTimer?.cancel();
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    print('[AuthProvider] Starting account deletion');
    
    // Set loading state
    _state = AuthState.loading;
    notifyListeners();

    try {
      // Clear global config before account deletion
      await _clearGlobalConfigOnLogout();
      
      // Call the deletion API
      await AuthService.deleteAccount();
      print('[AuthProvider] Account deletion API call successful');
      
      // Clear all local data
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      
      // Set to unauthenticated state
      _state = AuthState.unauthenticated;
      print('[AuthProvider] AuthProvider state set to unauthenticated');
      
      // Notify listeners
      notifyListeners();
      print('[AuthProvider] Listeners notified of state change');
      
      return true;
    } catch (e) {
      print('[AuthProvider] Account deletion failed: $e');
      _errorMessage = 'Account deletion failed: $e';
      _state = AuthState.authenticatedError;
      _internalLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      if (newState != AuthState.error && newState != AuthState.authenticatedError) {
        _errorMessage = null;
      }
      _notifyListenersDebounced();
    }
  }

  void _setInternalLoading(bool loading) {
    if (_internalLoading != loading) {
      _internalLoading = loading;
      _notifyListenersDebounced();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    _state = AuthState.error;
    _internalLoading = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }



  void _setAuthenticatedError(String error) {
    _errorMessage = error;
    _state = AuthState.authenticatedError;
    _internalLoading = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  void _notifyListenersDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      if (_state == AuthState.error && _user == null) {
         _setState(AuthState.unauthenticated);
      } else if (_state == AuthState.authenticatedError && _user != null) {
         _setState(_user!.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete);
      } else {
         notifyListeners();
      }
    }
  }

  bool shouldUpdateProfile() {
    return _state == AuthState.profileIncomplete && _user != null;
  }

  List<String> getMissingProfileFields() {
    if (_user == null) return [];
    final missing = <String>[];
    if (_user!.name == null || _user!.name!.isEmpty) missing.add('Name');
    if (_user!.dateOfBirth == null || _user!.dateOfBirth!.isEmpty) missing.add('Date of Birth');
    if (_user!.gender == null || _user!.gender!.isEmpty) missing.add('Gender');
    return missing;
  }

  void clearAuthState() {
    print('[AuthProvider] Clearing auth state');
    _user = null;
    _errorMessage = null;
    _internalLoading = false;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Helper method to sync global config after authentication
  Future<void> _syncGlobalConfigOnAuth() async {
    try {
      print('[AuthProvider] Syncing global config after authentication...');
      await GlobalConfig().fullSync();
      print('[AuthProvider] Global config sync completed');
    } catch (e) {
      print('[AuthProvider] Error syncing global config: $e');
      // Don't throw error - continue with app initialization
    }
  }

  /// Helper method to clear global config on logout
  Future<void> _clearGlobalConfigOnLogout() async {
    try {
      print('[AuthProvider] Clearing global config on logout...');
      await GlobalConfig().clearConfig();
      print('[AuthProvider] Global config cleared successfully');
    } catch (e) {
      print('[AuthProvider] Error clearing global config: $e');
      // Don't throw error - continue with logout
    }
  }
} 