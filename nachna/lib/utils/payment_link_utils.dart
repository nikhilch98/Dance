import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/order_service.dart';

class PaymentLinkUtils {
  /// Handles launching payment links based on their type
  /// [paymentLink] - The payment link (URL or phone number), ignored for 'nachna' type
  /// [paymentLinkType] - The type of payment link ('url', 'whatsapp', or 'nachna')
  /// [context] - BuildContext for showing error messages and loading states
  /// [workshopDetails] - Optional workshop details for WhatsApp message
  /// [workshopUuid] - Required for 'nachna' type to create payment link
  static Future<void> launchPaymentLink({
    required String paymentLink,
    String? paymentLinkType,
    required BuildContext context,
    Map<String, String?>? workshopDetails,
    String? workshopUuid,
  }) async {
    // Default to 'url' if paymentLinkType is null or empty for backward compatibility
    final linkType = paymentLinkType?.toLowerCase() ?? 'url';
    
    print('🔍 Debug: paymentLink=$paymentLink, paymentLinkType=$paymentLinkType, linkType=$linkType, workshopUuid=$workshopUuid');
    
    // Handle 'nachna' payment type - create payment link via API
    if (linkType == 'nachna') {
      await _handleNachnaPayment(context, workshopUuid, workshopDetails);
      return;
    }
    
    // Handle traditional payment types
    if (paymentLink.isEmpty) {
      _showErrorSnackBar(context, 'Registration link not available');
      return;
    }

    try {
      Uri uri;
      
      switch (linkType) {
        case 'whatsapp':
          uri = _buildWhatsAppUri(paymentLink, workshopDetails);
          print('🔍 WhatsApp: Original number: $paymentLink, Generated URL: $uri');
          break;
        case 'url':
        default:
          uri = Uri.parse(paymentLink);
          print('🔍 URL: Generated URL: $uri');
          break;
      }

      print('🔍 Attempting to launch: $uri');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Successfully launched: $uri');
      } else {
        print('❌ canLaunchUrl returned false for: $uri');
        throw Exception('Cannot launch $uri');
      }
    } catch (e) {
      print('❌ Error launching payment link: $e');
      
      // Provide more specific error messages for WhatsApp
      String errorMessage;
      if (paymentLinkType?.toLowerCase() == 'whatsapp') {
        errorMessage = 'Could not open WhatsApp. Please make sure WhatsApp is installed on your device.';
      } else {
        errorMessage = 'Could not open registration link. Please try again.';
      }
      
      _showErrorSnackBar(context, errorMessage);
    }
  }

  /// Handles 'nachna' payment type by creating payment link via API
  static Future<void> _handleNachnaPayment(
    BuildContext context,
    String? workshopUuid,
    Map<String, String?>? workshopDetails,
  ) async {
    if (workshopUuid == null || workshopUuid.isEmpty) {
      _showErrorSnackBar(context, 'Workshop information not available');
      return;
    }

    // Show loading dialog
    final loadingDialog = _showLoadingDialog(context);

    try {
      final orderService = OrderService();
      final result = await orderService.createPaymentLink(workshopUuid);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result.isSuccess) {
        // Success - new payment link created
        print('✅ Payment link created successfully: ${result.successResponse!.paymentLinkUrl}');
        await _launchUrl(context, result.successResponse!.paymentLinkUrl);
        
      } else if (result.existingResponse != null) {
        // Existing payment link found
        final existingUrl = result.existingResponse!.existingPaymentLinkUrl;
        if (existingUrl != null && existingUrl.isNotEmpty) {
          print('📋 Using existing payment link: $existingUrl');
          await _launchUrl(context, existingUrl);
        } else {
          _showErrorSnackBar(context, 'Existing payment link is invalid. Please contact support.');
        }
        
      } else {
        // Error occurred
        final errorMessage = result.errorMessage ?? 'Failed to create payment link';
        print('❌ Payment link creation failed: $errorMessage');
        _showErrorSnackBar(context, errorMessage);
      }
      
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      print('❌ Error in _handleNachnaPayment: $e');
      _showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Helper method to launch URL with error handling
  static Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Successfully launched: $uri');
      } else {
        throw Exception('Cannot launch $url');
      }
    } catch (e) {
      print('❌ Error launching URL: $e');
      _showErrorSnackBar(context, 'Could not open payment link. Please try again.');
    }
  }

  /// Shows loading dialog for payment link creation
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Creating payment link...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds WhatsApp URI from phone number with optional message
  /// [phoneNumber] - 10-digit phone number without country code
  /// [workshopDetails] - Optional workshop details for pre-filled message
  static Uri _buildWhatsAppUri(String phoneNumber, Map<String, String?>? workshopDetails) {
    print('🔍 _buildWhatsAppUri input: $phoneNumber');
    
    // Clean the phone number - remove spaces, dashes, and other non-numeric characters
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    print('🔍 Cleaned number: $cleanedNumber');
    
    // Add Indian country code (91) to the 10-digit number
    String whatsappNumber = '91$cleanedNumber';
    print('🔍 WhatsApp number with country code: $whatsappNumber');
    
    // Create the WhatsApp message
    String message = _buildWhatsAppMessage(workshopDetails);
    print('🔍 WhatsApp message: $message');
    
    // Create WhatsApp deep link with message
    final uri = Uri.parse('https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}');
    print('🔍 Final WhatsApp URI: $uri');
    return uri;
  }

  /// Builds a formatted WhatsApp message with workshop details
  static String _buildWhatsAppMessage(Map<String, String?>? workshopDetails) {
    if (workshopDetails == null) {
      return "Hi! I'm interested in registering for your dance workshop. Could you please share the registration details?";
    }

    String message = "Hi! I'm interested in registering for the following dance workshop:\n\n";
    
    // Add workshop details with proper formatting
    if (workshopDetails['song']?.isNotEmpty == true && workshopDetails['song'] != 'TBA') {
      message += "🎵 Song: ${_formatText(workshopDetails['song'])}\n";
    }
    
    if (workshopDetails['artist']?.isNotEmpty == true && workshopDetails['artist'] != 'TBA') {
      message += "💃 Artist: ${_formatText(workshopDetails['artist'])}\n";
    }
    
//     if (workshopDetails['studio']?.isNotEmpty == true && workshopDetails['studio'] != 'TBA') {
//       message += "🏢 Studio: ${_formatText(workshopDetails['studio'])}\n";
//     }
    
    if (workshopDetails['date']?.isNotEmpty == true && workshopDetails['date'] != 'TBA') {
      message += "📅 Date: ${workshopDetails['date']}\n";
    }
    
    if (workshopDetails['time']?.isNotEmpty == true && workshopDetails['time'] != 'TBA') {
      message += "⏰ Time: ${workshopDetails['time']}\n";
    }
    
    message += "\nCould you please help me with the registration process? Thank you! 🙏";
    
    return message;
  }

  /// Helper method to format text to title case
  static String _formatText(String? text) {
    if (text == null || text.isEmpty) return '';
    
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Shows error snackbar with consistent styling
  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
} 