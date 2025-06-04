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

  // Register new user
  static Future<AuthResponse> register({
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/register'),
        headers: HttpClientService.getHeaders(),
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // Login user
  static Future<AuthResponse> login({
    required String mobileNumber,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/login'),
        headers: HttpClientService.getHeaders(),
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(authResponse);
        return authResponse;
      } else {
        final error = jsonDecode(response.body);
        throw AuthException(error['detail'] ?? 'Login failed');
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

  // Update password
  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    print("🔄 AuthService.updatePassword: Starting password update");
    print("🔗 Base URL: $_baseUrl");
    print("🎯 Endpoint: $_baseUrl/password");
    
    try {
      final token = await getToken();
      print("🎫 Token available: ${token != null}");
      
      if (token == null) {
        print("❌ AuthService.updatePassword: No token found");
        throw AuthException('No authentication token found');
      }

      print("📤 Sending request with current password length: ${currentPassword.length}");
      print("📤 Sending request with new password length: ${newPassword.length}");
      
      final requestBody = jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      
      print("📦 Request body: $requestBody");

      final response = await _httpClient.put(
        Uri.parse('$_baseUrl/password'),
        headers: HttpClientService.getHeaders(authToken: token),
        body: requestBody,
      );

      print("📊 Response status code: ${response.statusCode}");
      print("📄 Response body: ${response.body}");
      print("📋 Response headers: ${response.headers}");

      if (response.statusCode != 200) {
        print("❌ AuthService.updatePassword: HTTP error ${response.statusCode}");
        try {
          final error = jsonDecode(response.body);
          print("❌ Error details: $error");
          throw AuthException(error['detail'] ?? 'Password update failed');
        } catch (e) {
          print("❌ Failed to parse error response: $e");
          throw AuthException('Password update failed with status ${response.statusCode}');
        }
      }
      
      print("✅ AuthService.updatePassword: Password update successful");
    } catch (e) {
      print("❌ AuthService.updatePassword: Exception occurred: $e");
      print("❌ Exception type: ${e.runtimeType}");
      
      if (e is AuthException) {
        print("❌ Re-throwing AuthException: ${e.message}");
        rethrow;
      }
      
      print("❌ Throwing new AuthException for: $e");
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
}

// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;
  
  AuthException(this.message);
  
  @override
  String toString() => 'AuthException: $message';
} 