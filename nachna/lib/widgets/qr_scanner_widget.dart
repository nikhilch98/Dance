import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../models/qr_verification.dart';
import '../services/admin_service.dart';

class QRScannerWidget extends StatefulWidget {
  const QRScannerWidget({Key? key}) : super(key: key);

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  Barcode? result;
  bool _isScanning = true;
  bool _isVerifying = false;
  QRVerificationResponse? _verificationResult;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0A0F),
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // QR Scanner Area with Controls
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      // Camera View
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GestureDetector(
                            onLongPress: () async {
                              // Long press to focus camera
                              await controller?.pauseCamera();
                              await Future.delayed(const Duration(milliseconds: 200));
                              await controller?.resumeCamera();
                              _showFocusIndicator();
                            },
                            child: QRView(
                              key: qrKey,
                              onQRViewCreated: _onQRViewCreated,
                              overlay: QrScannerOverlayShape(
                                borderColor: const Color(0xFF00D4FF),
                                borderRadius: 16,
                                borderLength: 50,
                                borderWidth: 8,
                                cutOutSize: MediaQuery.of(context).size.width * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Compact Control Buttons on the Right
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Column(
                          children: [
                            _buildCompactControlButton(
                              icon: Icons.flash_on,
                              onPressed: () async {
                                await controller?.toggleFlash();
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildCompactControlButton(
                              icon: _isScanning ? Icons.pause : Icons.play_arrow,
                              onPressed: _toggleScanning,
                            ),
                            const SizedBox(height: 12),
                            _buildCompactControlButton(
                              icon: Icons.flip_camera_ios,
                              onPressed: () async {
                                await controller?.flipCamera();
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Instructions overlay at bottom
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Long press camera to focus • Point at QR code',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Results Area - Fixed Height
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [                    
                      // Verification Status
                      if (_isVerifying)
                        _buildVerificationLoading()
                      else if (_verificationResult != null)
                        _buildVerificationResult()
                      else
                        _buildScanningInstructions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.6),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
      ),
    );
  }

  void _showFocusIndicator() {
    // Show a brief focus indicator animation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.center_focus_strong,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Camera focused',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00D4FF),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            Icon(
              icon,
              color: const Color(0xFF00D4FF),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner,
            color: const Color(0xFF00D4FF),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan Nachna QR Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Position the QR code within the scan area to verify registration',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(
            'Verifying QR Code...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationResult() {
    final result = _verificationResult!;
    final isValid = result.valid;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isValid 
            ? [
                Colors.green.withOpacity(0.2),
                Colors.green.withOpacity(0.1),
              ]
            : [
                Colors.red.withOpacity(0.2),
                Colors.red.withOpacity(0.1),
              ],
        ),
        border: Border.all(
          color: isValid 
            ? Colors.green.withOpacity(0.3)
            : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.verified : Icons.error,
                color: isValid ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isValid ? 'Valid Registration' : 'Invalid QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (isValid && result.registrationData != null)
            ..._buildRegistrationDetails(result.registrationData!)
          else if (!isValid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                result.error ?? 'Unknown error',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 14,
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Scan Another'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRegistrationDetails(RegistrationData data) {
    return [
      const SizedBox(height: 16),
      _buildDetailRow('Order ID', data.formattedOrderId),
      _buildDetailRow('User', data.registration.userName),
      _buildDetailRow('Phone', data.registration.maskedPhone),
      _buildDetailRow('Workshop', data.workshop.title),
      _buildDetailRow('Artist(s)', data.workshop.artistNames),
      _buildDetailRow('Studio', data.workshop.studio),
      _buildDetailRow('Date', data.workshop.date),
      _buildDetailRow('Time', data.workshop.time),
      _buildDetailRow('Amount', data.registration.formattedAmount),
      if (data.payment?.transactionId != null)
        _buildDetailRow('Transaction', data.payment!.transactionId),
      _buildDetailRow('Valid Until', data.verification.timeRemaining),
    ];
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
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_isScanning && !_isVerifying && scanData.code != null) {
        _verifyQRCode(scanData.code!);
      }
    });
  }

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
    });
    
    if (_isScanning) {
      controller?.resumeCamera();
    } else {
      controller?.pauseCamera();
    }
  }

  void _verifyQRCode(String qrData) async {
    setState(() {
      _isVerifying = true;
      _isScanning = false;
      _verificationResult = null;
    });

    try {
      final result = await AdminService.verifyQRCode(qrData);
      setState(() {
        _verificationResult = result;
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _verificationResult = QRVerificationResponse(
          valid: false,
          error: 'Verification failed: ${e.toString()}',
        );
        _isVerifying = false;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _verificationResult = null;
      _isScanning = true;
    });
    controller?.resumeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
