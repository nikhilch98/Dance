import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentLinkUtils {
  /// Handles launching payment links based on their type
  /// [paymentLink] - The payment link (URL or phone number)
  /// [paymentLinkType] - The type of payment link ('url' or 'whatsapp')
  /// [context] - BuildContext for showing error messages
  /// [workshopDetails] - Optional workshop details for WhatsApp message
  static Future<void> launchPaymentLink({
    required String paymentLink,
    String? paymentLinkType,
    required BuildContext context,
    Map<String, String?>? workshopDetails,
  }) async {
    if (paymentLink.isEmpty) {
      _showErrorSnackBar(context, 'Registration link not available');
      return;
    }

    try {
      Uri uri;
      
      // Default to 'url' if paymentLinkType is null or empty for backward compatibility
      final linkType = paymentLinkType?.toLowerCase() ?? 'url';
      
      print('🔍 Debug: paymentLink=$paymentLink, paymentLinkType=$paymentLinkType, linkType=$linkType');
      
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
    
    if (workshopDetails['studio']?.isNotEmpty == true && workshopDetails['studio'] != 'TBA') {
      message += "🏢 Studio: ${_formatText(workshopDetails['studio'])}\n";
    }
    
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