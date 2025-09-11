import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import './auth_service.dart';
import './http_client_service.dart';

class BundleService {
  // Set the base URL for the API - using production server
  final String baseUrl = 'https://nachna.com';

  // Add timeout duration for network requests
  static const Duration requestTimeout = const Duration(seconds: 15);

  // Get the HTTP client instance
  http.Client get _httpClient => HttpClientService.instance.client;

  /// Get available bundle templates
  Future<List<Map<String, dynamic>>> getBundleTemplates() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/orders/bundles/templates'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bundles = responseData['bundles'] as List<dynamic>? ?? [];
        return bundles.map((bundle) => bundle as Map<String, dynamic>).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Failed to fetch bundle templates');
      }
    } catch (e) {
      print('[BundleService] Error fetching bundle templates: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('timeout')) {
        throw Exception('Request timed out. Please check your internet connection and try again.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Purchase a bundle
  Future<BundlePurchaseResponse> purchaseBundle(String templateId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final request = BundlePurchaseRequest(templateId: templateId);

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/orders/bundles/purchase'),
            headers: {
              ...HttpClientService.getHeaders(authToken: token),
              'Content-Type': 'application/json',
            },
            body: json.encode(request.toJson()),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return BundlePurchaseResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Invalid bundle template');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Bundle template not found');
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Failed to purchase bundle');
      }
    } catch (e) {
      print('[BundleService] Error purchasing bundle: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('timeout')) {
        throw Exception('Request timed out. Please check your internet connection and try again.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Get user's bundle orders
  Future<List<Map<String, dynamic>>> getUserBundles() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/orders/user?type=bundle'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final orders = responseData['orders'] as List<dynamic>? ?? [];
        return orders.map((order) => order as Map<String, dynamic>).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Failed to fetch bundle orders');
      }
    } catch (e) {
      print('[BundleService] Error fetching user bundles: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('timeout')) {
        throw Exception('Request timed out. Please check your internet connection and try again.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }
}
