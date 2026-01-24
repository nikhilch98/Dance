import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'deep_link_service.dart';

/// Service for sharing content via various platforms (WhatsApp, Instagram, generic share).
///
/// This service provides a consistent sharing experience across the app,
/// with support for WhatsApp, Instagram Stories, and the native share sheet.
class ShareService {
  /// Share text via WhatsApp.
  ///
  /// Attempts to open WhatsApp Business first, then standard WhatsApp,
  /// then falls back to the WhatsApp web share URL.
  ///
  /// [text] The text content to share.
  /// [context] Required for showing error snackbars.
  ///
  /// Returns true if WhatsApp was opened successfully.
  static Future<bool> shareViaWhatsApp(String text, BuildContext context) async {
    try {
      final encoded = Uri.encodeComponent(text);

      // Try WhatsApp Business first
      final waBizUri = Uri.parse('whatsapp-business://send?text=$encoded');
      if (await canLaunchUrl(waBizUri)) {
        await launchUrl(waBizUri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Then standard WhatsApp
      final waUri = Uri.parse('whatsapp://send?text=$encoded');
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Fallback to WhatsApp web
      final waWeb = Uri.parse('https://wa.me/?text=$encoded');
      if (await canLaunchUrl(waWeb)) {
        await launchUrl(waWeb, mode: LaunchMode.externalApplication);
        return true;
      }

      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('WhatsApp not available'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
      return false;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open WhatsApp'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
      return false;
    }
  }

  /// Share to Instagram Story.
  ///
  /// [contentUrl] The URL to share in the story.
  /// [topColorHex] The top background color (e.g., '#FF006E').
  /// [bottomColorHex] The bottom background color (e.g., '#00D4FF').
  /// [context] Required for showing error snackbars.
  ///
  /// Returns true if Instagram was opened successfully.
  static Future<bool> shareToInstagramStory({
    required String contentUrl,
    required String topColorHex,
    required String bottomColorHex,
    required BuildContext context,
  }) async {
    final ok = await DeepLinkService.shareToInstagramStory(
      contentUrl: contentUrl,
      topColorHex: topColorHex,
      bottomColorHex: bottomColorHex,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Instagram not available'),
          backgroundColor: Colors.red.withOpacity(0.8),
        ),
      );
    }

    return ok;
  }

  /// Share using the native share sheet.
  ///
  /// [text] The text content to share.
  static Future<void> shareGeneric(String text) async {
    await Share.share(
      text,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  /// Show a modal bottom sheet with sharing options (WhatsApp, Instagram Story, More).
  ///
  /// [context] The build context.
  /// [text] The text content to share.
  /// [instagramShareUrl] The URL to share on Instagram Story.
  /// [instagramTopColor] Top gradient color for Instagram Story background.
  /// [instagramBottomColor] Bottom gradient color for Instagram Story background.
  static Future<void> showShareOptions({
    required BuildContext context,
    required String text,
    required String instagramShareUrl,
    String instagramTopColor = '#FF006E',
    String instagramBottomColor = '#00D4FF',
  }) async {
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.55),
                Colors.black.withOpacity(0.45),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // WhatsApp option
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'whatsapp-icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xFF25D366),
                          ),
                          child: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        );
                      },
                    ),
                  ),
                  title: const Text(
                    'Share on WhatsApp',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await shareViaWhatsApp(text, context);
                  },
                ),

                const Divider(color: Colors.white24, height: 1),

                // Instagram Story option
                ListTile(
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'instagram-icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  title: const Text(
                    'Share to Instagram Story',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await shareToInstagramStory(
                      contentUrl: instagramShareUrl,
                      topColorHex: instagramTopColor,
                      bottomColorHex: instagramBottomColor,
                      context: context,
                    );
                  },
                ),

                const Divider(color: Colors.white24, height: 1),

                // More options (native share)
                ListTile(
                  leading: const Icon(Icons.ios_share, color: Color(0xFF00D4FF)),
                  title: const Text(
                    'More...',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await shareGeneric(text);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
