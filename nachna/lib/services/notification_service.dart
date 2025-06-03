import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String baseUrl = 'https://nachna.com/api';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  String? _deviceToken;
  static const MethodChannel _channel = MethodChannel('nachna/notifications');

  /// Initialize notification service and get device token
  Future<String?> initialize() async {
    try {
      if (Platform.isIOS) {
        // Request permissions and get device token via method channel
        final result = await _channel.invokeMethod('requestPermissionsAndGetToken');
        
        if (result != null && result is Map) {
          final success = result['success'] as bool;
          if (success) {
            _deviceToken = result['token'] as String?;
            
            if (_deviceToken != null) {
              print('📱 Device Token: $_deviceToken');
              
              // Register token with server
              await _registerTokenWithServer(_deviceToken!);
              
              // Setup listeners for token refresh and notifications
              _setupChannelListeners();
            }
            
            return _deviceToken;
          } else {
            final error = result['error'] as String?;
            print('❌ Failed to get device token: $error');
            return null;
          }
        }
      } else {
        print('❌ APNs only available on iOS');
        return null;
      }
    } catch (e) {
      print('❌ Error initializing notifications: $e');
      return null;
    }
    
    return null;
  }

  /// Setup method channel listeners
  void _setupChannelListeners() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTokenRefresh':
          final newToken = call.arguments as String;
          print('📱 Token refreshed: $newToken');
          _deviceToken = newToken;
          await _registerTokenWithServer(newToken);
          break;
          
        case 'onNotificationReceived':
          final data = Map<String, dynamic>.from(call.arguments);
          print('📨 Notification received: $data');
          _handleNotificationReceived(data);
          break;
          
        case 'onNotificationTapped':
          final data = Map<String, dynamic>.from(call.arguments);
          print('📨 Notification tapped: $data');
          _handleNotificationTap(data);
          break;
      }
    });
  }

  /// Get current device token
  String? get deviceToken => _deviceToken;

  /// Copy device token to clipboard for testing
  Future<void> copyTokenToClipboard() async {
    if (_deviceToken != null) {
      await Clipboard.setData(ClipboardData(text: _deviceToken!));
      print('✅ Device token copied to clipboard');
    }
  }

  /// Register device token with server
  Future<bool> _registerTokenWithServer(String token) async {
    try {
      final authToken = await _storage.read(key: 'access_token');
      if (authToken == null) {
        print('❌ No auth token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/notifications/register-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'device_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Device token registered with server');
        return true;
      } else {
        print('❌ Failed to register token: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error registering token: $e');
      return false;
    }
  }

  /// Handle notification received (foreground)
  void _handleNotificationReceived(Map<String, dynamic> data) {
    // You can implement in-app notification display here
    print('🔔 Show notification: ${data['title']}');
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle different notification types
    switch (data['type']) {
      case 'new_workshop':
        // Navigate to workshop details
        print('Navigate to workshop: ${data['workshop_id']}');
        break;
      case 'artist_update':
        // Navigate to artist profile
        print('Navigate to artist: ${data['artist_id']}');
        break;
      default:
        print('Unknown notification type: ${data['type']}');
    }
  }

  /// Send test notification (admin only)
  Future<bool> sendTestNotification({
    required String title,
    required String body,
    String? targetDeviceToken,
  }) async {
    try {
      final authToken = await _storage.read(key: 'access_token');
      if (authToken == null) {
        print('❌ No auth token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/api/test-apns'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'device_token': targetDeviceToken ?? _deviceToken,
          'title': title,
          'body': body,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Test notification sent successfully');
        return true;
      } else {
        print('❌ Failed to send test notification: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending test notification: $e');
      return false;
    }
  }
} 