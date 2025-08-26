import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import './auth_service.dart';
import './http_client_service.dart';

class OrderService {
  // Set the base URL for the API - using production server
  final String baseUrl = 'https://nachna.com';
  
  // Add timeout duration for network requests
  static const Duration requestTimeout = Duration(seconds: 15);
  
  // Get the HTTP client instance
  http.Client get _httpClient => HttpClientService.instance.client;

  /// Creates a payment link for a workshop
  /// Returns PaymentLinkResult which handles success/existing/error cases
  /// [pointsRedeemed] - Optional reward points to redeem for discount
  /// [discountAmount] - Optional discount amount from redeemed points
  Future<PaymentLinkResult> createPaymentLink(
    String workshopUuid, {
    double? pointsRedeemed,
    double? discountAmount,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PaymentLinkResult.error('Authentication token not found. Please login again.');
      }

      final request = CreatePaymentLinkRequest(
        workshopUuid: workshopUuid,
        pointsRedeemed: pointsRedeemed ?? 0.0,
        discountAmount: discountAmount ?? 0.0,
      );
      
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/orders/create-payment-link'),
            headers: {
              ...HttpClientService.getHeaders(authToken: token),
              'Content-Type': 'application/json',
            },
            body: json.encode(request.toJson()),
          )
          .timeout(requestTimeout);

      print('[OrderService] Create payment link response: ${response.statusCode}');
      print('[OrderService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Success - payment link created or existing found
        final responseData = json.decode(response.body);
        print('[OrderService] Parsed response data: $responseData');
        
        PaymentLinkResponse paymentResponse;
        try {
          paymentResponse = PaymentLinkResponse.fromJson(responseData);
          print('[OrderService] PaymentLinkResponse created successfully');
        } catch (e) {
          print('[OrderService] Error creating PaymentLinkResponse: $e');
          return PaymentLinkResult.error('Failed to parse payment response: $e');
        }
        
        if (paymentResponse.isExisting) {
          print('[OrderService] Using existing payment link: ${paymentResponse.paymentLinkUrl}');
        } else {
          print('[OrderService] Created new payment link: ${paymentResponse.paymentLinkUrl}');
        }
        
        return PaymentLinkResult.success(paymentResponse);
        
      } else if (response.statusCode == 400) {
        // Bad request - workshop not found or pricing issue
        final responseData = json.decode(response.body);
        return PaymentLinkResult.error(responseData['detail'] ?? 'Invalid workshop or pricing information');
        
      } else if (response.statusCode == 404) {
        // Workshop not found
        return PaymentLinkResult.error('Workshop not found. Please try again.');
        
      } else if (response.statusCode == 401) {
        // Unauthorized
        return PaymentLinkResult.error('Session expired. Please login again.');
        
      } else {
        // Other error
        final responseData = json.decode(response.body);
        return PaymentLinkResult.error(responseData['detail'] ?? 'Failed to create payment link');
      }
      
    } catch (e) {
      print('[OrderService] Error creating payment link: $e');
      
      // Provide user-friendly error messages
      if (e.toString().contains('timeout')) {
        return PaymentLinkResult.error('Request timed out. Please check your internet connection and try again.');
      } else if (e.toString().contains('network')) {
        return PaymentLinkResult.error('Network error. Please check your internet connection.');
      } else {
        return PaymentLinkResult.error('Failed to create payment link. Please try again.');
      }
    }
  }

  /// Fetches orders for the authenticated user
  /// [status] - Optional comma-separated list of statuses to filter by
  /// [limit] - Number of orders to fetch (default 20)
  /// [offset] - Number of orders to skip for pagination (default 0)
  Future<UserOrdersResponse> getUserOrders({
    List<OrderStatus>? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      // Add status filter if provided
      if (status != null && status.isNotEmpty) {
        final statusStrings = status.map((s) {
          switch (s) {
            case OrderStatus.created:
              return 'created';
            case OrderStatus.paid:
              return 'paid';
            case OrderStatus.failed:
              return 'failed';
            case OrderStatus.expired:
              return 'expired';
            case OrderStatus.cancelled:
              return 'cancelled';
          }
        }).toList();
        queryParams['status'] = statusStrings.join(',');
      }

      final uri = Uri.parse('$baseUrl/api/orders/user').replace(queryParameters: queryParams);
      
      final response = await _httpClient
          .get(
            uri,
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      print('[OrderService] Get user orders response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return UserOrdersResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Failed to fetch orders');
      }
      
    } catch (e) {
      print('[OrderService] Error fetching user orders: $e');
      
      // Re-throw with user-friendly message
      if (e.toString().contains('timeout')) {
        throw Exception('Request timed out. Please check your internet connection.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  /// Fetches only completed orders for the user
  Future<UserOrdersResponse> getCompletedOrders({int limit = 20, int offset = 0}) async {
    return getUserOrders(
      status: [OrderStatus.paid],
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches only pending orders for the user
  Future<UserOrdersResponse> getPendingOrders({int limit = 20, int offset = 0}) async {
    return getUserOrders(
      status: [OrderStatus.created],
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches all active orders (created + paid) for the user
  Future<UserOrdersResponse> getActiveOrders({int limit = 20, int offset = 0}) async {
    return getUserOrders(
      status: [OrderStatus.created, OrderStatus.paid],
      limit: limit,
      offset: offset,
    );
  }

  /// Fetches the status of a specific order
  /// This is optimized for order status polling
  Future<Order> getOrderStatus(String orderId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/orders/$orderId/status'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      print('[OrderService] Get order status response: ${response.statusCode}');
      print('[OrderService] Order ID: $orderId');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['order'] != null) {
          return Order.fromJson(responseData['order']);
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Order not found');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['detail'] ?? 'Failed to fetch order status');
      }
      
    } catch (e) {
      print('[OrderService] Error fetching order status: $e');
      
      // Re-throw with user-friendly message
      if (e.toString().contains('timeout')) {
        throw Exception('Request timed out. Please check your internet connection.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }
}
