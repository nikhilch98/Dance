import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import '../models/order.dart';

class QRCodeDisplay extends StatelessWidget {
  final Order order;
  final VoidCallback? onClose;
  final bool isFullscreen;

  const QRCodeDisplay({
    Key? key,
    required this.order,
    this.onClose,
    this.isFullscreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: SafeArea(
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registration QR Code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // QR Code content - made scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: _buildQRCodeContent(context, isFullscreen: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return _buildQRCodeContent(context);
    }
  }

  Widget _buildQRCodeContent(BuildContext context, {bool isFullscreen = false}) {
    if (!order.hasQRCode) {
      return _buildQRCodeUnavailable(context, isFullscreen: isFullscreen);
    }

    // Check if we have multiple QR codes
    final hasMultipleQRCodes = order.qrCodesData != null && order.qrCodesData!.length > 1;

    if (hasMultipleQRCodes) {
      return _buildMultipleQRCodesContent(context, isFullscreen: isFullscreen);
    } else {
      return _buildSingleQRCodeContent(context, isFullscreen: isFullscreen);
    }
  }

  Widget _buildSingleQRCodeContent(BuildContext context, {bool isFullscreen = false}) {
    return Container(
      padding: EdgeInsets.all(isFullscreen ? 24 : 16),
      margin: EdgeInsets.all(isFullscreen ? 0 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isFullscreen ? 0 : 20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR Code header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: const Color(0xFF10B981),
                      size: isFullscreen ? 28 : 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.formattedOrderId,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFullscreen ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.workshopDetails.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isFullscreen ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.workshopDetails.artistNames.join(', ')} • ${order.workshopDetails.studioName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: isFullscreen ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // QR Code Image
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildQRCodeImage(context, isFullscreen),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: order.qrCodeData != null
                    ? () => _saveQRCode(context, order.qrCodeData!, order.workshopDetails.title)
                    : null,
                icon: Icon(
                  Icons.save,
                  size: isFullscreen ? 20 : 18,
                  color: order.qrCodeData != null ? Colors.white : Colors.white.withOpacity(0.5),
                ),
                label: Text(
                  'Save',
                  style: TextStyle(
                    color: order.qrCodeData != null ? Colors.white : Colors.white.withOpacity(0.5),
                    fontSize: isFullscreen ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.qrCodeData != null
                      ? const Color(0xFF10B981)
                      : Colors.grey.withOpacity(0.3),
                  padding: EdgeInsets.symmetric(
                    horizontal: isFullscreen ? 20 : 16,
                    vertical: isFullscreen ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: order.qrCodeData != null
                    ? () => _shareQRCode(context, order.qrCodeData!, order.workshopDetails.title)
                    : null,
                icon: Icon(
                  Icons.share,
                  size: isFullscreen ? 20 : 18,
                  color: order.qrCodeData != null ? Colors.white : Colors.white.withOpacity(0.5),
                ),
                label: Text(
                  'Share',
                  style: TextStyle(
                    color: order.qrCodeData != null ? Colors.white : Colors.white.withOpacity(0.5),
                    fontSize: isFullscreen ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.qrCodeData != null
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.withOpacity(0.3),
                  padding: EdgeInsets.symmetric(
                    horizontal: isFullscreen ? 20 : 16,
                    vertical: isFullscreen ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // QR Code info
          Text(
            'Show this QR code to the admin at the workshop',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: isFullscreen ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Generated ${order.qrCodeGeneratedTime}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: isFullscreen ? 14 : 12,
            ),
          ),

          if (isFullscreen) ...[
            const SizedBox(height: 24),

            // Workshop details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workshop Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Date', order.workshopDetails.date),
                  _buildDetailRow('Time', order.workshopDetails.time),
                  _buildDetailRow('Amount Paid', order.formattedAmount),
                  _buildDetailRow('Status', order.statusText),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultipleQRCodesContent(BuildContext context, {bool isFullscreen = false}) {
    final qrCodesData = order.qrCodesData!;
    final workshopTitles = _getWorkshopTitles();

    return Container(
      padding: EdgeInsets.all(isFullscreen ? 24 : 16),
      margin: EdgeInsets.all(isFullscreen ? 0 : 16),
      constraints: BoxConstraints(
        maxHeight: isFullscreen ? MediaQuery.of(context).size.height * 0.8 : 600,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isFullscreen ? 0 : 20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: const Color(0xFF10B981),
                      size: isFullscreen ? 28 : 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.formattedOrderId,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFullscreen ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${qrCodesData.length} Workshop QR Codes',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isFullscreen ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bundle Purchase',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: isFullscreen ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scrollable QR codes list
          Expanded(
            child: ListView.builder(
              itemCount: qrCodesData.length,
              itemBuilder: (context, index) {
                final workshopUuid = qrCodesData.keys.elementAt(index);
                final qrCodeData = qrCodesData[workshopUuid]!;
                final workshopTitle = workshopTitles[workshopUuid] ?? 'Workshop ${index + 1}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Workshop title
                      Text(
                        workshopTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF00D4FF),
                          fontSize: isFullscreen ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // QR Code image
                      _buildQRCodeImageForMultiple(
                        context,
                        qrCodeData,
                        isFullscreen,
                      ),

                      const SizedBox(height: 12),

                      // Action buttons for this QR code
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _saveQRCode(context, qrCodeData, workshopTitle),
                            icon: Icon(
                              Icons.save,
                              size: isFullscreen ? 16 : 14,
                              color: const Color(0xFF10B981),
                            ),
                            label: Text(
                              'Save',
                              style: TextStyle(
                                color: const Color(0xFF10B981),
                                fontSize: isFullscreen ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isFullscreen ? 12 : 8,
                                vertical: isFullscreen ? 8 : 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _shareQRCode(context, qrCodeData, workshopTitle),
                            icon: Icon(
                              Icons.share,
                              size: isFullscreen ? 16 : 14,
                              color: const Color(0xFF3B82F6),
                            ),
                            label: Text(
                              'Share',
                              style: TextStyle(
                                color: const Color(0xFF3B82F6),
                                fontSize: isFullscreen ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isFullscreen ? 12 : 8,
                                vertical: isFullscreen ? 8 : 6,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Workshop info
                      Text(
                        'Show this QR code to the admin at the workshop',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.7),
                          fontSize: isFullscreen ? 12 : 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Generated ${order.qrCodeGeneratedTime}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: isFullscreen ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get workshop titles from workshop_details_map or fallback to workshop details
  Map<String, String> _getWorkshopTitles() {
    final titles = <String, String>{};

    // Try to get titles from workshop_details_map if available
    if (order.workshopDetailsMap != null) {
      order.workshopDetailsMap!.forEach((uuid, details) {
        final title = details['song'] as String? ?? details['title'] as String? ?? 'Workshop';
        titles[uuid] = title;
      });
    }

    // Fallback to bundle info if available
    if (titles.isEmpty && order.bundleInfo != null && order.bundleInfo!['workshops'] != null) {
      final workshops = order.bundleInfo!['workshops'] as List?;
      if (workshops != null) {
        for (final workshop in workshops) {
          if (workshop is Map && workshop['uuid'] != null) {
            final uuid = workshop['uuid'] as String;
            final title = workshop['song'] as String? ?? workshop['title'] as String? ?? 'Workshop';
            titles[uuid] = title;
          }
        }
      }
    }

    return titles;
  }

  Widget _buildQRCodeImage(BuildContext context, bool isFullscreen) {
    try {
      // Extract base64 data from data URL
      final qrData = order.qrCodeData!;
      String base64String;

      if (qrData.startsWith('data:image/png;base64,')) {
        base64String = qrData.substring('data:image/png;base64,'.length);
      } else {
        base64String = qrData;
      }

      final bytes = base64Decode(base64String);
      final size = isFullscreen ? 280.0 : 200.0;

      return Container(
        width: size,
        height: size,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildQRCodeError(isFullscreen);
          },
        ),
      );
    } catch (e) {
      return _buildQRCodeError(isFullscreen);
    }
  }

  Widget _buildQRCodeImageForMultiple(BuildContext context, String qrCodeData, bool isFullscreen) {
    try {
      // Extract base64 data from data URL
      String base64String;

      if (qrCodeData.startsWith('data:image/png;base64,')) {
        base64String = qrCodeData.substring('data:image/png;base64,'.length);
      } else {
        base64String = qrCodeData;
      }

      final bytes = base64Decode(base64String);
      final size = isFullscreen ? 200.0 : 150.0;

      return Container(
        width: size,
        height: size,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildQRCodeErrorForMultiple(isFullscreen);
          },
        ),
      );
    } catch (e) {
      return _buildQRCodeErrorForMultiple(isFullscreen);
    }
  }

  Widget _buildQRCodeError(bool isFullscreen) {
    final size = isFullscreen ? 280.0 : 200.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: isFullscreen ? 48 : 32,
          ),
          const SizedBox(height: 8),
          Text(
            'QR Code Error',
            style: TextStyle(
              color: Colors.red,
              fontSize: isFullscreen ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeErrorForMultiple(bool isFullscreen) {
    final size = isFullscreen ? 200.0 : 150.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: isFullscreen ? 32 : 24,
          ),
          const SizedBox(height: 4),
          Text(
            'QR Error',
            style: TextStyle(
              color: Colors.red,
              fontSize: isFullscreen ? 12 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeUnavailable(BuildContext context, {bool isFullscreen = false}) {
    return Container(
      padding: EdgeInsets.all(isFullscreen ? 32 : 24),
      margin: EdgeInsets.all(isFullscreen ? 0 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isFullscreen ? 0 : 20),
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            order.status == OrderStatus.paid 
              ? Icons.hourglass_top 
              : Icons.payment,
            color: Colors.orange,
            size: isFullscreen ? 64 : 48,
          ),
          const SizedBox(height: 16),
          Text(
            order.qrCodeStatus,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isFullscreen ? 20 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.status == OrderStatus.paid
              ? 'Your QR code is being generated. This usually takes a few minutes.'
              : 'Complete your payment to receive your QR code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: isFullscreen ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get QR code bytes
  Uint8List? _getQRCodeBytes(String qrCodeData) {
    try {
      debugPrint('DEBUG: Processing QR code data, length: ${qrCodeData.length}');
      debugPrint('DEBUG: Starts with: ${qrCodeData.substring(0, min(50, qrCodeData.length))}');

      String base64String;

      if (qrCodeData.startsWith('data:image/png;base64,')) {
        base64String = qrCodeData.substring('data:image/png;base64,'.length);
        debugPrint('DEBUG: Found data URL format, extracted base64');
      } else if (qrCodeData.startsWith('data:image/')) {
        // Handle other image formats
        final commaIndex = qrCodeData.indexOf(',');
        if (commaIndex != -1) {
          base64String = qrCodeData.substring(commaIndex + 1);
          debugPrint('DEBUG: Found generic data URL format');
        } else {
          base64String = qrCodeData;
          debugPrint('DEBUG: Using data as-is (no data URL prefix)');
        }
      } else {
        base64String = qrCodeData;
        debugPrint('DEBUG: Using data as-is');
      }

      debugPrint('DEBUG: Base64 string length: ${base64String.length}');

      final bytes = base64Decode(base64String);
      debugPrint('DEBUG: Successfully decoded ${bytes.length} bytes');

      return bytes;
    } catch (e) {
      debugPrint('DEBUG: Error decoding QR code: $e');
      return null;
    }
  }

  // Save QR code to gallery
  Future<void> _saveQRCode(BuildContext context, String qrCodeData, String workshopTitle) async {
    try {
      debugPrint('DEBUG: Starting save QR code for $workshopTitle');
      debugPrint('DEBUG: QR code data is null: ${qrCodeData == null}');
      debugPrint('DEBUG: QR code data length: ${qrCodeData.length}');
      final bytes = _getQRCodeBytes(qrCodeData);
      if (bytes == null) {
        debugPrint('DEBUG: Failed to get QR code bytes');
        _showSnackBar(context, 'Failed to process QR code', isError: true);
        return;
      }

      debugPrint('DEBUG: QR code bytes length: ${bytes.length}');
      final fileName = 'qr_code_${workshopTitle.replaceAll(' ', '_')}.png';
      debugPrint('DEBUG: Saving with filename: $fileName');

      final result = await ImageGallerySaver.saveImage(bytes, name: fileName);
      debugPrint('DEBUG: ImageGallerySaver result: $result');

      if (result['isSuccess'] == true) {
        _showSnackBar(context, 'QR code saved to gallery!');
      } else {
        final errorMsg = result['errorMessage'] ?? 'Unknown error';
        debugPrint('DEBUG: Save failed: $errorMsg');
        _showSnackBar(context, 'Failed to save QR code: $errorMsg', isError: true);
      }
    } catch (e) {
      debugPrint('DEBUG: Save QR code error: $e');
      _showSnackBar(context, 'Failed to save QR code: $e', isError: true);
    }
  }

  // Share QR code
  Future<void> _shareQRCode(BuildContext context, String qrCodeData, String workshopTitle) async {
    try {
      debugPrint('DEBUG: Starting share QR code for $workshopTitle');
      debugPrint('DEBUG: QR code data is null: ${qrCodeData == null}');
      debugPrint('DEBUG: QR code data length: ${qrCodeData.length}');
      final bytes = _getQRCodeBytes(qrCodeData);
      if (bytes == null) {
        debugPrint('DEBUG: Failed to get QR code bytes for sharing');
        _showSnackBar(context, 'Failed to process QR code', isError: true);
        return;
      }

      debugPrint('DEBUG: Creating temporary file for sharing');
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'qr_code_${workshopTitle.replaceAll(' ', '_')}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      debugPrint('DEBUG: Temporary file created: ${file.path}');
      debugPrint('DEBUG: File exists: ${await file.exists()}');

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code for $workshopTitle - Nachna Workshop',
        subject: 'Workshop QR Code',
        sharePositionOrigin: Rect.fromCenter(
          center: MediaQuery.of(context).size.center(Offset.zero),
          width: 100,
          height: 100,
        ),
      );

      debugPrint('DEBUG: Share completed successfully');
    } catch (e) {
      debugPrint('DEBUG: Share QR code error: $e');
      _showSnackBar(context, 'Failed to share QR code: $e', isError: true);
    }
  }

  // Show snackbar
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showFullscreen(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => QRCodeDisplay(
        order: order,
        isFullscreen: true,
      ),
    );
  }
}
