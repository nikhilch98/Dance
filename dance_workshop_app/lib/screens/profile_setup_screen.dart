import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  String? _dateOfBirth;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _genderOptions = ['male', 'female', 'other'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    
    // Pre-fill with existing data if available
    _loadExistingData();
  }

  void _loadExistingData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      if (user.name != null) {
        _nameController.text = user.name!;
      }
      
      if (user.gender != null) {
        _selectedGender = user.gender;
      }
      
      if (user.dateOfBirth != null) {
        _dateOfBirth = user.dateOfBirth;
        try {
          _selectedDate = DateTime.parse(user.dateOfBirth!);
        } catch (e) {
          // Invalid date format, keep null
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation during profile setup
        return false;
      },
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
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
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  children: [
                                    // Header
                                    _buildHeader(screenHeight, screenWidth),
                                    
                                    // Profile Form
                                    Expanded(
                                      child: _buildForm(screenHeight, screenWidth),
                                    ),
                                    
                                    // Skip/Complete Button
                                    _buildActionButtons(screenHeight, screenWidth),
                                    
                                    SizedBox(height: screenHeight * 0.015), // 1.5% of screen height
                                  ],
                                ),
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
      ),
    );
  }

  Widget _buildHeader(double screenHeight, double screenWidth) {
    final topPadding = screenHeight * 0.025; // 2.5% of screen height
    final iconSize = screenWidth * 0.16; // 16% of screen width
    final clampedIconSize = iconSize.clamp(60.0, 85.0);
    final titleSize = screenWidth * 0.065; // 6.5% of screen width
    final clampedTitleSize = titleSize.clamp(22.0, 30.0);
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.06, // 6% horizontal padding
        topPadding,
        screenWidth * 0.06,
        screenHeight * 0.015, // 1.5% bottom padding
      ),
      child: Column(
        children: [
          // Progress Indicator
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
              Icons.person_outline,
              size: clampedIconSize * 0.5,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.02), // 2% of screen height
          
          // Title
          Text(
            'Complete Your\nProfile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: clampedTitleSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.008), // 0.8% of screen height
          
          // Subtitle
          Text(
            'Help us personalize your dance experience',
            style: TextStyle(
              fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(double screenHeight, double screenWidth) {
    final horizontalPadding = screenWidth * 0.045; // 4.5% of screen width
    final fieldSpacing = screenHeight * 0.022; // 2.2% of screen height
    
    return SingleChildScrollView(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.045), // 4.5% padding
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tell us about yourself',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.05).clamp(18.0, 22.0),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.025), // 2.5% of screen height
                    
                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person,
                      screenHeight: screenHeight,
                      screenWidth: screenWidth,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: fieldSpacing),
                    
                    // Date of Birth Field
                    _buildDateField(screenHeight, screenWidth),
                    
                    SizedBox(height: fieldSpacing),
                    
                    // Gender Field
                    _buildGenderField(screenHeight, screenWidth),
                    
                    SizedBox(height: screenHeight * 0.025), // 2.5% of screen height
                    
                    // Error Message
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        if (authProvider.errorMessage != null) {
                          return Container(
                            padding: EdgeInsets.all(screenWidth * 0.025),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              authProvider.errorMessage!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: (screenWidth * 0.032).clamp(11.0, 13.0),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      textInputAction: TextInputAction.done, // Add done button to keyboard
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(), // Dismiss keyboard on done
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.015,
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

  Widget _buildDateField(double screenHeight, double screenWidth) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.018,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF00D4FF)),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: (screenWidth * 0.03).clamp(11.0, 12.0),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    _dateOfBirth ?? 'Select your birth date',
                    style: TextStyle(
                      color: _dateOfBirth != null 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderField(double screenHeight, double screenWidth) {
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: screenWidth * 0.04,
      vertical: screenHeight * 0.012,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.03, bottom: screenHeight * 0.01),
          child: Text(
            'Gender',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: (screenWidth * 0.04).clamp(14.0, 16.0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Wrap(
          spacing: screenWidth * 0.025,
          children: _genderOptions.map((gender) {
            final isSelected = _selectedGender == gender;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGender = gender;
                });
              },
              child: Container(
                padding: buttonPadding,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent 
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  gender.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (screenWidth * 0.032).clamp(12.0, 14.0),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(double screenHeight, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.045),
      child: Row(
        children: [
          // Skip Button
          Expanded(
            child: Container(
              height: screenHeight * 0.06, // 6% of screen height
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _handleSkip,
                  child: Center(
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(width: screenWidth * 0.04),
          
          // Complete Button
          Expanded(
            flex: 2,
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Container(
                  height: screenHeight * 0.06, // 6% of screen height
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
                      onTap: authProvider.isLoading ? null : _handleComplete,
                      child: Center(
                        child: authProvider.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              )
                            : Text(
                                'Complete Profile',
                                style: TextStyle(
                                  fontSize: (screenWidth * 0.037).clamp(13.0, 15.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectDate() {
    picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(1900, 1, 1),
      maxTime: DateTime.now().subtract(const Duration(days: 365 * 13)), // At least 13 years old
      currentTime: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      theme: picker.DatePickerTheme(
        backgroundColor: const Color(0xFF1A1A2E),
        itemStyle: const TextStyle(color: Colors.white),
        doneStyle: const TextStyle(color: Color(0xFF00D4FF)),
        cancelStyle: const TextStyle(color: Colors.grey),
      ),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
          _dateOfBirth = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        });
      },
    );
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      _showErrorSnackBar('Please select your date of birth');
      return;
    }

    if (_selectedGender == null) {
      _showErrorSnackBar('Please select your gender');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.updateProfile(
      name: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _selectedGender,
    );

    if (success && mounted) {
      // Profile completed, navigate to main app
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _handleSkip() async {
    // Navigate to main app even with incomplete profile
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
} 