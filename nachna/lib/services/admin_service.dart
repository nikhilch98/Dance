import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

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
} 