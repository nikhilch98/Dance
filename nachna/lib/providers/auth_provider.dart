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
    print('[AuthProvider] Starting logout process...');
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      print('[AuthProvider] Step 1: Clearing auth data from storage...');
      // Clear auth data first (local storage) with very short timeout
      // If this fails, we'll still continue with logout to ensure user gets logged out
      try {
        await AuthService.logout().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('[AuthProvider] WARNING: AuthService.logout() timed out - continuing with logout anyway');
          },
        );
        print('[AuthProvider] Step 1 completed: Auth service logout completed');
      } catch (storageError) {
        print('[AuthProvider] WARNING: Storage clearing failed: $storageError - continuing with logout anyway');
        // Don't let storage errors block logout
      }
      
      print('[AuthProvider] Step 2: Clearing global config...');
      // Clear global config on logout with timeout and error handling
      try {
        await _clearGlobalConfigOnLogout().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('[AuthProvider] WARNING: GlobalConfig.clearConfig() timed out - continuing with logout anyway');
          },
        );
        print('[AuthProvider] Step 2 completed: Global config cleared');
      } catch (configError) {
        print('[AuthProvider] WARNING: Global config clearing failed: $configError - continuing with logout anyway');
        // Don't let global config errors block logout
      }
      
      print('[AuthProvider] Step 3: Clearing local state...');
      // Clear all local state - this always succeeds
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      _state = AuthState.unauthenticated;
      
      print('[AuthProvider] Logout completed successfully');
    } catch (e) {
      print('[AuthProvider] Logout error: $e');
      // Even if there's an error, clear local state to ensure logout
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      _state = AuthState.unauthenticated;
    }
    
    // Always notify listeners at the end
    _debounceTimer?.cancel();
    notifyListeners();
    print('[AuthProvider] Logout process completed, state: $_state');
  }

  Future<bool> deleteAccount() async {
    print('[AuthProvider] Starting account deletion');
    
    // Set loading state
    _state = AuthState.loading;
    _internalLoading = true;
    _debounceTimer?.cancel();
    notifyListeners();

    try {
      print('[AuthProvider] Step 1: Calling delete account API...');
      // Call the deletion API first with timeout
      await AuthService.deleteAccount().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Account deletion API timed out');
        },
      );
      print('[AuthProvider] Step 1 completed: Account deletion API call successful');
      
      print('[AuthProvider] Step 2: Clearing global config after deletion...');
      // Clear global config after successful deletion with timeout and error handling
      try {
        await _clearGlobalConfigOnLogout().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[AuthProvider] WARNING: GlobalConfig.clearConfig() timed out during account deletion');
          },
        );
        print('[AuthProvider] Step 2 completed: Global config cleared after account deletion');
      } catch (configError) {
        print('[AuthProvider] WARNING: Global config clearing failed during account deletion: $configError');
        // Don't let global config errors block account deletion
      }
      
      print('[AuthProvider] Step 3: Clearing local state after deletion...');
      // Clear all local data
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      
      // Set to unauthenticated state to trigger navigation to login screen
      _state = AuthState.unauthenticated;
      print('[AuthProvider] AuthProvider state set to unauthenticated');
      
      // Notify listeners to trigger navigation
      _debounceTimer?.cancel();
      notifyListeners();
      print('[AuthProvider] Listeners notified of state change');
      
      return true;
    } catch (e) {
      print('[AuthProvider] Account deletion failed: $e');
      _errorMessage = 'Account deletion failed: $e';
      _state = AuthState.authenticatedError;
      _internalLoading = false;
      _debounceTimer?.cancel();
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

  // Force logout (immediate, bypasses all async operations)
  void forceLogout() {
    print('[AuthProvider] Force logout - immediate state clear');
    _debounceTimer?.cancel();
    
    // Immediately clear all state
    _user = null;
    _errorMessage = null;
    _internalLoading = false;
    _state = AuthState.unauthenticated;
    
    // Notify listeners immediately
    notifyListeners();
    print('[AuthProvider] Force logout completed, state: $_state');
    
    // Try to clear storage in background (fire and forget)
    Future.microtask(() async {
      try {
        print('[AuthProvider] Background: Attempting to clear auth storage...');
        await AuthService.logout().timeout(const Duration(seconds: 1));
        print('[AuthProvider] Background: Auth storage cleared');
      } catch (e) {
        print('[AuthProvider] Background: Failed to clear auth storage: $e');
      }
      
      try {
        print('[AuthProvider] Background: Attempting to clear global config...');
        await _clearGlobalConfigOnLogout().timeout(const Duration(seconds: 1));
        print('[AuthProvider] Background: Global config cleared');
      } catch (e) {
        print('[AuthProvider] Background: Failed to clear global config: $e');
      }
    });
  }
} 