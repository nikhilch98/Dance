import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
              
              // QR Code content
              Expanded(
                child: Center(
                  child: _buildQRCodeContent(context, isFullscreen: true),
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
      return _buildQRCodeUnavailable(context, isFullscreen);
    }

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

  Widget _buildQRCodeUnavailable(BuildContext context, bool isFullscreen) {
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
