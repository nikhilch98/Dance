import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/home_screen.dart';

class DeepLinkService {
  static const String _baseUrl = 'https://nachna.com';
  static const MethodChannel _methodChannel = MethodChannel('nachna/deep_links');
  
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._internal();
  
  DeepLinkService._internal();
  
  /// Initialize deep link handling
  Future<void> initialize({required Function(String) onArtistLink}) async {
    try {
      // Listen for deep links while app is running
      _methodChannel.setMethodCallHandler((call) async {
        if (call.method == 'handleDeepLink') {
          final String? url = call.arguments as String?;
          if (url != null) {
            await _handleIncomingLink(url, onArtistLink);
          }
        }
      });
      
      // Check for initial deep link when app is launched
      final String? initialLink = await _methodChannel.invokeMethod('getInitialLink');
      if (initialLink != null) {
        await _handleIncomingLink(initialLink, onArtistLink);
      }
    } catch (e) {
      print('Error initializing deep link service: $e');
    }
  }
  
  /// Handle incoming deep link
  Future<void> _handleIncomingLink(String url, Function(String) onArtistLink) async {
    try {
      final uri = Uri.parse(url);
      print('Deep link received: $url');
      
      // Handle artist deep links: https://nachna.com/artist/{artistId}
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'artist') {
        final artistId = uri.pathSegments[1];
        print('Navigating to artist: $artistId');
        onArtistLink(artistId);
      }
    } catch (e) {
      print('Error handling deep link: $e');
    }
  }
  
  /// Generate shareable URL for an artist
  static String generateArtistShareUrl(String artistId) {
    return '$_baseUrl/artist/$artistId';
  }
  
  /// Navigate to artist from deep link
  static void navigateToArtist(BuildContext context, String artistId) {
    // First navigate to home screen, then to artist detail
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
      (route) => false,
    );
    
    // Add a small delay to ensure the home screen is loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(
            artistId: artistId,
            fromNotification: false,
          ),
        ),
      );
    });
  }
} 