import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reaction.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import './reaction_service.dart';
import './auth_service.dart';

/// Service for handling push notifications and device token management.
///
/// This singleton service manages:
/// - Native iOS/Android push notification registration
/// - Device token retrieval and server synchronization
/// - Local notification display when app is in foreground
/// - Deep linking from notification taps
///
/// Uses method channels to communicate with native platform code.
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
  bool _isDisposed = false;

  // Navigation callback for deep linking
  Function(String)? _onNotificationTap;

  // Stream controllers for handling notification events - lazily initialized
  StreamController<Map<String, dynamic>>? _messageStreamController;
  StreamController<String>? _tokenStreamController;

  /// Get or create message stream controller (safe for reuse after dispose)
  StreamController<Map<String, dynamic>> get _safeMessageStreamController {
    if (_messageStreamController == null || _messageStreamController!.isClosed) {
      _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _messageStreamController!;
  }

  /// Get or create token stream controller (safe for reuse after dispose)
  StreamController<String> get _safeTokenStreamController {
    if (_tokenStreamController == null || _tokenStreamController!.isClosed) {
      _tokenStreamController = StreamController<String>.broadcast();
    }
    return _tokenStreamController!;
  }

  /// Current device token for push notifications, or null if not available.
  String? get deviceToken => _deviceToken;

  /// Whether the notification service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether notification permissions have been granted.
  bool get permissionsGranted => _permissionsGranted;

  /// Stream of incoming notification messages.
  Stream<Map<String, dynamic>> get messageStream => _safeMessageStreamController.stream;

  /// Stream of device token updates.
  Stream<String> get tokenStream => _safeTokenStreamController.stream;

  /// Initialize the notification service
  Future<String?> initialize({
    Function(String)? onNotificationTap,
  }) async {
    AppLogger.startOperation('Notification service initialization', tag: 'Notifications');
    AppLogger.debug('Platform: ${Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'Other'}', tag: 'Notifications');

    _onNotificationTap = onNotificationTap;

    try {
      AppLogger.debug('Setting up method call handler', tag: 'Notifications');
      // Set up method call handler for notifications from native side
      _channel.setMethodCallHandler(_handleMethodCall);

      AppLogger.debug('Requesting native initialization', tag: 'Notifications');
      // Request permission and get device token
      final result = await _channel.invokeMethod('initialize');

      if (result != null && result is Map) {
        final deviceToken = result['deviceToken'] as String?;
        final isAuthorized = result['isAuthorized'] as bool?;
        final authStatus = result['authorizationStatus'] as String?;

        AppLogger.debug('Authorization status: $authStatus, isAuthorized: $isAuthorized', tag: 'Notifications');

        if (deviceToken != null && deviceToken.isNotEmpty) {
          await _handleTokenReceived(deviceToken);
          _isInitialized = true;
          AppLogger.endOperation('Notification service initialization', tag: 'Notifications', success: true);
          return _deviceToken;
        } else {
          AppLogger.warning('No device token received - may be simulator or permissions not granted', tag: 'Notifications');
          // Try to get more info about the current state
          await _debugCurrentState();
        }
      } else {
        AppLogger.warning('Invalid initialization result', tag: 'Notifications');
      }

      return null;
    } catch (e) {
      AppLogger.error('Error initializing notification service', tag: 'Notifications', error: e);
      return null;
    }
  }

  /// Debug current notification state
  Future<void> _debugCurrentState() async {
    try {
      final result = await _channel.invokeMethod('checkPermissionStatus');

      if (result != null && result is Map) {
        final status = result['status'] as String?;
        final isRegistered = result['isRegistered'] as bool?;

        AppLogger.debug('Permission status: $status, isRegistered: $isRegistered', tag: 'Notifications');

        if (status == 'notDetermined') {
          AppLogger.debug('Permissions not yet requested', tag: 'Notifications');
        } else if (status == 'denied') {
          AppLogger.debug('Permissions denied - user needs to enable in Settings', tag: 'Notifications');
        }
      }
    } catch (e) {
      AppLogger.error('Error debugging notification state', tag: 'Notifications', error: e);
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

  /// Requests notification permissions and retrieves the device token.
  ///
  /// Returns a map containing:
  /// - `success`: Whether permission was granted and token received
  /// - `token`: The device token (if successful)
  /// - `shouldOpenSettings`: Whether user should be directed to settings
  /// - `error`: Error message (if failed)
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

  /// Opens the device's notification settings page.
  ///
  /// Returns `true` if settings were opened successfully.
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
    AppLogger.debug('Handling token received', tag: 'Notifications');

    final previousToken = _deviceToken;
    _deviceToken = token;

    // Store token locally
    await _storeTokenLocally(token);

    // Only register with server if we have auth token and token changed
    if (previousToken != token) {
      AppLogger.debug('Token changed, attempting server registration', tag: 'Notifications');
      await _registerTokenWithServer(token);
    }

    // Notify listeners safely
    if (!_isDisposed && _tokenStreamController != null && !_tokenStreamController!.isClosed) {
      _safeTokenStreamController.add(token);
    }
  }

  /// Handle notification received
  Future<void> _handleNotificationReceived(Map<String, dynamic> arguments) async {
    // Notification received - safely add to stream
    if (!_isDisposed && _messageStreamController != null && !_messageStreamController!.isClosed) {
      _safeMessageStreamController.add(arguments);
    }
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
        AppLogger.debug('Device token already registered, skipping', tag: 'Notifications');
        return;
      }

      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        AppLogger.debug('No auth token available, skipping device token registration', tag: 'Notifications');
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
      AppLogger.info('Device token registered with server', tag: 'Notifications');
    } catch (e) {
      AppLogger.error('Error registering token with server', tag: 'Notifications', error: e);
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

  /// Unregisters device token from server.
  ///
  /// Should be called on logout or account deletion to stop receiving
  /// push notifications. Returns `true` if successful.
  Future<bool> unregisterDeviceToken() async {
    if (_deviceToken == null) {
      AppLogger.debug('No device token to unregister', tag: 'Notifications');
      return true; // Consider it successful if no token exists
    }

    try {
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        AppLogger.debug('No auth token available for device token unregistration', tag: 'Notifications');
        return false;
      }

      final reactionService = ReactionService();
      reactionService.setAuthToken(authToken);

      await reactionService.unregisterDeviceToken(_deviceToken!);

      // Clear the last registered token since it's now unregistered
      _lastRegisteredToken = null;
      AppLogger.info('Device token unregistered successfully', tag: 'Notifications');
      return true;
    } catch (e) {
      AppLogger.error('Error unregistering device token', tag: 'Notifications', error: e);
      return false;
    }
  }

  /// Synchronize device token with server via config API during app startup
  Future<bool> syncDeviceTokenViaConfig() async {
    AppLogger.startOperation('Device token sync via config', tag: 'Notifications');

    if (_deviceToken == null) {
      AppLogger.debug('No local device token to sync', tag: 'Notifications');
      return false;
    }

    try {
      // Get platform
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Call config API with device token
      final configResponse = await AuthService.syncDeviceTokenWithServer(
        localDeviceToken: _deviceToken!,
        platform: platform,
      );

      // Check if the response indicates the token was updated
      final syncStatus = configResponse['token_sync_status'];

      if (syncStatus == 'matched' || syncStatus == 'updated') {
        AppLogger.endOperation('Device token sync via config', tag: 'Notifications', success: true);
        _lastRegisteredToken = _deviceToken;
        return true;
      } else {
        AppLogger.warning('Config API sync incomplete, falling back to direct registration', tag: 'Notifications');
        return await _fallbackDeviceTokenSync();
      }

    } catch (e) {
      AppLogger.error('Error syncing device token via config', tag: 'Notifications', error: e);
      return await _fallbackDeviceTokenSync();
    }
  }

  /// Fallback device token sync using direct registration API
  Future<bool> _fallbackDeviceTokenSync() async {
    try {
      // Get auth token first
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        AppLogger.debug('No auth token available for fallback sync', tag: 'Notifications');
        return false;
      }

      final reactionService = ReactionService();
      reactionService.setAuthToken(authToken);

      // Register the current device token directly
      final platform = Platform.isIOS ? 'ios' : 'android';

      await reactionService.registerDeviceToken(
        DeviceTokenRequest(
          deviceToken: _deviceToken!,
          platform: platform,
        ),
      );

      // Mark this token as successfully registered
      _lastRegisteredToken = _deviceToken;
      AppLogger.info('Device token synchronized via fallback method', tag: 'Notifications');
      return true;

    } catch (e) {
      AppLogger.error('Error in fallback device token sync', tag: 'Notifications', error: e);
      return false;
    }
  }

  /// Legacy method - keep for backwards compatibility
  Future<bool> syncDeviceTokenWithServer() async {
    return await syncDeviceTokenViaConfig();
  }

  /// Clears device token state.
  ///
  /// Call on logout to reset registration flags. This allows
  /// re-registration on next login with the same or new token.
  void clearDeviceTokenState() {
    _lastRegisteredToken = null;
    AppLogger.debug('Device token state cleared', tag: 'Notifications');
  }

  /// Dispose resources safely
  void dispose() {
    _isDisposed = true;
    // Safely close stream controllers if they exist and are not already closed
    if (_messageStreamController != null && !_messageStreamController!.isClosed) {
      _messageStreamController!.close();
    }
    if (_tokenStreamController != null && !_tokenStreamController!.isClosed) {
      _tokenStreamController!.close();
    }
    _messageStreamController = null;
    _tokenStreamController = null;
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
      AppLogger.debug('Is registered for notifications: $result', tag: 'Notifications');
      return result == true;
    } catch (e) {
      AppLogger.error('Error checking registration status', tag: 'Notifications', error: e);
      return false;
    }
  }

  /// Debug method to force device token sync
  Future<bool> debugSyncDeviceToken() async {
    AppLogger.debug('Force sync device token requested', tag: 'Notifications');

    if (_deviceToken == null) {
      AppLogger.debug('No device token available - trying to get one', tag: 'Notifications');
      final result = await retryTokenRegistration();

      if (!result['success']) {
        AppLogger.warning('Failed to get device token', tag: 'Notifications');
        return false;
      }
    }

    // Force sync via config API
    return await syncDeviceTokenViaConfig();
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