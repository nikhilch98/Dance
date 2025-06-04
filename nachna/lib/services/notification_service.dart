import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reaction.dart';
import './reaction_service.dart';
import 'auth_service.dart';

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
  Future<String?> initialize({Function(String)? onNotificationTap}) async {
    if (_isInitialized) return _deviceToken;
    
    _onNotificationTap = onNotificationTap;
    
    try {
      print('🚀 Initializing native notification service...');
      
      // Setup method channel handlers
      _setupMethodChannelHandlers();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Check current permission status
      await _checkCurrentPermissionStatus();
      
      _isInitialized = true;
      print('✅ Native notification service initialized successfully');
      return _deviceToken;
      
    } catch (e) {
      print('❌ Error initializing notification service: $e');
      return null;
    }
  }

  /// Setup method channel handlers for iOS/Android communication
  void _setupMethodChannelHandlers() {
    _channel.setMethodCallHandler((MethodCall call) async {
      print('📱 Received method call: ${call.method}');
      
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
          print('⚠️ Unknown method call: ${call.method}');
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
        
        print('📋 Current permission status: $status');
        print('📱 Is registered for notifications: $isRegistered');
        
        _permissionsGranted = (status == 'authorized' || status == 'provisional') && isRegistered;
        
        if (token != null && token.isNotEmpty) {
          await _handleTokenReceived(token);
        }
      }
    } catch (e) {
      print('❌ Error checking permission status: $e');
    }
  }

  /// Request permissions and get device token
  Future<Map<String, dynamic>> requestPermissionsAndGetToken() async {
    try {
      print('📱 Requesting permissions and device token...');
      
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
          print('❌ Permission request failed: $error');
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
      print('❌ Error requesting permissions: $e');
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
      final result = await _channel.invokeMethod('openNotificationSettings');
      return result as bool? ?? false;
    } catch (e) {
      print('❌ Error opening notification settings: $e');
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
      print('❌ Error retrying token registration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle token refresh from native platform
  Future<void> _handleTokenRefresh(dynamic arguments) async {
    if (arguments is Map) {
      final token = arguments['token'] as String?;
      final isNewToken = arguments['isNewToken'] as bool? ?? true;
      
      if (token != null) {
        print('📱 Token ${isNewToken ? 'received' : 'refreshed'}: ${token.substring(0, 20)}...');
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
    print('🔔 Notification received: $arguments');
    _messageStreamController.add(arguments);
    // Show local notification if app is in foreground
    await _showLocalNotification(arguments);
  }

  /// Handle notification tapped
  Future<void> _handleNotificationTapped(Map<String, dynamic> arguments) async {
    print('📱 Notification tapped: $arguments');
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
      
      print('📋 Permission status changed - granted: $granted');
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
      print('❌ Registration error: $error');
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
      print('❌ Error showing local notification: $e');
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
      print('❌ Error handling local notification tap: $e');
    }
  }

  /// Store token locally to detect changes
  Future<void> _storeTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousToken = prefs.getString('device_token');
      
      if (previousToken != token) {
        await prefs.setString('device_token', token);
        print('💾 Device token updated locally');
      }
    } catch (e) {
      print('❌ Error storing token locally: $e');
    }
  }

  /// Register device token with server
  Future<void> _registerTokenWithServer(String token) async {
    try {
      // Skip if we've already registered this exact token
      if (_lastRegisteredToken == token) {
        print('ℹ️ Device token already registered, skipping duplicate registration');
        return;
      }
      
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        print('⚠️ No auth token available, skipping device token registration');
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
      print('✅ Device token registered with server successfully');
    } catch (e) {
      print('❌ Error registering token with server: $e');
    }
  }

  /// Manually register current device token with server (useful after authentication)
  Future<bool> registerCurrentDeviceToken() async {
    if (_deviceToken == null) {
      print('⚠️ No device token available to register');
      return false;
    }
    
    try {
      await _registerTokenWithServer(_deviceToken!);
      return true;
    } catch (e) {
      print('❌ Error in registerCurrentDeviceToken: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }
} 