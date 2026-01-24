import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/studio_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/order_status_screen.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import '../utils/validators.dart';
import '../utils/logger.dart';
import '../main.dart';

class DeepLinkService {
  static const String _baseUrl = 'https://nachna.com';
  static const MethodChannel _methodChannel = MethodChannel('nachna/deep_links');
  static const MethodChannel _instagramShareChannel = MethodChannel('nachna/instagram_share');
  
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._internal();
  
  // Deduplication and reentrancy guards
  static String? _lastHandledUrl;
  static DateTime? _lastHandledAt;
  static bool _isHandling = false;
  
  DeepLinkService._internal();
  
  /// Initialize deep link handling
  Future<void> initialize() async {
    try {
      // Listen for deep links while app is running
      _methodChannel.setMethodCallHandler((call) async {
        if (call.method == 'handleDeepLink') {
          final String? url = call.arguments as String?;
          if (url != null) {
            await _handleIncomingLink(url);
          }
        }
      });

      // Check for initial deep link when app is launched
      // Avoid double-processing: iOS sometimes delivers continueUserActivity and initialLink
      // We'll rely on continueUserActivity path; keep this call but guard inside handler
      final String? initialLink = await _methodChannel.invokeMethod('getInitialLink');
      if (initialLink != null) {
        await _handleIncomingLink(initialLink);
      }
    } catch (e) {
      AppLogger.error('Error initializing deep link service', tag: 'DeepLink', error: e);
    }
  }
  
  /// Handle incoming deep link
  Future<void> _handleIncomingLink(String url) async {
    try {
      AppLogger.debug('Processing URL', tag: 'DeepLink');

      // Validate URL length first to prevent DoS
      if (url.isEmpty || url.length > UrlValidator.maxUrlLength) {
        AppLogger.warning('Deep link rejected: invalid length', tag: 'DeepLink');
        return;
      }

      // Drop duplicates within a short window
      final now = DateTime.now();
      if (_lastHandledUrl == url && _lastHandledAt != null && now.difference(_lastHandledAt!).inSeconds < 3) {
        AppLogger.debug('Deep link ignored (duplicate within window)', tag: 'DeepLink');
        return;
      }
      if (_isHandling) {
        AppLogger.debug('Deep link ignored (already handling)', tag: 'DeepLink');
        return;
      }
      _isHandling = true;
      _lastHandledUrl = url;
      _lastHandledAt = now;

      // Safely parse URL
      Uri uri;
      try {
        uri = Uri.parse(url);
      } catch (e) {
        AppLogger.warning('Deep link rejected: malformed URL', tag: 'DeepLink');
        return;
      }

      // Validate URL scheme and structure
      if (!_isValidDeepLinkScheme(uri)) {
        AppLogger.warning('Deep link rejected: invalid scheme or host', tag: 'DeepLink');
        return;
      }

      AppLogger.debug('Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}', tag: 'DeepLink');

      // Handle artist deep links:
      // Custom scheme: nachna://artist/{artistId}
      // Universal link: https://nachna.com/artist/{artistId}
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'artist') {
        final artistId = PathValidator.sanitizeId(uri.pathSegments[1]);
        if (artistId != null) {
          AppLogger.info('Navigating to artist', tag: 'DeepLink');
          await _navigateToArtistInternal(artistId);
        } else {
          AppLogger.warning('Deep link rejected: invalid artist ID', tag: 'DeepLink');
        }
      } else if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'studio') {
        final studioId = PathValidator.sanitizeId(uri.pathSegments[1]);
        if (studioId != null) {
          AppLogger.info('Navigating to studio', tag: 'DeepLink');
          await _navigateToStudioInternal(studioId);
        } else {
          AppLogger.warning('Deep link rejected: invalid studio ID', tag: 'DeepLink');
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'artist') {
        // Handle custom scheme: nachna://artist/{artistId}
        final rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : uri.path.replaceFirst('/', '');
        final artistId = PathValidator.sanitizeId(rawId);
        if (artistId != null && artistId.isNotEmpty) {
          AppLogger.info('Navigating to artist via custom scheme', tag: 'DeepLink');
          await _navigateToArtistInternal(artistId);
        } else {
          AppLogger.warning('Deep link rejected: invalid artist ID in custom scheme', tag: 'DeepLink');
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'studio') {
        // Handle custom scheme: nachna://studio/{studioId}
        final rawId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : uri.path.replaceFirst('/', '');
        final studioId = PathValidator.sanitizeId(rawId);
        if (studioId != null && studioId.isNotEmpty) {
          AppLogger.info('Navigating to studio via custom scheme', tag: 'DeepLink');
          await _navigateToStudioInternal(studioId);
        } else {
          AppLogger.warning('Deep link rejected: invalid studio ID in custom scheme', tag: 'DeepLink');
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'order-status') {
        // Handle custom scheme: nachna://order-status/{orderId}
        AppLogger.debug('Processing order-status pattern', tag: 'DeepLink');

        String? rawOrderId;
        if (uri.pathSegments.length >= 2) {
          rawOrderId = uri.pathSegments[1];
        } else if (uri.pathSegments.length == 1 && uri.pathSegments[0].isNotEmpty) {
          rawOrderId = uri.pathSegments[0];
        } else {
          final path = uri.path;
          if (path.startsWith('/') && path.length > 1) {
            rawOrderId = path.substring(1);
          }
        }

        final orderId = PathValidator.sanitizeId(rawOrderId);
        if (orderId != null && orderId.isNotEmpty && PathValidator.isValidOrderId(orderId)) {
          AppLogger.info('Navigating to order status via custom scheme', tag: 'DeepLink');
          await _navigateToOrderStatusInternal(orderId);
        } else {
          AppLogger.warning('Deep link rejected: invalid order ID', tag: 'DeepLink');
        }
      } else if (uri.path == '/order/status' && uri.queryParameters.containsKey('order_id')) {
        // Handle universal link: https://nachna.com/order/status?order_id={orderId}
        final rawOrderId = uri.queryParameters['order_id'];
        final orderId = PathValidator.sanitizeId(rawOrderId);
        if (orderId != null && orderId.isNotEmpty && PathValidator.isValidOrderId(orderId)) {
          AppLogger.info('Navigating to order status via universal link', tag: 'DeepLink');
          await _navigateToOrderStatusInternal(orderId);
        } else {
          AppLogger.warning('Deep link rejected: invalid order ID in query', tag: 'DeepLink');
        }
      } else {
        AppLogger.warning('Deep link rejected: unrecognized pattern', tag: 'DeepLink');
      }
    } catch (e) {
      AppLogger.error('Error handling deep link', tag: 'DeepLink', error: e);
    } finally {
      // Keep a short lock to prevent UIKit re-entrant deliveries from bouncing us
      await Future.delayed(const Duration(milliseconds: 250));
      _isHandling = false;
    }
  }

  /// Validates that the deep link has an allowed scheme and host
  bool _isValidDeepLinkScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    // Allow custom nachna:// scheme
    if (scheme == 'nachna') {
      final validHosts = ['artist', 'studio', 'order-status'];
      return validHosts.contains(uri.host.toLowerCase());
    }

    // Allow https:// links to nachna.com
    if (scheme == 'https' || scheme == 'http') {
      final validHosts = ['nachna.com', 'www.nachna.com'];
      return validHosts.contains(uri.host.toLowerCase());
    }

    return false;
  }
  
  /// Generate shareable URL for an artist.
  /// Prefer universal link so it opens on web and defers to the app via iOS Universal Links / Android App Links.
  static String generateArtistShareUrl(String artistId) {
    return '$_baseUrl/artist/$artistId';
  }

  /// Generate shareable URL for a studio (direct app link)
  static String generateStudioShareUrl(String studioId) {
    // Use a universal link so it opens in the app via iOS Universal Links / Android App Links,
    // and falls back to the website when the app is not installed
    return '$_baseUrl/studio/$studioId';
  }

  /// Share to Instagram Story (iOS). Returns true if Instagram story intent was opened.
  static Future<bool> shareToInstagramStory({
    required String contentUrl,
    String? topColorHex,
    String? bottomColorHex,
  }) async {
    try {
      final bool ok = await _instagramShareChannel.invokeMethod('shareToStory', {
        'contentURL': contentUrl,
        'topColor': topColorHex,
        'bottomColor': bottomColorHex,
      });
      return ok;
    } catch (_) {
      return false;
    }
  }
  
  /// Internal method to navigate to artist (used by deep link handler)
  Future<void> _navigateToArtistInternal(String artistId) async {
    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('Navigator not available, cannot navigate to artist', tag: 'DeepLink');
        return;
      }

      AppLogger.info('Navigating to artist detail', tag: 'DeepLink');

      // First navigate to home screen, then to artist detail
      // Reset stack to a single HomeScreen to avoid route info errors
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
        (route) => false,
      );

      // Add a small delay to ensure the home screen is loaded
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if navigator is still available
      if (MyApp.navigatorKey.currentState == null) {
        AppLogger.warning('Navigator no longer available', tag: 'DeepLink');
        return;
      }

      // Navigate to artist detail
      MyApp.navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(
            artistId: artistId,
            fromNotification: false,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Error navigating to artist', tag: 'DeepLink', error: e);
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
          (route) => false,
        );
      }
    }
  }

  /// Internal method to navigate to studio (used by deep link handler)
  Future<void> _navigateToStudioInternal(String studioId) async {
    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('Navigator not available, cannot navigate to studio', tag: 'DeepLink');
        return;
      }

      AppLogger.info('Fetching studio data', tag: 'DeepLink');

      // Fetch studio data first
      final studios = await ApiService().fetchStudios();
      final studio = studios.firstWhere(
        (s) => s.id == studioId,
        orElse: () => throw Exception('Studio not found'),
      );

      AppLogger.info('Found studio, navigating', tag: 'DeepLink');

      // Check if navigator is still available after API call
      if (MyApp.navigatorKey.currentState == null) {
        AppLogger.warning('Navigator no longer available after API call', tag: 'DeepLink');
        return;
      }

      // Navigate to home screen first, then to studio detail
      MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)), // Studios tab
        (route) => false,
      );

      // Add a small delay to ensure the home screen is loaded
      await Future.delayed(const Duration(milliseconds: 300));

      // Final check before navigation to studio detail
      if (MyApp.navigatorKey.currentState != null) {
        AppLogger.info('Navigating to studio detail', tag: 'DeepLink');
        MyApp.navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StudioDetailScreen(studio: studio),
          ),
        );
      } else {
        AppLogger.warning('Navigator no longer available', tag: 'DeepLink');
      }
    } catch (e) {
      AppLogger.error('Error navigating to studio', tag: 'DeepLink', error: e);
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        AppLogger.debug('Falling back to studios home screen', tag: 'DeepLink');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
          (route) => false,
        );
      }
    }
  }

  /// Navigate to artist from deep link
  static Future<void> navigateToArtist(BuildContext context, String artistId, {bool fromNotification = false}) async {
    // Validate and sanitize artist ID
    final sanitizedId = PathValidator.sanitizeId(artistId);
    if (sanitizedId == null) {
      AppLogger.warning('Invalid artist ID provided to navigateToArtist', tag: 'DeepLink');
      return;
    }

    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('Navigator not available, cannot navigate to artist', tag: 'DeepLink');
        return;
      }

      AppLogger.info('Navigating to artist', tag: 'DeepLink');

      // First navigate to home screen, then to artist detail
      navigator.popUntil((route) => route.isFirst);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
      );

      // Add a small delay to ensure the home screen is loaded
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if navigator is still available
      if (MyApp.navigatorKey.currentState == null) {
        AppLogger.warning('Navigator no longer available', tag: 'DeepLink');
        return;
      }

      // Navigate to artist detail
      MyApp.navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(
            artistId: sanitizedId,
            fromNotification: fromNotification,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Error navigating to artist', tag: 'DeepLink', error: e);
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
          (route) => false,
        );
      }
    }
  }

  /// Navigate to studio from deep link
  static Future<void> navigateToStudio(BuildContext context, String studioId) async {
    // Validate and sanitize studio ID
    final sanitizedId = PathValidator.sanitizeId(studioId);
    if (sanitizedId == null) {
      AppLogger.warning('Invalid studio ID provided to navigateToStudio', tag: 'DeepLink');
      return;
    }

    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('Navigator not available, cannot navigate to studio', tag: 'DeepLink');
        return;
      }

      AppLogger.info('Fetching studio data', tag: 'DeepLink');

      // Fetch studio data first
      final studios = await ApiService().fetchStudios();
      final studio = studios.firstWhere(
        (s) => s.id == sanitizedId,
        orElse: () => throw Exception('Studio not found'),
      );

      AppLogger.info('Found studio, navigating', tag: 'DeepLink');

      // Check if navigator is still available after API call
      if (MyApp.navigatorKey.currentState == null) {
        AppLogger.warning('Navigator no longer available after API call', tag: 'DeepLink');
        return;
      }

      // Navigate to home screen first, then to studio detail
      MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)), // Studios tab
        (route) => false,
      );

      // Add a small delay to ensure the home screen is loaded
      await Future.delayed(const Duration(milliseconds: 300));

      // Final check before navigation to studio detail
      if (MyApp.navigatorKey.currentState != null) {
        AppLogger.info('Navigating to studio detail', tag: 'DeepLink');
        MyApp.navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StudioDetailScreen(studio: studio),
          ),
        );
      } else {
        AppLogger.warning('Navigator no longer available', tag: 'DeepLink');
      }
    } catch (e) {
      AppLogger.error('Error navigating to studio', tag: 'DeepLink', error: e);
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        AppLogger.debug('Falling back to studios home screen', tag: 'DeepLink');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
          (route) => false,
        );
      }
    }
  }

  /// Internal method to navigate to order status (used by deep link handler)
  Future<void> _navigateToOrderStatusInternal(String orderId) async {
    try {
      AppLogger.info('Attempting to navigate to order status', tag: 'DeepLink');

      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        AppLogger.warning('Navigator not available, cannot navigate to order status', tag: 'DeepLink');
        return;
      }

      AppLogger.info('Navigating to order status screen', tag: 'DeepLink');

      // Navigate directly to order status screen
      navigator.push(
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(orderId: orderId),
        ),
      );

      AppLogger.info('Successfully navigated to order status screen', tag: 'DeepLink');
    } catch (e) {
      AppLogger.error('Error navigating to order status', tag: 'DeepLink', error: e);
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        AppLogger.debug('Falling back to home screen', tag: 'DeepLink');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
          (route) => false,
        );
      }
    }
  }
} 