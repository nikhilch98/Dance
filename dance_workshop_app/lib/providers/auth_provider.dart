import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'dart:async';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  profileIncomplete,
  error,
}

class AuthProvider with ChangeNotifier {
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  bool _isLoading = false;
  static const Duration _debounceDelay = Duration(milliseconds: 100); // Add debouncing for performance
  Timer? _debounceTimer;

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isProfileComplete => _user?.profileComplete ?? false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Initialize authentication state
  Future<void> initializeAuth() async {
    _setState(AuthState.loading);
    
    try {
      final isAuth = await AuthService.isAuthenticated();
      if (isAuth) {
        final storedUser = await AuthService.getStoredUser();
        if (storedUser != null) {
          _user = storedUser;
          
          // Check if profile is complete
          if (storedUser.profileComplete) {
            _setState(AuthState.authenticated);
          } else {
            _setState(AuthState.profileIncomplete);
          }
        } else {
          _setState(AuthState.unauthenticated);
        }
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setError('Failed to initialize authentication: $e');
    }
  }

  // Register new user
  Future<bool> register({
    required String mobileNumber,
    required String password,
  }) async {
    _setLoading(true);
    
    try {
      final authResponse = await AuthService.register(
        mobileNumber: mobileNumber,
        password: password,
      );
      
      _user = authResponse.user;
      
      // After registration, user needs to complete profile
      _setState(AuthState.profileIncomplete);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Login user
  Future<bool> login({
    required String mobileNumber,
    required String password,
  }) async {
    _setLoading(true);
    
    try {
      final authResponse = await AuthService.login(
        mobileNumber: mobileNumber,
        password: password,
      );
      
      _user = authResponse.user;
      
      // Check if profile is complete
      if (authResponse.user.profileComplete) {
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.profileIncomplete);
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? dateOfBirth,
    String? gender,
  }) async {
    _setLoading(true);
    
    try {
      final updatedUser = await AuthService.updateProfile(
        name: name,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );
      
      _user = updatedUser;
      
      // Check if profile is now complete
      if (updatedUser.profileComplete) {
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.profileIncomplete);
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    
    try {
      await AuthService.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Refresh user profile
  Future<void> refreshProfile() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      _user = currentUser;
      
      // Update state based on profile completeness
      if (currentUser.profileComplete) {
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.profileIncomplete);
      }
    } catch (e) {
      _setError('Failed to refresh profile: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await AuthService.logout();
      _user = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError('Logout failed: $e');
    }
    
    _setLoading(false);
  }

  // Helper methods with performance optimization
  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      _errorMessage = null;
      _notifyListenersDebounced();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      _notifyListenersDebounced();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    _state = AuthState.error;
    _isLoading = false;
    _notifyListenersDebounced();
  }

  // Debounced notifyListeners for better performance
  void _notifyListenersDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      notifyListeners();
    });
  }

  // Clear error message with immediate notification for UX
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners(); // Immediate notification for clearing errors
    }
  }

  // Helper method to check if profile update is needed
  bool shouldUpdateProfile() {
    return _state == AuthState.profileIncomplete && _user != null;
  }

  // Helper method to get missing profile fields
  List<String> getMissingProfileFields() {
    if (_user == null) return [];
    
    final missing = <String>[];
    if (_user!.name == null || _user!.name!.isEmpty) missing.add('Name');
    if (_user!.dateOfBirth == null || _user!.dateOfBirth!.isEmpty) missing.add('Date of Birth');
    if (_user!.gender == null || _user!.gender!.isEmpty) missing.add('Gender');
    
    return missing;
  }
} 