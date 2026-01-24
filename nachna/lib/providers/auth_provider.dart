import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/global_config.dart';
import '../utils/logger.dart';
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

/// Provider that manages authentication state throughout the application.
///
/// This provider handles:
/// - User authentication (OTP-based login flow)
/// - Profile management (updates and profile completion)
/// - Session management (logout, account deletion)
/// - Global config synchronization on auth state changes
///
/// Uses debounced notifications to prevent excessive UI rebuilds.
class AuthProvider with ChangeNotifier {
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  bool _internalLoading = false;
  static const Duration _debounceDelay = Duration(milliseconds: 100);
  Timer? _debounceTimer;
  bool _isDisposed = false;

  /// Current authentication state of the user.
  AuthState get state => _state;

  /// Currently authenticated user, or null if not authenticated.
  User? get user => _user;

  /// Error message from the last failed operation, if any.
  String? get errorMessage => _errorMessage;

  /// Whether a top-level loading operation is in progress.
  bool get isLoading => _state == AuthState.loading;

  /// Whether an internal (background) loading operation is in progress.
  bool get isInternalLoading => _internalLoading;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Whether the authenticated user has completed their profile.
  bool get isProfileComplete => _user?.profileComplete ?? false;

  @override
  void dispose() {
    _isDisposed = true;
    _cancelDebounceTimer();
    super.dispose();
  }

  /// Safely cancel the debounce timer
  void _cancelDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Initializes authentication state by checking stored credentials.
  ///
  /// Checks if user is authenticated from stored data, loads user profile,
  /// and syncs global configuration. Sets appropriate [AuthState] based on
  /// whether user exists and profile is complete.
  Future<void> initializeAuth() async {
    _state = AuthState.loading;
    _internalLoading = true;
    _cancelDebounceTimer();
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
    _cancelDebounceTimer();
    notifyListeners();
  }

  /// Sends an OTP to the specified mobile number for authentication.
  ///
  /// Returns `true` if OTP was sent successfully, `false` otherwise.
  /// Sets [errorMessage] if the request fails.
  Future<bool> sendOTP({
    required String mobileNumber,
  }) async {
    _state = AuthState.loading;
    _internalLoading = true;
    _cancelDebounceTimer();
    notifyListeners();

    try {
      await AuthService.sendOTP(mobileNumber: mobileNumber);
      _errorMessage = null;
      _internalLoading = false;
      _state = AuthState.unauthenticated;
      _cancelDebounceTimer();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Verifies the OTP and logs in the user.
  ///
  /// Returns `true` if verification and login succeed, `false` otherwise.
  /// On success, sets [user] and updates [state] to authenticated or profileIncomplete.
  Future<bool> verifyOTPAndLogin({
    required String mobileNumber,
    required String otp,
  }) async {
    AppLogger.debug('Starting OTP verification', tag: 'AuthProvider');
    _state = AuthState.loading;
    _internalLoading = true;
    _cancelDebounceTimer();
    notifyListeners();

    try {
      final authResponse = await AuthService.verifyOTPAndLogin(
        mobileNumber: mobileNumber,
        otp: otp,
      );
      AppLogger.info('OTP verification successful', tag: 'AuthProvider');
      _user = authResponse.user;
      _state = authResponse.user.profileComplete ? AuthState.authenticated : AuthState.profileIncomplete;
      _errorMessage = null;
      _internalLoading = false;
      _cancelDebounceTimer();

      // Sync global config after successful login
      await _syncGlobalConfigOnAuth();

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('OTP verification failed', tag: 'AuthProvider', error: e);
      _setError(e.toString());
      return false;
    }
  }

  /// Updates the user's profile information.
  ///
  /// All parameters are optional. Returns `true` if update succeeds.
  /// Updates [user] with new profile data on success.
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



  /// Refreshes the user profile from the server.
  ///
  /// Updates [user] with latest data. Sets error state if refresh fails.
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

  /// Logs out the current user and clears all authentication data.
  ///
  /// Clears local storage, global config, and resets state to unauthenticated.
  /// Continues with logout even if individual cleanup steps fail.
  Future<void> logout() async {
    AppLogger.startOperation('Logout process', tag: 'AuthProvider');
    _state = AuthState.loading;
    _internalLoading = true;
    _cancelDebounceTimer();
    notifyListeners();

    try {
      AppLogger.debug('Step 1: Clearing auth data from storage', tag: 'AuthProvider');
      // Clear auth data first (local storage) with very short timeout
      // If this fails, we'll still continue with logout to ensure user gets logged out
      try {
        await AuthService.logout().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            AppLogger.warning('AuthService.logout() timed out', tag: 'AuthProvider');
          },
        );
        AppLogger.debug('Auth service logout completed', tag: 'AuthProvider');
      } catch (storageError) {
        AppLogger.warning('Storage clearing failed - continuing', tag: 'AuthProvider');
        // Don't let storage errors block logout
      }

      AppLogger.debug('Step 2: Clearing global config', tag: 'AuthProvider');
      // Clear global config on logout with timeout and error handling
      try {
        await _clearGlobalConfigOnLogout().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            AppLogger.warning('GlobalConfig.clearConfig() timed out', tag: 'AuthProvider');
          },
        );
        AppLogger.debug('Global config cleared', tag: 'AuthProvider');
      } catch (configError) {
        AppLogger.warning('Global config clearing failed - continuing', tag: 'AuthProvider');
        // Don't let global config errors block logout
      }

      AppLogger.debug('Step 3: Clearing local state', tag: 'AuthProvider');
      // Clear all local state - this always succeeds
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      _state = AuthState.unauthenticated;

      AppLogger.endOperation('Logout process', tag: 'AuthProvider', success: true);
    } catch (e) {
      AppLogger.error('Logout error', tag: 'AuthProvider', error: e);
      // Even if there's an error, clear local state to ensure logout
      _user = null;
      _errorMessage = null;
      _internalLoading = false;
      _state = AuthState.unauthenticated;
    }

    // Always notify listeners at the end
    _cancelDebounceTimer();
    notifyListeners();
  }

  /// Permanently deletes the user's account and all associated data.
  ///
  /// Returns `true` if deletion succeeds, `false` otherwise.
  /// On success, clears all local data and sets state to unauthenticated.
  Future<bool> deleteAccount() async {
    AppLogger.startOperation('Account deletion', tag: 'AuthProvider');

    // Set loading state
    _state = AuthState.loading;
    _internalLoading = true;
    _cancelDebounceTimer();
    notifyListeners();

    try {
      AppLogger.debug('Step 1: Calling delete account API', tag: 'AuthProvider');
      // Call the deletion API first with timeout
      await AuthService.deleteAccount().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Account deletion API timed out');
        },
      );
      AppLogger.debug('Account deletion API call successful', tag: 'AuthProvider');

      AppLogger.debug('Step 2: Clearing global config after deletion', tag: 'AuthProvider');
      // Clear global config after successful deletion with timeout and error handling
      try {
        await _clearGlobalConfigOnLogout().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            AppLogger.warning('GlobalConfig.clearConfig() timed out during account deletion', tag: 'AuthProvider');
          },
        );
        AppLogger.debug('Global config cleared after account deletion', tag: 'AuthProvider');
      } catch (configError) {
        AppLogger.warning('Global config clearing failed during account deletion', tag: 'AuthProvider');
        // Don't let global config errors block account deletion
      }

      AppLogger.debug('Step 3: Clearing local state after deletion', tag: 'AuthProvider');
      // Clear all local data
      _user = null;
      _errorMessage = null;
      _internalLoading = false;

      // Set to unauthenticated state to trigger navigation to login screen
      _state = AuthState.unauthenticated;

      // Notify listeners to trigger navigation
      _cancelDebounceTimer();
      notifyListeners();
      AppLogger.endOperation('Account deletion', tag: 'AuthProvider', success: true);

      return true;
    } catch (e) {
      AppLogger.error('Account deletion failed', tag: 'AuthProvider', error: e);
      _errorMessage = 'Account deletion failed: $e';
      _state = AuthState.authenticatedError;
      _internalLoading = false;
      _cancelDebounceTimer();
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
    _cancelDebounceTimer();
    notifyListeners();
  }

  void _setAuthenticatedError(String error) {
    _errorMessage = error;
    _state = AuthState.authenticatedError;
    _internalLoading = false;
    _cancelDebounceTimer();
    notifyListeners();
  }

  void _notifyListenersDebounced() {
    _cancelDebounceTimer();
    _debounceTimer = Timer(_debounceDelay, () {
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  /// Clears the current error message and restores appropriate state.
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

  /// Returns `true` if the user needs to complete their profile.
  bool shouldUpdateProfile() {
    return _state == AuthState.profileIncomplete && _user != null;
  }

  /// Returns a list of profile fields that are missing or empty.
  List<String> getMissingProfileFields() {
    if (_user == null) return [];
    final missing = <String>[];
    if (_user!.name == null || _user!.name!.isEmpty) missing.add('Name');
    if (_user!.dateOfBirth == null || _user!.dateOfBirth!.isEmpty) missing.add('Date of Birth');
    if (_user!.gender == null || _user!.gender!.isEmpty) missing.add('Gender');
    return missing;
  }

  /// Clears all authentication state without making any API calls.
  void clearAuthState() {
    AppLogger.debug('Clearing auth state', tag: 'AuthProvider');
    _user = null;
    _errorMessage = null;
    _internalLoading = false;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Helper method to sync global config after authentication
  Future<void> _syncGlobalConfigOnAuth() async {
    try {
      AppLogger.debug('Syncing global config after authentication', tag: 'AuthProvider');
      await GlobalConfig().fullSync();
      AppLogger.debug('Global config sync completed', tag: 'AuthProvider');
    } catch (e) {
      AppLogger.error('Error syncing global config', tag: 'AuthProvider', error: e);
      // Don't throw error - continue with app initialization
    }
  }

  /// Helper method to clear global config on logout
  Future<void> _clearGlobalConfigOnLogout() async {
    try {
      AppLogger.debug('Clearing global config on logout', tag: 'AuthProvider');
      await GlobalConfig().clearConfig();
      AppLogger.debug('Global config cleared successfully', tag: 'AuthProvider');
    } catch (e) {
      AppLogger.error('Error clearing global config', tag: 'AuthProvider', error: e);
      // Don't throw error - continue with logout
    }
  }

  /// Force logout that immediately clears state, bypassing async operations.
  ///
  /// Use when immediate logout is required without waiting for cleanup.
  /// Cleanup operations run in background after state is cleared.
  void forceLogout() {
    AppLogger.info('Force logout - immediate state clear', tag: 'AuthProvider');
    _cancelDebounceTimer();

    // Immediately clear all state
    _user = null;
    _errorMessage = null;
    _internalLoading = false;
    _state = AuthState.unauthenticated;

    // Notify listeners immediately
    notifyListeners();

    // Try to clear storage in background (fire and forget)
    Future.microtask(() async {
      try {
        await AuthService.logout().timeout(const Duration(seconds: 1));
        AppLogger.debug('Background: Auth storage cleared', tag: 'AuthProvider');
      } catch (e) {
        AppLogger.warning('Background: Failed to clear auth storage', tag: 'AuthProvider');
      }

      try {
        await _clearGlobalConfigOnLogout().timeout(const Duration(seconds: 1));
        AppLogger.debug('Background: Global config cleared', tag: 'AuthProvider');
      } catch (e) {
        AppLogger.warning('Background: Failed to clear global config', tag: 'AuthProvider');
      }
    });
  }
} 