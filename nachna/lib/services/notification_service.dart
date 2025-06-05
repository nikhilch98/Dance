import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reaction.dart';
import './reaction_service.dart';
import './auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Method channel for native iOS/Android communication
  static const MethodChannel _channel = MethodChannel('nachna/notifications');
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _deviceToken;
  bool _isInitialized = false;
  bool _permissionsGranted = false;
  String? _lastRegisteredToken;
  
  // Navigation callback for deep linking
  Function(String)? _onNotificationTap;
  
  // Stream controllers for handling notification events
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();
  
  // Getters
  String? get deviceToken => _deviceToken;
  bool get isInitialized => _isInitialized;
  bool get permissionsGranted => _permissionsGranted;
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  Stream<String> get tokenStream => _tokenStreamController.stream;

  /// Initialize the notification service
  Future<String?> initialize({
    Function(String)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    
    try {
      // Initialize native notification service
      
      // Set up method call handler for notifications from native side
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Request permission and get device token
      final result = await _channel.invokeMethod('initialize');
      
      if (result != null && result is Map) {
        _deviceToken = result['deviceToken'];
        _isInitialized = true;
        // Native notification service initialized successfully
        return _deviceToken;
      }
      
      return null;
    } catch (e) {
      // Error initializing notification service
      return null;
    }
  }

  /// Setup method channel handlers for iOS/Android communication
  void _setupMethodChannelHandlers() {
    _channel.setMethodCallHandler((MethodCall call) async {
      // Received method call
      
      switch (call.method) {
        case 'onTokenRefresh':
          await _handleTokenRefresh(call.arguments);
          break;
        case 'onNotificationReceived':
          await _handleNotificationReceived(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onNotificationTapped':
          await _handleNotificationTapped(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onPermissionStatusChanged':
          await _handlePermissionStatusChanged(call.arguments);
          break;
        case 'onRegistrationError':
          _handleRegistrationError(call.arguments);
          break;
        default:
          // Unknown method call
      }
    });
  }

  /// Check current permission status and token
  Future<void> _checkCurrentPermissionStatus() async {
    try {
      final result = await _channel.invokeMethod('checkPermissionStatus');
      if (result != null && result is Map) {
        final status = result['status'] as String?;
        final token = result['token'] as String?;
        final isRegistered = result['isRegistered'] as bool? ?? false;
        
        // Current permission status checked
        
        _permissionsGranted = (status == 'authorized' || status == 'provisional') && isRegistered;
        
        if (token != null && token.isNotEmpty) {
          await _handleTokenReceived(token);
        }
      }
    } catch (e) {
      // Error checking permission status
    }
  }

  /// Request permissions and get device token
  Future<Map<String, dynamic>> requestPermissionsAndGetToken() async {
    try {
      // Requesting permissions and device token
      
      final result = await _channel.invokeMethod('requestPermissionsAndGetToken');
      
      if (result != null && result is Map) {
        final success = result['success'] as bool? ?? false;
        final token = result['token'] as String?;
        final shouldOpenSettings = result['shouldOpenSettings'] as bool? ?? false;
        final error = result['error'] as String?;
        
        if (success && token != null) {
          await _handleTokenReceived(token);
          _permissionsGranted = true;
          
          return {
            'success': true,
            'token': token,
            'shouldOpenSettings': false,
          };
        } else {
          // Permission request failed
          return {
            'success': false,
            'error': error ?? 'Permission request failed',
            'shouldOpenSettings': shouldOpenSettings,
          };
        }
      }
      
      return {
        'success': false,
        'error': 'Invalid response from native platform',
        'shouldOpenSettings': false,
      };
      
    } catch (e) {
      // Error requesting permissions
      return {
        'success': false,
        'error': 'Failed to request permissions: $e',
        'shouldOpenSettings': false,
      };
    }
  }

  /// Open device notification settings
  Future<bool> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retry token registration (useful for troubleshooting)
  Future<Map<String, dynamic>> retryTokenRegistration() async {
    try {
      final result = await _channel.invokeMethod('retryTokenRegistration');
      if (result != null && result is Map) {
        final success = result['success'] as bool? ?? false;
        final token = result['token'] as String?;
        
        if (success && token != null) {
          await _handleTokenReceived(token);
        }
        
        return {
          'success': success,
          'token': token,
        };
      }
      return {'success': false};
    } catch (e) {
      // Error retrying token registration
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle token refresh from native platform
  Future<void> _handleTokenRefresh(dynamic arguments) async {
    if (arguments is Map) {
      final token = arguments['token'] as String?;
      final isNewToken = arguments['isNewToken'] as bool? ?? true;
      
      if (token != null) {
        // Token received/refreshed
        await _handleTokenReceived(token);
      }
    }
  }

  /// Handle token received and register with server
  Future<void> _handleTokenReceived(String token) async {
    final previousToken = _deviceToken;
    _deviceToken = token;
    
    // Store token locally
    await _storeTokenLocally(token);
    
    // Register with server if token changed
    if (previousToken != token) {
      await _registerTokenWithServer(token);
    }
    
    // Notify listeners
    _tokenStreamController.add(token);
  }

  /// Handle notification received
  Future<void> _handleNotificationReceived(Map<String, dynamic> arguments) async {
    // Notification received
    _messageStreamController.add(arguments);
    // Show local notification if app is in foreground
    await _showLocalNotification(arguments);
  }

  /// Handle notification tapped
  Future<void> _handleNotificationTapped(Map<String, dynamic> arguments) async {
    // Notification tapped
    // Extract artist_id for deep linking
    final artistId = _extractArtistIdFromPayload(arguments);
    if (artistId != null && _onNotificationTap != null) {
      _onNotificationTap!(artistId);
    }
  }

  /// Handle permission status changed
  Future<void> _handlePermissionStatusChanged(dynamic arguments) async {
    if (arguments is Map) {
      final granted = arguments['granted'] as bool? ?? false;
      final token = arguments['token'] as String?;
      
      // Permission status changed
      _permissionsGranted = granted;
      
      if (granted && token != null) {
        await _handleTokenReceived(token);
      }
    }
  }

  /// Handle registration error
  void _handleRegistrationError(dynamic arguments) {
    if (arguments is Map) {
      final error = arguments['error'] as String?;
      // Registration error occurred
    }
  }

  /// Extract artist ID from notification payload for deep linking
  String? _extractArtistIdFromPayload(Map<String, dynamic> payload) {
    // Check for artist_id in various possible locations
    String? artistId = payload['artist_id'] as String?;
    
    if (artistId == null) {
      // Check in nested data
      final data = payload['data'] as Map?;
      if (data != null) {
        artistId = data['artist_id'] as String?;
      }
    }
    
    if (artistId == null) {
      // Check for custom payload format: "artist|{artist_id}"
      final customPayload = payload['custom'] as String?;
      if (customPayload != null && customPayload.startsWith('artist|')) {
        artistId = customPayload.substring(7); // Remove "artist|" prefix
      }
    }
    
    return artistId;
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We handle permissions through native code
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Show local notification when app is in foreground
  Future<void> _showLocalNotification(Map<String, dynamic> payload) async {
    try {
      // Extract title and body from payload
      String title = 'New Notification';
      String body = 'You have a new notification';
      
      // Check for aps structure (iOS format)
      final aps = payload['aps'] as Map?;
      if (aps != null) {
        final alert = aps['alert'] as Map?;
        if (alert != null) {
          title = alert['title'] as String? ?? title;
          body = alert['body'] as String? ?? body;
        }
      } else {
        // Check for direct title/body
        title = payload['title'] as String? ?? title;
        body = payload['body'] as String? ?? body;
      }

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(payload),
      );
    } catch (e) {
      // Error showing local notification
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final payload = jsonDecode(response.payload!);
        if (payload is Map<String, dynamic>) {
          final artistId = _extractArtistIdFromPayload(payload);
          if (artistId != null && _onNotificationTap != null) {
            _onNotificationTap!(artistId);
          }
        }
      }
    } catch (e) {
      // Error handling local notification tap
    }
  }

  /// Store token locally to detect changes
  Future<void> _storeTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousToken = prefs.getString('device_token');
      
      if (previousToken != token) {
        await prefs.setString('device_token', token);
        // Device token updated locally
      }
    } catch (e) {
      // Error storing token locally
    }
  }

  /// Register device token with server
  Future<void> _registerTokenWithServer(String token) async {
    try {
      // Skip if we've already registered this exact token
      if (_lastRegisteredToken == token) {
        // Device token already registered, skipping duplicate registration
        return;
      }
      
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        // No auth token available, skipping device token registration
        return;
      }
      
      final reactionService = ReactionService();
      reactionService.setAuthToken(authToken);
      
      final platform = Platform.isIOS ? 'ios' : 'android';
      await reactionService.registerDeviceToken(
        DeviceTokenRequest(
          deviceToken: token,
          platform: platform,
        ),
      );
      
      // Mark this token as successfully registered
      _lastRegisteredToken = token;
      // Device token registered with server successfully
    } catch (e) {
      // Error registering token with server
    }
  }

  /// Manually register current device token with server (useful after authentication)
  Future<bool> registerCurrentDeviceToken() async {
    if (_deviceToken == null) {
      // No device token available to register
      return false;
    }
    
    try {
      await _registerTokenWithServer(_deviceToken!);
      return true;
    } catch (e) {
      // Error in registerCurrentDeviceToken
      return false;
    }
  }

  /// Unregister device token from server (call on logout/account deletion)
  Future<bool> unregisterDeviceToken() async {
    if (_deviceToken == null) {
      print('[NotificationService] No device token to unregister');
      return true; // Consider it successful if no token exists
    }
    
    try {
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        print('[NotificationService] No auth token available for device token unregistration');
        return false;
      }
      
      final reactionService = ReactionService();
      reactionService.setAuthToken(authToken);
      
      await reactionService.unregisterDeviceToken(_deviceToken!);
      
      // Clear the last registered token since it's now unregistered
      _lastRegisteredToken = null;
      print('[NotificationService] Device token unregistered successfully');
      return true;
    } catch (e) {
      print('[NotificationService] Error unregistering device token: $e');
      return false;
    }
  }

  /// Synchronize device token with server via config API during app startup
  Future<bool> syncDeviceTokenViaConfig() async {
    print('[NotificationService] ===== STARTING DEVICE TOKEN SYNC VIA CONFIG =====');
    print('[NotificationService] Local device token available: ${_deviceToken != null}');
    
    if (_deviceToken == null) {
      print('[NotificationService] No local device token to sync - waiting for device token...');
      return false;
    }
    
    try {
      // Get platform
      final platform = Platform.isIOS ? 'ios' : 'android';
      print('[NotificationService] Platform: $platform');
      print('[NotificationService] Local device token: ${_deviceToken?.substring(0, 20)}...');
      
      // Call config API with device token
      final configResponse = await AuthService.getConfigWithDeviceToken(
        deviceToken: _deviceToken!,
        platform: platform,
      );
      
      print('[NotificationService] Config API response: $configResponse');
      
      // Check if the response indicates the token was updated
      final isAdmin = configResponse['is_admin'] ?? false;
      final serverDeviceToken = configResponse['current_device_token'];
      final tokenUpdated = configResponse['device_token_updated'] ?? false;
      
      print('[NotificationService] Server device token: ${serverDeviceToken?.substring(0, 20) ?? 'null'}...');
      print('[NotificationService] Token updated: $tokenUpdated');
      
      if (tokenUpdated) {
        print('[NotificationService] ✅ Device token synchronized via config API');
        _lastRegisteredToken = _deviceToken;
        return true;
      } else if (serverDeviceToken == _deviceToken) {
        print('[NotificationService] ✅ Device tokens already match, no sync needed');
        _lastRegisteredToken = _deviceToken;
        return true;
      } else {
        print('[NotificationService] ⚠️ Config API did not update token, falling back to direct registration');
        return await _fallbackDeviceTokenSync();
      }
      
    } catch (e) {
      print('[NotificationService] ❌ Error syncing device token via config: $e');
      print('[NotificationService] Falling back to direct device token sync...');
      return await _fallbackDeviceTokenSync();
    }
  }

  /// Fallback device token sync using direct registration API
  Future<bool> _fallbackDeviceTokenSync() async {
    try {
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        print('[NotificationService] No auth token available for fallback sync');
        return false;
      }
      
      final reactionService = ReactionService();
      reactionService.setAuthToken(authToken);
      
      // Register the current device token directly
      final platform = Platform.isIOS ? 'ios' : 'android';
      print('[NotificationService] Fallback: Registering device token for platform: $platform');
      
      await reactionService.registerDeviceToken(
        DeviceTokenRequest(
          deviceToken: _deviceToken!,
          platform: platform,
        ),
      );
      
      // Mark this token as successfully registered
      _lastRegisteredToken = _deviceToken;
      print('[NotificationService] ✅ Device token synchronized via fallback method');
      return true;
      
    } catch (e) {
      print('[NotificationService] ❌ Error in fallback device token sync: $e');
      return false;
    }
  }

  /// Legacy method - keep for backwards compatibility
  Future<bool> syncDeviceTokenWithServer() async {
    return await syncDeviceTokenViaConfig();
  }

  /// Clear device token state (call on logout to reset registration flags)
  void clearDeviceTokenState() {
    _lastRegisteredToken = null;
    print('[NotificationService] Device token state cleared');
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        // Notification received
        // You can handle the notification here if needed
        break;
        
      case 'onNotificationTapped':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        // Notification tapped
        
        // Extract artist_id from notification data
        final artistId = arguments['artist_id'] as String?;
        if (artistId != null && _onNotificationTap != null) {
          _onNotificationTap!(artistId);
        }
        break;
        
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Notification service method ${call.method} not implemented',
        );
    }
  }

  Future<bool> isRegisteredForNotifications() async {
    try {
      final result = await _channel.invokeMethod('isRegisteredForNotifications');
      // Is registered for notifications
      return result == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _localNotifications.show(
        0,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      // Error showing local notification
    }
  }
} 