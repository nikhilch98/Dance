import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/studio_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/order_status_screen.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
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
      print('Error initializing deep link service: $e');
    }
  }
  
  /// Handle incoming deep link
  Future<void> _handleIncomingLink(String url) async {
    try {
      print('🔗 Deep link service: Processing URL: $url');
      
      // Drop duplicates within a short window
      final now = DateTime.now();
      if (_lastHandledUrl == url && _lastHandledAt != null && now.difference(_lastHandledAt!).inSeconds < 3) {
        print('Deep link ignored (duplicate within window): $url');
        return;
      }
      if (_isHandling) {
        print('Deep link ignored (already handling): $url');
        return;
      }
      _isHandling = true;
      _lastHandledUrl = url;
      _lastHandledAt = now;

      final uri = Uri.parse(url);
      print('🔗 Deep link service: Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}, query: ${uri.queryParameters}');
      print('🔗 Deep link service: Full URL breakdown:');
      print('   Original URL: $url');
      print('   Scheme: ${uri.scheme}');
      print('   Host: ${uri.host}');
      print('   Path: ${uri.path}');
      print('   Path segments: ${uri.pathSegments}');
      print('   Query parameters: ${uri.queryParameters}');
      print('   Authority: ${uri.authority}');
      
      // Handle artist deep links: 
      // Custom scheme: nachna://artist/{artistId}
      // Universal link: https://nachna.com/artist/{artistId}
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'artist') {
        final artistId = uri.pathSegments[1];
        print('Navigating to artist: $artistId');
        await _navigateToArtistInternal(artistId);
      } else if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'studio') {
        final studioId = uri.pathSegments[1];
        print('Navigating to studio: $studioId');
        await _navigateToStudioInternal(studioId);
      } else if (uri.scheme == 'nachna' && uri.host == 'artist') {
        // Handle custom scheme: nachna://artist/{artistId}
        final artistId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : uri.path.replaceFirst('/', '');
        if (artistId.isNotEmpty) {
          print('Navigating to artist via custom scheme: $artistId');
          await _navigateToArtistInternal(artistId);
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'studio') {
        // Handle custom scheme: nachna://studio/{studioId}
        final studioId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : uri.path.replaceFirst('/', '');
        if (studioId.isNotEmpty) {
          print('Navigating to studio via custom scheme: $studioId');
          await _navigateToStudioInternal(studioId);
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'order-status') {
        // Handle custom scheme: nachna://order-status/{orderId}
        final orderId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : uri.path.replaceFirst('/', '');
        if (orderId.isNotEmpty) {
          print('🔗 Deep link service: Navigating to order status via custom scheme: $orderId');
          await _navigateToOrderStatusInternal(orderId);
        }
      } else if (uri.path == '/order/status' && uri.queryParameters.containsKey('order_id')) {
        // Handle universal link: https://nachna.com/order/status?order_id={orderId}
        final orderId = uri.queryParameters['order_id'];
        if (orderId != null && orderId.isNotEmpty) {
          print('🔗 Deep link service: Navigating to order status via universal link: $orderId');
          await _navigateToOrderStatusInternal(orderId);
        }
      } else if (uri.scheme == 'nachna' && uri.host == 'order-status' && uri.pathSegments.isNotEmpty) {
        // Alternative pattern: nachna://order-status/{orderId} (with path segments)
        final orderId = uri.pathSegments[0];
        if (orderId.isNotEmpty) {
          print('🔗 Deep link service: Navigating to order status via alternative pattern: $orderId');
          await _navigateToOrderStatusInternal(orderId);
        }
      }
    } catch (e) {
      print('Error handling deep link: $e');
    } finally {
      // Keep a short lock to prevent UIKit re-entrant deliveries from bouncing us
      await Future.delayed(const Duration(milliseconds: 250));
      _isHandling = false;
    }
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
        print('Navigator not available, cannot navigate to artist');
        return;
      }
      
      print('Navigating to artist: $artistId');
      
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
        print('Navigator no longer available, cannot continue navigation');
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
      print('Error navigating to artist: $e');
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
        print('Navigator not available, cannot navigate to studio');
        return;
      }
      
      print('Fetching studio data for ID: $studioId');
      
      // Fetch studio data first
      final studios = await ApiService().fetchStudios();
      final studio = studios.firstWhere(
        (s) => s.id == studioId,
        orElse: () => throw Exception('Studio not found with ID: $studioId'),
      );
      
      print('Found studio: ${studio.name}');
      
      // Check if navigator is still available after API call
      if (MyApp.navigatorKey.currentState == null) {
        print('Navigator no longer available after API call, cannot continue navigation');
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
        print('Navigating to studio detail: ${studio.name}');
        MyApp.navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StudioDetailScreen(studio: studio),
          ),
        );
      } else {
        print('Navigator no longer available, cannot navigate to studio detail');
      }
    } catch (e) {
      print('Error navigating to studio: $e');
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        print('Falling back to studios home screen');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
          (route) => false,
        );
      }
    }
  }

  /// Navigate to artist from deep link
  static Future<void> navigateToArtist(BuildContext context, String artistId, {bool fromNotification = false}) async {
    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        print('Navigator not available, cannot navigate to artist');
        return;
      }
      
      print('Navigating to artist: $artistId');
      
      // First navigate to home screen, then to artist detail
      navigator.popUntil((route) => route.isFirst);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
      );
      
      // Add a small delay to ensure the home screen is loaded
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if navigator is still available
      if (MyApp.navigatorKey.currentState == null) {
        print('Navigator no longer available, cannot continue navigation');
        return;
      }
      
      // Navigate to artist detail
      MyApp.navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(
            artistId: artistId,
            fromNotification: fromNotification,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to artist: $e');
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
    try {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        print('Navigator not available, cannot navigate to studio');
        return;
      }
      
      print('Fetching studio data for ID: $studioId');
      
      // Fetch studio data first
      final studios = await ApiService().fetchStudios();
      final studio = studios.firstWhere(
        (s) => s.id == studioId,
        orElse: () => throw Exception('Studio not found with ID: $studioId'),
      );
      
      print('Found studio: ${studio.name}');
      
      // Check if navigator is still available after API call
      if (MyApp.navigatorKey.currentState == null) {
        print('Navigator no longer available after API call, cannot continue navigation');
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
        print('Navigating to studio detail: ${studio.name}');
        MyApp.navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => StudioDetailScreen(studio: studio),
          ),
        );
      } else {
        print('Navigator no longer available, cannot navigate to studio detail');
      }
    } catch (e) {
      print('Error navigating to studio: $e');
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        print('Falling back to studios home screen');
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
      print('🔗 Deep link service: Attempting to navigate to order status for order: $orderId');
      
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) {
        print('❌ Navigator not available, cannot navigate to order status');
        return;
      }
      
      print('✅ Navigator available, navigating to order status: $orderId');
      
      // Navigate directly to order status screen
      navigator.push(
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(orderId: orderId),
        ),
      );
      
      print('✅ Successfully navigated to order status screen');
    } catch (e) {
      print('❌ Error navigating to order status: $e');
      // Fallback to home screen if available
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        print('🔄 Falling back to home screen');
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
          (route) => false,
        );
      }
    }
  }
} 