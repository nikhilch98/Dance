import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode(); // Add focus node for password field
  
  bool _obscurePassword = true;
  bool _isLoggingIn = false; // Local loading state to prevent UI refresh
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Simplified animation controller with shorter duration for better performance
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced from 1500ms
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
      begin: const Offset(0, 0.1), // Reduced from 0.3 to 0.1 for smoother performance
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
    _passwordController.dispose();
    _passwordFocusNode.dispose(); // Dispose focus node
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    
    // Dynamic sizing based on screen dimensions
    final isCompactHeight = screenHeight < 700;
    final isWideScreen = screenWidth > 400;
    
    return Scaffold(
      body: GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping outside input fields
              FocusScope.of(context).unfocus();
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0A0F),
                    Color(0xFF1A1A2E),
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
                                    // Top spacing to position header higher
                                    SizedBox(height: screenHeight * 0.12),
                                    
                                    // Header
                                    _buildHeader(screenHeight, screenWidth),
                                    
                                    // Flexible space before form
                                    SizedBox(height: screenHeight * 0.06),
                                    
                                    // Login Form - centered
                                    _buildForm(screenHeight, screenWidth),
                                    
                                    // Spacing between form and register link
                                    SizedBox(height: screenHeight * 0.04),
                                    
                                    // Register Link
                                    _buildRegisterLink(screenHeight, screenWidth),
                                    
                                    // Bottom padding
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
    final topPadding = screenHeight * 0.02; // Reduced from 0.03 to 0.02
    final iconSize = screenWidth * 0.15; // Reduced from 0.18 to 0.15
    final clampedIconSize = iconSize.clamp(50.0, 80.0); // Reduced max from 100 to 80
    final titleSize = screenWidth * 0.06; // Reduced from 0.07 to 0.06
    final clampedTitleSize = titleSize.clamp(22.0, 28.0); // Reduced max from 32 to 28
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.06, // 6% horizontal padding
        topPadding,
        screenWidth * 0.06,
        screenHeight * 0.01, // Reduced from 0.02 to 0.01
      ),
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
                  blurRadius: 15, // Reduced from 20
                  spreadRadius: 3, // Reduced from 5
                ),
              ],
            ),
            child: Icon(
              Icons.login,
              size: clampedIconSize * 0.5,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.015), // Reduced from 0.025 to 0.015
          
          // Title
          Text(
            'Welcome Back\nDancer!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: clampedTitleSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1, // Reduced from 1.2 to 1.1
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(double screenHeight, double screenWidth) {
    final horizontalPadding = screenWidth * 0.05; // 5% of screen width
    final fieldSpacing = screenHeight * 0.015; // Reduced from 0.02 to 0.015
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Reduced from 10 to 5 for better performance
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.03), // Reduced from 0.04 to 0.03
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: (screenWidth * 0.05).clamp(18.0, 22.0), // Reduced from 0.055 and max 24 to 22
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: screenHeight * 0.015), // Reduced from 0.02 to 0.015
                  
                  // Mobile Number Field
                  _buildMobileNumberField(
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                  ),
                  
                  SizedBox(height: fieldSpacing),
                  
                  // Password Field
                  _buildPasswordField(
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                  ),
                  
                  SizedBox(height: fieldSpacing),
                  
                  // Login Button
                  _buildLoginButton(screenHeight, screenWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNumberField({
    required double screenHeight,
    required double screenWidth,
  }) {
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: (value) {
        if (value.length == 10) {
          // Auto-move to password field after 10 digits
          _passwordFocusNode.requestFocus();
        }
      },
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (value) {
        // Move to password field
        FocusScope.of(context).nextFocus();
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your mobile number';
        }
        if (!AuthService.isValidMobileNumber(value)) {
          return 'Please enter a valid 10-digit mobile number';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: '9876543210',
        prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF00D4FF)),
        counterText: '', // Hide the character counter
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.018,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required double screenHeight,
    required double screenWidth,
  }) {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode, // Use the focus node
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (value) {
        // Dismiss keyboard and attempt login
        FocusScope.of(context).unfocus();
        if (_formKey.currentState!.validate()) {
          _handleLogin();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00D4FF)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white.withOpacity(0.7),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.018,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required double screenHeight,
    required double screenWidth,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      textInputAction: keyboardType == TextInputType.phone 
          ? TextInputAction.next 
          : TextInputAction.done,
      onFieldSubmitted: (value) {
        if (keyboardType == TextInputType.phone) {
          // Move to password field
          FocusScope.of(context).nextFocus();
        } else {
          // Dismiss keyboard and attempt login
          FocusScope.of(context).unfocus();
          if (_formKey.currentState!.validate()) {
            _handleLogin();
          }
        }
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.018,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildLoginButton(double screenHeight, double screenWidth) {
    return Container(
      height: screenHeight * 0.065, // 6.5% of screen height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoggingIn ? null : _handleLogin,
          child: Center(
            child: _isLoggingIn
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  )
                : Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: (screenWidth * 0.045).clamp(16.0, 18.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }



  Widget _buildRegisterLink(double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Don\'t have an account? ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              authProvider.clearError(); // Clear any existing errors
              Navigator.of(context).pushReplacementNamed('/register');
            },
            child: Text(
              'Create Account',
              style: TextStyle(
                color: const Color(0xFF00D4FF),
                fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF00D4FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Set local loading state
    setState(() {
      _isLoggingIn = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    print('[LoginScreen] Clearing any previous errors...');
    authProvider.clearError();

    print('[LoginScreen] Starting login process...');
    
    final success = await authProvider.login(
      mobileNumber: AuthService.formatMobileNumber(_mobileController.text.trim()),
      password: _passwordController.text,
    );

    print('[LoginScreen] Login completed. Success: $success');
    print('[LoginScreen] Auth state: ${authProvider.state}');
    print('[LoginScreen] Error message: ${authProvider.errorMessage}');

    // Clear local loading state
    if (mounted) {
      setState(() {
        _isLoggingIn = false;
      });
    }

    if (success && mounted) {
      final authState = authProvider.state;
      
      if (authState == AuthState.authenticated) {
        // Profile is complete, go to main app
        Navigator.of(context).pushReplacementNamed('/home');
      } else if (authState == AuthState.profileIncomplete) {
        // Profile needs completion
        Navigator.of(context).pushReplacementNamed('/profile-setup');
      }
    } else if (!success && mounted) {
      // Show error popup immediately before any state changes
      final errorMsg = authProvider.errorMessage ?? 'Login failed. Please try again.';
      print('[LoginScreen] *** SHOULD SHOW ERROR POPUP ***');
      print('[LoginScreen] Success: $success, Mounted: $mounted');
      print('[LoginScreen] Error message: $errorMsg');
      
      _showErrorPopup(_cleanErrorMessage(errorMsg));
      print('[LoginScreen] _showErrorPopup called directly');
    } else {
      print('[LoginScreen] *** NO ERROR POPUP SHOWN ***');
      print('[LoginScreen] Success: $success, Mounted: $mounted');
      print('[LoginScreen] Conditions not met for showing error');
    }
  }

  String _cleanErrorMessage(String errorMessage) {
    // Remove "AuthException:" prefix if it exists
    if (errorMessage.startsWith('AuthException:')) {
      return errorMessage.substring('AuthException:'.length).trim();
    }
    return errorMessage;
  }



  void _showErrorPopup(String errorMessage) {
    print('[LoginScreen] _showErrorPopup called with message: $errorMessage');
    print('[LoginScreen] Context mounted: $mounted');
    print('[LoginScreen] Context: $context');
    
    if (!mounted) {
      print('[LoginScreen] Widget not mounted, skipping error popup');
      return;
    }
    
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    
    print('[LoginScreen] About to call showDialog...');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    
                    SizedBox(height: screenWidth * 0.04),
                    
                    // Error Title
                    Text(
                      'Login Failed',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.05).clamp(18.0, 22.0),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    SizedBox(height: screenWidth * 0.03),
                    
                    // Error Message
                    Text(
                      errorMessage,
                      style: TextStyle(
                        fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: screenWidth * 0.06),
                    
                    // Close Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Center(
                            child: Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 