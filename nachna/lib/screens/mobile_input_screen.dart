import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive_utils.dart';
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
                                SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                                _buildHeader(screenHeight, screenWidth),
                                SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                                _buildForm(screenHeight, screenWidth),
                                SizedBox(height: ResponsiveUtils.spacingMedium(context)),
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
    return Container(
      padding: ResponsiveUtils.paddingLarge(context),
      child: Column(
        children: [
          // Logo/Icon
          Container(
            width: ResponsiveUtils.avatarSizeLarge(context),
            height: ResponsiveUtils.avatarSizeLarge(context),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
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
              size: ResponsiveUtils.iconXLarge(context),
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          
          // Title
          Text(
            'Welcome to Nachna',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ResponsiveUtils.h1(context),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          
          // Subtitle
          Text(
            'Enter your mobile number to get started\nWe\'ll send you a secure verification code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ResponsiveUtils.body2(context),
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(double screenHeight, double screenWidth) {
    return Container(
      margin: ResponsiveUtils.paddingLarge(context),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Mobile Number Field
            _buildMobileField(screenHeight, screenWidth),
            
            SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
            
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
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: ResponsiveUtils.borderWidthMedium(context),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: ResponsiveUtils.paddingMedium(context),
            child: Row(
              children: [
                // Country Code
                Container(
                  padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingSmall(context)),
                  child: Row(
                    children: [
                      Text(
                        '🇮🇳',
                        style: TextStyle(fontSize: ResponsiveUtils.body1(context)),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                      Text(
                        '+91',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.body1(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                      Container(
                        width: ResponsiveUtils.borderWidthThin(context),
                        height: ResponsiveUtils.iconMedium(context),
                        color: Colors.white.withOpacity(0.3),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingMedium(context)),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.body1(context),
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendOTP(),
                    decoration: InputDecoration(
                      hintText: 'Mobile Number',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: ResponsiveUtils.body1(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.spacingSmall(context),
                      ),
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
                    onChanged: (value) {
                      // Trigger rebuild to update button state
                      setState(() {});
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
        // More robust loading state detection
        final isLoading = _isSendingOTP || 
            (authProvider.isLoading && authProvider.state == AuthState.loading);
        final isFormValid = _mobileController.text.length == 10;
        
        // Debug logging
        print('[MobileInput Button] Local loading: $_isSendingOTP, '
              'AuthProvider loading: ${authProvider.isLoading}, '
              'AuthProvider state: ${authProvider.state}, '
              'Combined loading: $isLoading, '
              'Form valid: $isFormValid');
        
        return Container(
          width: double.infinity,
          height: ResponsiveUtils.buttonHeight(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
            gradient: (isLoading || !isFormValid)
                ? LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.5),
                      Colors.grey.withOpacity(0.3),
                    ],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                  ),
            boxShadow: (isLoading || !isFormValid)
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
              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
              onTap: (isLoading || !isFormValid) ? null : _sendOTP,
              child: Container(
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: ResponsiveUtils.iconMedium(context),
                        height: ResponsiveUtils.iconMedium(context),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.body1(context),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _sendOTP() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Prevent multiple calls
    if (_isSendingOTP) {
      return;
    }

    // Clear any previous errors from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Set local loading state
    setState(() {
      _isSendingOTP = true;
    });

    final mobileNumber = _mobileController.text.trim();
    
    try {
      print('[MobileInput] Sending OTP to: $mobileNumber');
      
      // Call the API and wait for response
      final success = await authProvider.sendOTP(mobileNumber: mobileNumber);
      
      print('[MobileInput] OTP API response - Success: $success');
      print('[MobileInput] AuthProvider loading state: ${authProvider.isLoading}');
      print('[MobileInput] AuthProvider error: ${authProvider.errorMessage}');
      
      if (mounted) {
        if (success) {
          print('[MobileInput] OTP sent successfully, preparing to navigate...');
          
          // Reset local loading state BEFORE navigation
          setState(() {
            _isSendingOTP = false;
          });
          
          // Give UI a moment to update the button state
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            print('[MobileInput] Navigating to verification screen');
            // Navigate to OTP verification screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  mobileNumber: mobileNumber,
                ),
              ),
            );
          }
        } else {
          print('[MobileInput] OTP sending failed: ${authProvider.errorMessage}');
          
          // Reset local loading state on failure
          setState(() {
            _isSendingOTP = false;
          });
          
          // Show error message
          _showErrorMessage(
            authProvider.errorMessage ?? 'Failed to send OTP. Please try again.'
          );
        }
      }
    } catch (e) {
      print('[MobileInput] Exception during OTP sending: $e');
      
      // Always ensure loading state is reset when exception occurs
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
        
        // Show error message for any uncaught exceptions
        _showErrorMessage(
          'An error occurred while sending OTP. Please check your connection and try again.'
        );
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
} 