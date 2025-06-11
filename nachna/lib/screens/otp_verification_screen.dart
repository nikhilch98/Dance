import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String mobileNumber;

  const OTPVerificationScreen({
    super.key,
    required this.mobileNumber,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = 
      List.generate(6, (_) => FocusNode());
  
  bool _isVerifying = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();

    // Auto focus on first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0F),
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: screenHeight * 0.08),
                                _buildHeader(screenHeight, screenWidth),
                                SizedBox(height: screenHeight * 0.06),
                                _buildOTPFields(screenHeight, screenWidth),
                                SizedBox(height: screenHeight * 0.04),
                                _buildVerifyButton(screenHeight, screenWidth),
                                SizedBox(height: screenHeight * 0.03),
                                _buildResendOption(screenHeight, screenWidth),
                                SizedBox(height: screenHeight * 0.02),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double screenHeight, double screenWidth) {
    final iconSize = screenWidth * 0.15;
    final clampedIconSize = iconSize.clamp(50.0, 80.0);
    final titleSize = screenWidth * 0.06;
    final clampedTitleSize = titleSize.clamp(22.0, 28.0);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Column(
        children: [
          // Back Button
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenHeight * 0.03),
          
          // Logo/Icon
          Container(
            width: clampedIconSize,
            height: clampedIconSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(clampedIconSize * 0.25),
              gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              Icons.sms_outlined,
              size: clampedIconSize * 0.5,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.025),
          
          // Title
          Text(
            'Enter Verification Code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: clampedTitleSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.01),
          
          // Subtitle
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
                color: Colors.white.withOpacity(0.7),
              ),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to\n'),
                TextSpan(
                  text: '+91 ${widget.mobileNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00D4FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPFields(double screenHeight, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return Container(
            width: screenWidth * 0.12,
            height: screenWidth * 0.12,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: _focusNodes[index].hasFocus
                    ? const Color(0xFF00D4FF)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        // Move to next field
                        if (index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else {
                          // Last field, dismiss keyboard
                          FocusScope.of(context).unfocus();
                        }
                      }
                    },
                    onTap: () {
                      // Clear field when tapped
                      _otpControllers[index].clear();
                    },
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVerifyButton(double screenHeight, double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final isLoading = _isVerifying || authProvider.isLoading;
          final isComplete = _otpControllers.every((controller) => controller.text.isNotEmpty);
          
          return Container(
            width: double.infinity,
            height: screenHeight * 0.07,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: (!isComplete || isLoading)
                  ? LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.5),
                        Colors.grey.withOpacity(0.3),
                      ],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                    ),
              boxShadow: (!isComplete || isLoading)
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: (!isComplete || isLoading) ? null : _verifyOTP,
                child: Container(
                  alignment: Alignment.center,
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Verify & Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (screenWidth * 0.045).clamp(16.0, 18.0),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResendOption(double screenHeight, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Didn't receive the code? ",
            style: TextStyle(
              fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          GestureDetector(
            onTap: _resendOTP,
            child: Text(
              'Resend',
              style: TextStyle(
                fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
                color: const Color(0xFF00D4FF),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF00D4FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _verifyOTP() async {
    final otp = _otpControllers.map((controller) => controller.text).join();
    
    if (otp.length != 6) {
      _showErrorMessage('Please enter complete 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyOTPAndLogin(
      mobileNumber: widget.mobileNumber,
      otp: otp,
    );
    
    setState(() {
      _isVerifying = false;
    });

    if (success) {
      // Navigate to main app
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MyApp()),
        (route) => false,
      );
    } else {
      _showErrorMessage(authProvider.errorMessage ?? 'OTP verification failed');
      _clearOTPFields();
    }
  }

  void _resendOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOTP(mobileNumber: widget.mobileNumber);
    
    if (success) {
      _showSuccessMessage('OTP sent successfully');
      _clearOTPFields();
      _focusNodes[0].requestFocus();
    } else {
      _showErrorMessage(authProvider.errorMessage ?? 'Failed to resend OTP');
    }
  }

  void _clearOTPFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 