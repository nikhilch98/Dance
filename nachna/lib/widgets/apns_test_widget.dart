import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import '../services/notification_service.dart';

class APNsTestWidget extends StatefulWidget {
  const APNsTestWidget({Key? key}) : super(key: key);

  @override
  State<APNsTestWidget> createState() => _APNsTestWidgetState();
}

class _APNsTestWidgetState extends State<APNsTestWidget> {
  String? _deviceToken;
  String _status = 'Not initialized';
  bool _isLoading = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _getDeviceToken();
  }

  Future<void> _getDeviceToken() async {
    setState(() {
      _status = 'Getting device token...';
      _isLoading = true;
    });

    try {
      if (Platform.isIOS) {
        final token = _notificationService.deviceToken;
        
        if (token != null) {
          setState(() {
            _deviceToken = token;
            _status = 'Device token obtained successfully';
            _isLoading = false;
          });
        } else {
          // Try to initialize if not already done
          final newToken = await _notificationService.initialize();
          
          setState(() {
            _deviceToken = newToken;
            _status = newToken != null 
              ? 'Device token obtained successfully' 
              : 'Failed to get device token';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _status = 'APNs testing only available on iOS';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyTokenToClipboard() async {
    if (_deviceToken != null) {
      await Clipboard.setData(ClipboardData(text: _deviceToken!));
      _showSnackBar('Device token copied to clipboard');
    }
  }

  Future<void> _sendTestNotification() async {
    if (_deviceToken == null) {
      _showSnackBar('No device token available');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Sending test notification...';
    });

    try {
      final success = await _notificationService.sendTestNotification(
        title: 'Nachna Test',
        body: 'This is a test notification from the Nachna app! 🎉',
      );
      
      setState(() {
        _status = success 
          ? 'Test notification sent! Check your device.' 
          : 'Failed to send test notification';
        _isLoading = false;
      });
      
      _showSnackBar(success 
        ? 'Test notification sent successfully' 
        : 'Failed to send test notification');
    } catch (e) {
      setState(() {
        _status = 'Error sending notification: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00D4FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'APNs Testing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        Icon(
                          _status.contains('Error') ? Icons.error : Icons.info,
                          color: _status.contains('Error') 
                            ? Colors.red 
                            : const Color(0xFF00D4FF),
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Device Token
                if (_deviceToken != null) ...[
                  const Text(
                    'Device Token:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _copyTokenToClipboard,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_deviceToken!.substring(0, 20)}...${_deviceToken!.substring(_deviceToken!.length - 10)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.copy,
                            color: Color(0xFF00D4FF),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _getDeviceToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8338EC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Refresh Token',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendTestNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Send Test',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Testing Instructions:',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Copy device token using the button above\n'
                        '2. Use this token in the Python test script\n'
                        '3. Send test notifications via admin panel\n'
                        '4. Check device notification center for results',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 