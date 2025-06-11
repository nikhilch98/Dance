import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/user.dart';
import './http_client_service.dart';

class AuthService {
  static const String _baseUrl = 'https://nachna.com/api/auth';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  // Get the HTTP client instance
  static http.Client get _httpClient => HttpClientService.instance.client;

  // Send OTP to mobile number
  static Future<String> sendOTP({
    required String mobileNumber,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: HttpClientService.getHeaders(),
        body: jsonEncode({
          'mobile_number': mobileNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'OTP sent successfully';
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Verify OTP and login/register user
  static Future<AuthResponse> verifyOTPAndLogin({
    required String mobileNumber,
    required String otp,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: HttpClientService.getHeaders(),
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'OTP verification failed');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Get current user profile
  static Future<User> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/profile'),
        headers: HttpClientService.getHeaders(authToken: token),
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        await _saveUser(user);
        return user;
      } else {
        throw AuthException('Failed to fetch user profile');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Get app config with device token sync via auth config API
  static Future<Map<String, dynamic>> getAuthConfig() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/config'),
        headers: HttpClientService.getHeaders(authToken: token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Failed to get auth config');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Sync device token with server (used by GlobalConfig)
  static Future<Map<String, dynamic>> syncDeviceTokenWithServer({
    required String localDeviceToken,
    required String platform,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      print('[AuthService] Syncing device token with server...');
      print('[AuthService] Local device token: ${localDeviceToken.substring(0, 20)}...');

      // Build URL with query parameters for device token sync
      final uri = Uri.parse('$_baseUrl/config').replace(queryParameters: {
        'device_token': localDeviceToken,
        'platform': platform,
      });

      final response = await _httpClient.get(
        uri,
        headers: HttpClientService.getHeaders(authToken: token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('[AuthService] Device token sync response: ${responseData['token_sync_status']}');
        return responseData;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Failed to sync device token');
      }
    } catch (e) {
      print('[AuthService] Error syncing device token: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Device token sync failed: ${e.toString()}');
    }
  }

  // Register device token with server
  static Future<bool> registerDeviceToken({
    required String deviceToken,
    String platform = 'ios',
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final response = await _httpClient.post(
        Uri.parse('https://nachna.com/api/notifications/register-token'),
        headers: HttpClientService.getHeaders(authToken: token),
        body: jsonEncode({
          'device_token': deviceToken,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200) {
        print('[AuthService] Device token registered successfully');
        return true;
      } else {
        final error = jsonDecode(response.body);
        print('[AuthService] Failed to register device token: ${error['detail']}');
        return false;
      }
    } catch (e) {
      print('[AuthService] Error registering device token: $e');
      return false;
    }
  }

  // Update user profile
  static Future<User> updateProfile({
    String? name,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      if (gender != null) body['gender'] = gender;

      final response = await _httpClient.put(
        Uri.parse('$_baseUrl/profile'),
        headers: HttpClientService.getHeaders(authToken: token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final user = User.fromJson(jsonDecode(response.body));
        await _saveUser(user);
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Profile update failed');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }



  // Upload profile picture
  static Future<String> uploadProfilePicture(File imageFile) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/profile-picture'),
      );

      // Add headers with gzip support
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept-Encoding': 'gzip, deflate',
      });
      
      // Determine content type based on file extension
      String contentType = 'image/jpeg';
      final extension = imageFile.path.toLowerCase().split('.').last;
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'gif') {
        contentType = 'image/gif';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(contentType),
      ));

      print('📤 Uploading image: ${imageFile.path}');
      print('📤 Content type: $contentType');
      print('📤 File size: ${await imageFile.length()} bytes');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final imageUrl = responseData['image_url'];
        
        // Update stored user data with new profile picture
        final currentUser = await getStoredUser();
        if (currentUser != null) {
          final updatedUser = User(
            userId: currentUser.userId,
            mobileNumber: currentUser.mobileNumber,
            name: currentUser.name,
            dateOfBirth: currentUser.dateOfBirth,
            gender: currentUser.gender,
            profilePictureUrl: imageUrl,
            profileComplete: currentUser.profileComplete,
            isAdmin: currentUser.isAdmin,
            createdAt: currentUser.createdAt,
            updatedAt: DateTime.now(),
          );
          await _saveUser(updatedUser);
        }
        
        return imageUrl;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Profile picture upload failed');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Remove profile picture
  static Future<void> removeProfilePicture() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final response = await _httpClient.delete(
        Uri.parse('$_baseUrl/profile-picture'),
        headers: HttpClientService.getHeaders(authToken: token),
      );

      if (response.statusCode == 200) {
        // Update stored user data to remove profile picture
        final currentUser = await getStoredUser();
        if (currentUser != null) {
          final updatedUser = User(
            userId: currentUser.userId,
            mobileNumber: currentUser.mobileNumber,
            name: currentUser.name,
            dateOfBirth: currentUser.dateOfBirth,
            gender: currentUser.gender,
            profilePictureUrl: null,
            profileComplete: currentUser.profileComplete,
            isAdmin: currentUser.isAdmin,
            createdAt: currentUser.createdAt,
            updatedAt: DateTime.now(),
          );
          await _saveUser(updatedUser);
        }
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Profile picture removal failed');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      // Check if token is expired
      if (JwtDecoder.isExpired(token)) {
        await logout();
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get stored token
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      return null;
    }
  }

  // Get stored user
  static Future<User?> getStoredUser() async {
    try {
      final userJson = await _storage.read(key: _userKey);
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Logout user
  static Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (e) {
      // Silent fail for logout
    }
  }

  // Save authentication data
  static Future<void> _saveAuthData(AuthResponse authResponse) async {
    try {
      await _storage.write(key: _tokenKey, value: authResponse.accessToken);
      await _storage.write(key: _userKey, value: jsonEncode(authResponse.user.toJson()));
    } catch (e) {
      throw AuthException('Failed to save authentication data');
    }
  }

  // Save user data
  static Future<void> _saveUser(User user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (e) {
      throw AuthException('Failed to save user data');
    }
  }

  // Validate mobile number format
  static bool isValidMobileNumber(String mobileNumber) {
    // Remove any spaces, dashes, or other formatting
    String cleaned = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check for Indian mobile number format (10 digits starting with 6-9)
    final regex = RegExp(r'^[6-9]\d{9}$');
    return regex.hasMatch(cleaned);
  }

  // Validate password strength
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Format mobile number for display and API calls
  static String formatMobileNumber(String mobileNumber) {
    // Remove any non-digit characters
    String cleaned = mobileNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it's already 10 digits and starts with 6-9, return as is
    if (cleaned.length == 10 && RegExp(r'^[6-9]').hasMatch(cleaned)) {
      return cleaned;
    }
    
    // If it has country code +91, remove it
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    }
    
    return cleaned;
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('No authentication token found');
      }

      final response = await _httpClient.delete(
        Uri.parse('$_baseUrl/account'),
        headers: HttpClientService.getHeaders(authToken: token),
      );

      if (response.statusCode == 200) {
        // Account deleted successfully on the server
        await _clearAuthData(); // Clear local token and user data
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Account deletion failed');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error during account deletion: $e');
    }
  }

  // Clear all stored authentication data
  static Future<void> _clearAuthData() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    // Also ensure the HttpClientService clears its cached token if any
    HttpClientService.instance.clearToken();
  }
}

// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;
  
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
} 