import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/responsive_utils.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String message;
  final String appStoreUrl;
  final String currentVersion;
  final String minimumVersion;

  const ForceUpdateDialog({
    super.key,
    required this.message,
    required this.appStoreUrl,
    required this.currentVersion,
    required this.minimumVersion,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button dismiss
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0F),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00D4FF).withOpacity(0.2),
                            const Color(0xFF9C27B0).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update,
                        size: 48,
                        color: Color(0xFF00D4FF),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Update Required',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Version info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Current Version: $currentVersion',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Required Version: $minimumVersion',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                              color: const Color(0xFF00D4FF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Message
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _launchAppStore(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF00D4FF).withOpacity(0.3),
                        ),
                        child: Text(
                          'Update Now',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Note
                    Text(
                      'You cannot continue using the app until you update.',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                        color: Colors.white.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchAppStore() async {
    try {
      final Uri url = Uri.parse(appStoreUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback - try to open App Store app directly
        final Uri fallbackUrl = Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID');
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(
            fallbackUrl,
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      print('Error launching App Store: $e');
      // Show error message to user
    }
  }
}
