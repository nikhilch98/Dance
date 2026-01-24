import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utility class for launching URLs, with special handling for Instagram.
class UrlLauncherUtils {
  /// Launch a generic URL in an external application.
  ///
  /// Returns true if the URL was launched successfully, false otherwise.
  static Future<bool> launchGenericUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback to web browser
        final webUri = Uri.parse(url);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.platformDefault);
          return true;
        }
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
    return false;
  }

  /// Launch an Instagram URL, preferring the native app when available.
  ///
  /// This method attempts to open the Instagram app first. If not available,
  /// it falls back to opening the URL in a web browser.
  ///
  /// Returns true if launched successfully, false otherwise.
  static Future<bool> launchInstagram(String instagramUrl) async {
    try {
      final uri = Uri.parse(instagramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback to web browser
        final webUri = Uri.parse(instagramUrl);
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.platformDefault);
          return true;
        }
      }
    } catch (e) {
      print('Error launching Instagram: $e');
    }
    return false;
  }

  /// Launch an Instagram profile by username, preferring the native app.
  ///
  /// This method extracts the username from an Instagram URL and attempts
  /// to open it in the Instagram app. Falls back to web if app is not available.
  ///
  /// [instagramUrl] can be a full Instagram URL or just a username.
  /// [context] is required to show error snackbars.
  ///
  /// Returns true if launched successfully, false otherwise.
  static Future<bool> launchInstagramProfile(
    String instagramUrl, {
    BuildContext? context,
  }) async {
    try {
      String? username;

      // Extract username from URL
      if (instagramUrl.contains('instagram.com/')) {
        final parts = instagramUrl.split('instagram.com/');
        if (parts.length > 1) {
          username = parts[1].split('/')[0].split('?')[0];
        }
      }

      if (username != null && username.isNotEmpty) {
        final appUrl = 'instagram://user?username=$username';
        final webUrl = 'https://instagram.com/$username';

        if (await canLaunchUrl(Uri.parse(appUrl))) {
          await launchUrl(Uri.parse(appUrl));
          return true;
        } else {
          await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
          return true;
        }
      } else {
        // Try launching the URL directly
        final uri = Uri.parse(instagramUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not launch $instagramUrl'),
                backgroundColor: Colors.red.withOpacity(0.8),
              ),
            );
          }
          return false;
        }
      }
    } catch (e) {
      print('Error launching Instagram profile: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open Instagram link'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
      return false;
    }
  }
}
