import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/qr_verification.dart';

class AdminService {
  static const String baseUrl = 'https://nachna.com/admin/api';

  /// Get application insights and statistics
  static Future<Map<String, dynamic>?> getAppInsights() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/app-insights'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception('API returned success: false');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to get app insights (Error ${response.statusCode})');
      }
    } catch (e) {
      print('[AdminService] Error getting app insights: $e');
      rethrow;
    }
  }

  /// Send test APNs notification
  static Future<bool> sendTestNotification({
    required String deviceToken,
    required String title,
    required String body,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/test-apns'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'device_token': deviceToken,
          'title': title,
          'body': body,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[AdminService] Error sending test notification: $e');
      return false;
    }
  }

  /// Send test artist notification
  static Future<bool> sendTestArtistNotification(String artistId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/send-test-notification'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'artist_id': artistId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[AdminService] Error sending test artist notification: $e');
      return false;
    }
  }

  /// Get existing choreo links for a specific artist
  static Future<List<Map<String, dynamic>>> getArtistChoreoLinks(String artistId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/artists/$artistId/choreo-links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception('API returned success: false');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to get artist choreo links (Error ${response.statusCode})');
      }
    } catch (e) {
      print('[AdminService] Error getting artist choreo links: $e');
      return [];
    }
  }

  /// Add a new artist (admin only)
  static Future<bool> addArtist({
    required String artistId,
    required String artistName,
    List<String>? artistAliases,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/artist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'artist_id': artistId,
          'artist_name': artistName,
          'artist_aliases': artistAliases ?? [],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> && (data['success'] == true);
      } else if (response.statusCode == 409) {
        // Artist already exists – treat as a handled error for UI messaging
        throw Exception("Artist with this ID already exists");
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required.');
      } else {
        throw Exception('Failed to add artist (Error ${response.statusCode})');
      }
    } catch (e) {
      print('[AdminService] Error adding artist: $e');
      rethrow;
    }
  }

  /// Verify QR code and extract registration data
  static Future<QRVerificationResponse> verifyQRCode(String qrData) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final request = QRVerificationRequest(qrData: qrData);

      final response = await http.post(
        Uri.parse('$baseUrl/verify-qr'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      print('[AdminService] QR verification response: ${response.statusCode}');
      print('[AdminService] QR verification body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return QRVerificationResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required.');
      } else {
        throw Exception('Failed to verify QR code (Error ${response.statusCode})');
      }
    } catch (e) {
      print('[AdminService] Error verifying QR code: $e');
      rethrow;
    }
  }

  /// Mark attendance for a registration
  static Future<Map<String, dynamic>> markAttendance(String orderId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/mark-attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'order_id': orderId,
        }),
      );

      print('[AdminService] Mark attendance response: ${response.statusCode}');
      print('[AdminService] Mark attendance body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          // Show the exact message from the API response
          throw Exception(data['message'] ?? 'Failed to mark attendance');
        }
      } else {
        // For error status codes, try to parse the error message from the response body
        try {
          final data = json.decode(response.body);
          final errorMessage = data['detail'] ?? data['message'] ?? data['error'];
          if (errorMessage != null) {
            throw Exception(errorMessage);
          }
        } catch (parseError) {
          // If we can't parse the response, fall back to generic messages
        }

        // Fallback generic messages for different status codes
        if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please log in again.');
        } else if (response.statusCode == 403) {
          throw Exception('Admin access required or insufficient studio permissions.');
        } else if (response.statusCode == 409) {
          throw Exception('Attendance has already been marked for this registration.');
        } else if (response.statusCode == 404) {
          throw Exception('Order or workshop not found.');
        } else {
          throw Exception('Failed to mark attendance (Error ${response.statusCode})');
        }
      }
    } catch (e) {
      print('[AdminService] Error marking attendance: $e');
      rethrow;
    }
  }
} 