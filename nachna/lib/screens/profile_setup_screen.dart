import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

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
  
  bool _isUploadingImage = false;
  String? _profilePictureUrl;
  final ImagePicker _picker = ImagePicker();
  
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
      
      if (user.profilePictureUrl != null) {
        _profilePictureUrl = user.profilePictureUrl;
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
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
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
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
              ),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height - 
                                     MediaQuery.of(context).padding.top - 
                                     MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                              children: [
                                // Header
                                _buildHeader(screenHeight, screenWidth),
                                
                                // Profile Picture Section
                                _buildProfilePictureSection(screenHeight, screenWidth),
                                
                                // Profile Form (no longer expanded)
                                _buildForm(screenHeight, screenWidth),
                                
                                // Moderate spacing between form and buttons
                                SizedBox(height: screenHeight * 0.03),
                                
                                // Skip/Complete Button
                                _buildActionButtons(screenHeight, screenWidth),
                              ],
                            ),
                          ),
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
    final topPadding = screenHeight * 0.015; // Reduced from 0.025
    final titleSize = screenWidth * 0.055; // Reduced from 0.065
    final clampedTitleSize = titleSize.clamp(18.0, 24.0); // Reduced sizes
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.06, // 6% horizontal padding
        topPadding,
        screenWidth * 0.06,
        screenHeight * 0.01, // Reduced from 0.015
      ),
      child: Column(
        children: [
          SizedBox(height: screenHeight * 0.02),
          
          // Title
          Text(
            'Complete Your\nProfile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: clampedTitleSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1, // Reduced from 1.2
            ),
          ),
          
          SizedBox(height: screenHeight * 0.01),
          
          // Subtitle
          Text(
            'Help us personalize your dance experience',
            style: TextStyle(
              fontSize: (screenWidth * 0.032).clamp(11.0, 13.0), // Reduced from 0.037
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection(double screenHeight, double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.045),
      padding: EdgeInsets.all(screenWidth * 0.025), // Reduced from 0.035
      child: Column(
        children: [
          // Profile Picture
          Stack(
            children: [
              Container(
                width: screenWidth * 0.2, // Reduced from 0.22
                height: screenWidth * 0.2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(screenWidth * 0.1),
                  gradient: _profilePictureUrl == null
                      ? const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _profilePictureUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(screenWidth * 0.1),
                        child: Image.network(
                          'https://nachna.com$_profilePictureUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(screenWidth);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildDefaultAvatar(screenWidth);
                          },
                        ),
                      )
                    : _buildDefaultAvatar(screenWidth),
              ),
              
              // Upload/Edit Button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _showImagePickerDialog,
                  child: Container(
                    width: screenWidth * 0.07, // Reduced from 0.08
                    height: screenWidth * 0.07,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF),
                      borderRadius: BorderRadius.circular(screenWidth * 0.035),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isUploadingImage
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: screenWidth * 0.035, // Reduced from 0.04
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenHeight * 0.01), // Reduced from 0.015
          
          // Profile Picture Label
          Text(
            'Add Profile Picture',
            style: TextStyle(
              fontSize: (screenWidth * 0.035).clamp(12.0, 14.0), // Reduced from 0.04
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          
          Text(
            '(Optional)',
            style: TextStyle(
              fontSize: (screenWidth * 0.028).clamp(10.0, 12.0), // Reduced from 0.032
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(double screenWidth) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(screenWidth * 0.125),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
        ),
      ),
      child: Center(
        child: Text(
          user?.name?.isNotEmpty == true 
              ? user!.name!.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: screenWidth * 0.08, // 8% of screen width
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(double screenHeight, double screenWidth) {
    final horizontalPadding = screenWidth * 0.045; // 4.5% of screen width
    final fieldSpacing = screenHeight * 0.012; // Reduced from 0.015
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.03), // Reduced from 0.035
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
                      fontSize: (screenWidth * 0.042).clamp(15.0, 18.0), // Reduced from 0.048
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: screenHeight * 0.015), // Reduced from 0.02
                  
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
                  
                  SizedBox(height: screenHeight * 0.015), // Reduced from 0.02
                  
                  // Error Message
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.errorMessage != null) {
                        return Container(
                          padding: EdgeInsets.all(screenWidth * 0.02), // Reduced from 0.025
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
                              fontSize: (screenWidth * 0.03).clamp(10.0, 12.0), // Reduced from 0.032
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
          vertical: screenHeight * 0.012, // Reduced from 0.015
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
        errorMaxLines: 2,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: (screenWidth * 0.03).clamp(11.0, 12.0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      mainAxisSize: MainAxisSize.min,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Wrap(
          spacing: screenWidth * 0.025,
          runSpacing: screenHeight * 0.01,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.035, // Left
        screenWidth * 0.025, // Top - reduced
        screenWidth * 0.035, // Right
        screenWidth * 0.015, // Bottom - reduced to minimal
      ),
      child: Row(
        children: [
          // Skip Button
          Expanded(
            child: Container(
              height: screenHeight * 0.055, // Reduced from 0.06
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
                        fontSize: (screenWidth * 0.034).clamp(12.0, 14.0), // Reduced from 0.037
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
                  height: screenHeight * 0.055, // Reduced from 0.06
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
                                  fontSize: (screenWidth * 0.034).clamp(12.0, 14.0), // Reduced from 0.037
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

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Profile Picture',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildImagePickerOption(
                          'Camera',
                          Icons.camera_alt_rounded,
                          const Color(0xFF3B82F6),
                          () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildImagePickerOption(
                          'Gallery',
                          Icons.photo_library_rounded,
                          const Color(0xFF10B981),
                          () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  if (_profilePictureUrl != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildImagePickerOption(
                        'Remove Picture',
                        Icons.delete_rounded,
                        const Color(0xFFFF006E),
                        () => _removeProfilePicture(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerOption(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        await _uploadProfilePicture(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _uploadProfilePicture(File imageFile) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageUrl = await AuthService.uploadProfilePicture(imageFile);
      
      setState(() {
        _profilePictureUrl = imageUrl;
      });
      
      _showSuccessSnackBar('Profile picture uploaded successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to upload profile picture: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _removeProfilePicture() async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      await AuthService.removeProfilePicture();
      
      setState(() {
        _profilePictureUrl = null;
      });
      
      _showSuccessSnackBar('Profile picture removed successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to remove profile picture: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 