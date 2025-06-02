import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';

class APNsTestWidget extends StatefulWidget {
  const APNsTestWidget({Key? key}) : super(key: key);

  @override
  State<APNsTestWidget> createState() => _APNsTestWidgetState();
}

class _APNsTestWidgetState extends State<APNsTestWidget> {
  String? _deviceToken;
  String _status = 'Not initialized';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    setState(() {
      _status = 'Initializing...';
      _isLoading = true;
    });

    try {
      if (Platform.isIOS) {
        // Initialize Firebase Messaging or APNs
        // For now, simulate getting a device token
        await Future.delayed(const Duration(seconds: 1));
        
        // In a real app, you would get the actual device token like this:
        // final messaging = FirebaseMessaging.instance;
        // final token = await messaging.getToken();
        
        // For testing, generate a dummy token
        final dummyToken = 'a' * 64; // Real tokens are 64 hex characters
        
        setState(() {
          _deviceToken = dummyToken;
          _status = 'Device token obtained (dummy for testing)';
          _isLoading = false;
        });
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

  Future<void> _testNotificationPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking notification permissions...';
    });

    try {
      if (Platform.isIOS) {
        // In a real app:
        // final messaging = FirebaseMessaging.instance;
        // final settings = await messaging.requestPermission(
        //   alert: true,
        //   announcement: false,
        //   badge: true,
        //   carPlay: false,
        //   criticalAlert: false,
        //   provisional: false,
        //   sound: true,
        // );
        
        // For testing, simulate permission check
        await Future.delayed(const Duration(seconds: 1));
        
        setState(() {
          _status = 'Notification permissions: Authorized (simulated)';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Permission error: ${e.toString()}';
        _isLoading = false;
      });
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
      // Here you would call your server's test notification endpoint
      // For example:
      // final response = await http.post(
      //   Uri.parse('https://nachna.com/api/admin/api/test-apns'),
      //   headers: {
      //     'Authorization': 'Bearer ${your_auth_token}',
      //     'Content-Type': 'application/json',
      //   },
      //   body: json.encode({
      //     'device_token': _deviceToken,
      //     'title': 'Test Notification',
      //     'body': 'This is a test from the Nachna app!',
      //   }),
      // );

      // For testing, simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _status = 'Test notification sent! Check your device.';
        _isLoading = false;
      });
      
      _showSnackBar('Test notification request sent');
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
                        onPressed: _isLoading ? null : _testNotificationPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8338EC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Check Permissions',
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
                        '1. Copy device token and send to your backend team\n'
                        '2. Ensure APNs credentials are configured\n'
                        '3. Use admin endpoint to send test notifications\n'
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