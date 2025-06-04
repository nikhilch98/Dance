import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reaction.dart';
import './reaction_service.dart';
import 'auth_service.dart';

/// Global function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
  print('Background message data: ${message.data}');
  
  // Handle background message processing here if needed
  // This runs when the app is in background or terminated
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _deviceToken;
  bool _isInitialized = false;
  
  // Navigation callback for deep linking
  Function(String)? _onNotificationTap;
  
  // Stream controllers for handling notification events
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();
  
  // Getters
  String? get deviceToken => _deviceToken;
  bool get isInitialized => _isInitialized;
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  Stream<String> get tokenStream => _tokenStreamController.stream;

  /// Initialize the notification service
  Future<String?> initialize({Function(String)? onNotificationTap}) async {
    if (_isInitialized) return _deviceToken;
    
    _onNotificationTap = onNotificationTap;
    
    try {
      print('🚀 Initializing notification service...');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions
      await _requestPermissions();
      
      // Get device token
      await _getDeviceToken();
      
      // Setup message handlers
      _setupMessageHandlers();
      
      // Listen for token refresh
      _setupTokenRefreshListener();
      
      _isInitialized = true;
      print('✅ Notification service initialized successfully');
      return _deviceToken;
      
    } catch (e) {
      print('❌ Error initializing notification service: $e');
      return null;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
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

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request Firebase messaging permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('📋 Firebase permission status: ${settings.authorizationStatus}');

      // Request additional permissions for Android
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        print('📋 Android notification permission: $status');
      }

      // Enable foreground notifications for iOS
      if (Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  /// Get and store device token
  Future<void> _getDeviceToken() async {
    try {
      // Get token for this app installation
      _deviceToken = await _firebaseMessaging.getToken();
      
      if (_deviceToken != null) {
        print('📱 Device token received: ${_deviceToken!.substring(0, 20)}...');
        
        // Store token locally
        await _storeTokenLocally(_deviceToken!);
        
        // Register token with server
        await _registerTokenWithServer(_deviceToken!);
        
        // Notify listeners
        _tokenStreamController.add(_deviceToken!);
      } else {
        print('❌ Failed to get device token');
      }
    } catch (e) {
      print('❌ Error getting device token: $e');
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
      final reactionService = ReactionService();
      
      final platform = Platform.isIOS ? 'ios' : 'android';
      final request = DeviceTokenRequest(
        deviceToken: token,
        platform: platform,
      );
      
      await reactionService.registerDeviceToken(request);
      print('🌐 Device token registered with server');
      
    } catch (e) {
      print('❌ Error registering token with server: $e');
      // Don't throw error here as this shouldn't prevent app functionality
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message taps (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
    
    // Handle message tap when app is launched from terminated state
    _handleAppLaunchFromNotification();
  }

  /// Setup token refresh listener
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('🔄 Token refreshed: ${newToken.substring(0, 20)}...');
      _deviceToken = newToken;
      
      // Store new token locally
      await _storeTokenLocally(newToken);
      
      // Register new token with server
      await _registerTokenWithServer(newToken);
      
      // Notify listeners
      _tokenStreamController.add(newToken);
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Foreground message received: ${message.notification?.title}');
    print('Foreground message data: ${message.data}');
    
    // Show local notification for foreground messages
    await _showLocalNotification(message);
    
    // Notify listeners
    _messageStreamController.add(message);
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    print('👆 Background message tapped: ${message.data}');
    _processDeepLink(message.data);
  }

  /// Handle app launch from notification (when app was terminated)
  Future<void> _handleAppLaunchFromNotification() async {
    try {
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App launched from notification: ${initialMessage.data}');
        // Delay processing to ensure app is fully initialized
        Future.delayed(const Duration(seconds: 1), () {
          _processDeepLink(initialMessage.data);
        });
      }
    } catch (e) {
      print('❌ Error handling app launch from notification: $e');
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    print('👆 Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        // Parse payload as deep link data
        final parts = response.payload!.split('|');
        if (parts.length >= 2) {
          final type = parts[0];
          final artistId = parts[1];
          if (type == 'artist' && _onNotificationTap != null) {
            _onNotificationTap!(artistId);
          }
        }
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create payload for deep linking
      String? payload;
      if (message.data.containsKey('artist_id')) {
        payload = 'artist|${message.data['artist_id']}';
      }

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Nachna',
        message.notification?.body ?? 'New notification',
        details,
        payload: payload,
      );
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  /// Process deep link data
  void _processDeepLink(Map<String, dynamic> data) {
    try {
      print('🔗 Processing deep link: $data');
      
      if (data.containsKey('artist_id') && _onNotificationTap != null) {
        final artistId = data['artist_id'];
        print('🎭 Navigating to artist: $artistId');
        _onNotificationTap!(artistId);
      }
    } catch (e) {
      print('❌ Error processing deep link: $e');
    }
  }

  /// Manually register device token (useful when auth state changes)
  Future<bool> registerDeviceToken() async {
    if (_deviceToken == null) {
      await _getDeviceToken();
    }
    
    if (_deviceToken != null) {
      await _registerTokenWithServer(_deviceToken!);
      return true;
    }
    
    return false;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('❌ Error checking notification status: $e');
      return false;
    }
  }

  /// Request permissions again (useful when user initially declined)
  Future<bool> requestPermissionsAgain() async {
    try {
      await _requestPermissions();
      
      // Get new token if we didn't have one
      if (_deviceToken == null) {
        await _getDeviceToken();
      }
      
      return await areNotificationsEnabled();
    } catch (e) {
      print('❌ Error requesting permissions again: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }
} 