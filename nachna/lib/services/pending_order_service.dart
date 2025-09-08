import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../screens/order_status_screen.dart';
import '../main.dart';

class PendingOrderService {
  static final PendingOrderService _instance = PendingOrderService._internal();
  static PendingOrderService get instance => _instance;
  
  PendingOrderService._internal();
  
  bool _hasCheckedPendingOrders = false;
  bool _isCheckingPendingOrders = false;
  
  /// Check for pending orders and navigate to order status screen if found
  /// This should be called when user returns to the app after authentication
  Future<void> checkAndNavigateToPendingOrder() async {
    // Prevent multiple simultaneous checks
    if (_isCheckingPendingOrders || _hasCheckedPendingOrders) {
      return;
    }
    
    _isCheckingPendingOrders = true;
    
    try {
      print('[PendingOrderService] Checking for pending orders...');
      
      final orderService = OrderService();
      final pendingOrdersResponse = await orderService.getPendingOrders(limit: 1);
      
      if (pendingOrdersResponse.orders.isNotEmpty) {
        final mostRecentPendingOrder = pendingOrdersResponse.orders.first;
        print('[PendingOrderService] Found pending order: ${mostRecentPendingOrder.orderId}');
        
        // Check if the order was created recently (within last 30 minutes)
        final orderAge = DateTime.now().difference(mostRecentPendingOrder.createdAt);
        if (orderAge.inMinutes <= 30) {
          print('[PendingOrderService] Recent pending order found, navigating to order status');
          await _navigateToOrderStatus(mostRecentPendingOrder.orderId);
        } else {
          print('[PendingOrderService] Pending order is too old (${orderAge.inMinutes} minutes), not auto-navigating');
        }
      } else {
        print('[PendingOrderService] No pending orders found');
      }
      
      _hasCheckedPendingOrders = true;
      
    } catch (e) {
      print('[PendingOrderService] Error checking pending orders: $e');
      // Don't mark as checked if there was an error, so we can retry
    } finally {
      _isCheckingPendingOrders = false;
    }
  }
  
  /// Navigate to order status screen for a specific order ID
  Future<void> _navigateToOrderStatus(String orderId) async {
    final navigator = MyApp.navigatorKey.currentState;
    if (navigator == null) {
      print('[PendingOrderService] Navigator not available, cannot navigate to order status');
      return;
    }
    
    try {
      // Small delay to ensure home screen is fully loaded
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('[PendingOrderService] Navigating to order status for order: $orderId');
      
      navigator.push(
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(orderId: orderId),
        ),
      );
      
      print('[PendingOrderService] Successfully navigated to order status screen');
    } catch (e) {
      print('[PendingOrderService] Error navigating to order status: $e');
    }
  }
  
  /// Reset the check flag (useful for testing or when user logs out)
  void resetCheckFlag() {
    _hasCheckedPendingOrders = false;
    _isCheckingPendingOrders = false;
    print('[PendingOrderService] Check flag reset');
  }
  
  /// Force check for pending orders (bypasses the already-checked flag)
  Future<void> forceCheckPendingOrders() async {
    _hasCheckedPendingOrders = false;
    await checkAndNavigateToPendingOrder();
  }
  
  /// Check if there are any pending orders without navigation
  Future<Order?> getMostRecentPendingOrder() async {
    try {
      final orderService = OrderService();
      final pendingOrdersResponse = await orderService.getPendingOrders(limit: 1);
      
      if (pendingOrdersResponse.orders.isNotEmpty) {
        return pendingOrdersResponse.orders.first;
      }
      
      return null;
    } catch (e) {
      print('[PendingOrderService] Error getting pending orders: $e');
      return null;
    }
  }
}
