import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import './otp_verification_screen.dart';

class MobileInputScreen extends StatefulWidget {
  const MobileInputScreen({super.key});

  @override
  State<MobileInputScreen> createState() => _MobileInputScreenState();
}

class _MobileInputScreenState extends State<MobileInputScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  
  bool _isSendingOTP = false;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mobileController.dispose();
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
                                SizedBox(height: screenHeight * 0.12),
                                _buildHeader(screenHeight, screenWidth),
                                SizedBox(height: screenHeight * 0.08),
                                _buildForm(screenHeight, screenWidth),
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
              Icons.phone_android,
              size: clampedIconSize * 0.5,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.025),
          
          // Title
          Text(
            'Welcome to Nachna',
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
          Text(
            'Enter your mobile number to get started\nWe\'ll send you a secure verification code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(double screenHeight, double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Mobile Number Field
            _buildMobileField(screenHeight, screenWidth),
            
            SizedBox(height: screenHeight * 0.04),
            
            // Send OTP Button
            _buildSendOTPButton(screenHeight, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileField(double screenHeight, double screenWidth) {
    return Container(
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
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Country Code
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      const Text(
                        '🇮🇳',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '+91',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                
                // Mobile Number Input
                Expanded(
                  child: TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendOTP(),
                    decoration: InputDecoration(
                      hintText: 'Mobile Number',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter mobile number';
                      }
                      if (value.length != 10) {
                        return 'Please enter valid 10-digit mobile number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendOTPButton(double screenHeight, double screenWidth) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isLoading = _isSendingOTP || authProvider.isLoading;
        
        return Container(
          width: double.infinity,
          height: screenHeight * 0.07,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isLoading
                ? LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.5),
                      Colors.grey.withOpacity(0.3),
                    ],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                  ),
            boxShadow: isLoading
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
              onTap: isLoading ? null : _sendOTP,
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
                        'Continue',
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
    );
  }

  void _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSendingOTP) return; // Prevent multiple calls

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingOTP = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mobileNumber = _mobileController.text.trim();
    
    try {
      final success = await authProvider.sendOTP(mobileNumber: mobileNumber);
      
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });

        if (success) {
          // Navigate to OTP verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                mobileNumber: mobileNumber,
              ),
            ),
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authProvider.errorMessage ?? 'Failed to send OTP',
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }
} 