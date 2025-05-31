import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import '../providers/auth_provider.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  String? _dateOfBirth;
  
  bool _isEditingProfile = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _genderOptions = ['male', 'female', 'other'];

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
    
    _animationController.forward();
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      _nameController.text = user.name ?? '';
      _selectedGender = user.gender;
      _dateOfBirth = user.dateOfBirth;
      
      if (user.dateOfBirth != null) {
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final isMediumScreen = screenSize.height >= 700 && screenSize.height < 800;
    
    return Scaffold(
      body: Container(
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                _buildHeader(isSmallScreen),
                
                // Profile Card
                Expanded(
                  child: _buildProfileCard(isSmallScreen, isMediumScreen),
                ),
                
                // Action Buttons
                _buildActionButtons(isSmallScreen),
                
                SizedBox(height: isSmallScreen ? 12 : 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              iconSize: isSmallScreen ? 20 : 24,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          // Settings/Edit Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: IconButton(
              icon: Icon(
                _isEditingProfile ? Icons.close : Icons.edit,
                color: const Color(0xFF00D4FF),
                size: isSmallScreen ? 20 : 24,
              ),
              onPressed: () {
                setState(() {
                  if (_isEditingProfile) {
                    _loadUserData(); // Reset changes
                  }
                  _isEditingProfile = !_isEditingProfile;
                  _isChangingPassword = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.user;
                if (user == null) {
                  return const Center(
                    child: Text(
                      'No user data available',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Avatar
                      _buildAvatar(user, isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      
                      // Profile Fields
                      if (_isEditingProfile) ...[
                        _buildEditableFields(isSmallScreen),
                      ] else ...[
                        _buildReadOnlyFields(user, isSmallScreen),
                      ],
                      
                      // Password Change Section
                      if (_isChangingPassword) ...[
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        _buildPasswordChangeSection(isSmallScreen),
                      ],
                      
                      // Error Message
                      if (authProvider.errorMessage != null) ...[
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
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
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User user, bool isSmallScreen) {
    final avatarSize = isSmallScreen ? 80.0 : 100.0;
    
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(avatarSize / 2),
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
      child: Center(
        child: Text(
          (user.name?.isNotEmpty == true) 
              ? user.name!.substring(0, 1).toUpperCase()
              : user.mobileNumber.substring(user.mobileNumber.length - 1),
          style: TextStyle(
            fontSize: isSmallScreen ? 32 : 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFields(User user, bool isSmallScreen) {
    final fieldSpacing = isSmallScreen ? 12.0 : 16.0;
    
    return Column(
      children: [
        _buildInfoCard(
          icon: Icons.person,
          label: 'Name',
          value: user.name ?? 'Not set',
          isComplete: user.name != null,
          isSmallScreen: isSmallScreen,
        ),
        
        SizedBox(height: fieldSpacing),
        
        _buildInfoCard(
          icon: Icons.phone,
          label: 'Mobile Number',
          value: user.mobileNumber,
          isComplete: true,
          isSmallScreen: isSmallScreen,
        ),
        
        SizedBox(height: fieldSpacing),
        
        _buildInfoCard(
          icon: Icons.cake,
          label: 'Date of Birth',
          value: user.dateOfBirth ?? 'Not set',
          isComplete: user.dateOfBirth != null,
          isSmallScreen: isSmallScreen,
        ),
        
        SizedBox(height: fieldSpacing),
        
        _buildInfoCard(
          icon: Icons.person_outline,
          label: 'Gender',
          value: user.gender?.toUpperCase() ?? 'Not set',
          isComplete: user.gender != null,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isComplete,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete 
              ? Colors.white.withOpacity(0.2)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isComplete ? const Color(0xFF00D4FF) : Colors.orange,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isComplete ? Colors.white : Colors.orange,
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isComplete)
            Icon(
              Icons.warning_rounded,
              color: Colors.orange,
              size: isSmallScreen ? 16 : 20,
            ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(bool isSmallScreen) {
    final fieldSpacing = isSmallScreen ? 14.0 : 18.0;
    
    return Column(
      children: [
        // Name Field
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person,
          isSmallScreen: isSmallScreen,
        ),
        
        SizedBox(height: fieldSpacing),
        
        // Date of Birth Field
        _buildDateField(isSmallScreen),
        
        SizedBox(height: fieldSpacing),
        
        // Gender Field
        _buildGenderField(isSmallScreen),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isSmallScreen,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: isSmallScreen ? 13 : 15,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: isSmallScreen ? 13 : 15,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isSmallScreen ? 10 : 14,
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
      ),
    );
  }

  Widget _buildDateField(bool isSmallScreen) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isSmallScreen ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF00D4FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: isSmallScreen ? 11 : 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateOfBirth ?? 'Select your birth date',
                    style: TextStyle(
                      color: _dateOfBirth != null 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.5),
                      fontSize: isSmallScreen ? 14 : 16,
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

  Widget _buildGenderField(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            'Gender',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Wrap(
          spacing: isSmallScreen ? 8 : 12,
          children: _genderOptions.map((gender) {
            final isSelected = _selectedGender == gender;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGender = gender;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: isSmallScreen ? 8 : 12,
                ),
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
                    fontSize: isSmallScreen ? 12 : 14,
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

  Widget _buildPasswordChangeSection(bool isSmallScreen) {
    final fieldSpacing = isSmallScreen ? 12.0 : 16.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: Colors.white24),
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        Text(
          'Change Password',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Current Password
        _buildTextField(
          controller: _currentPasswordController,
          label: 'Current Password',
          hint: 'Enter current password',
          icon: Icons.lock_outline,
          obscureText: _obscureCurrentPassword,
          isSmallScreen: isSmallScreen,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscureCurrentPassword = !_obscureCurrentPassword;
              });
            },
          ),
        ),
        
        SizedBox(height: fieldSpacing),
        
        // New Password
        _buildTextField(
          controller: _newPasswordController,
          label: 'New Password',
          hint: 'Enter new password',
          icon: Icons.lock,
          obscureText: _obscureNewPassword,
          isSmallScreen: isSmallScreen,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscureNewPassword = !_obscureNewPassword;
              });
            },
          ),
        ),
        
        SizedBox(height: fieldSpacing),
        
        // Confirm New Password
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          hint: 'Re-enter new password',
          icon: Icons.lock,
          obscureText: _obscureConfirmPassword,
          isSmallScreen: isSmallScreen,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.white.withOpacity(0.7),
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Column(
        children: [
          if (_isEditingProfile) ...[
            // Save Profile Button
            _buildGradientButton(
              text: 'Save Changes',
              onPressed: _handleSaveProfile,
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Change Password Toggle Button
            _buildOutlineButton(
              text: _isChangingPassword ? 'Cancel Password Change' : 'Change Password',
              onPressed: () {
                setState(() {
                  _isChangingPassword = !_isChangingPassword;
                  if (!_isChangingPassword) {
                    // Clear password fields
                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  }
                });
              },
              isSmallScreen: isSmallScreen,
            ),
            
            if (_isChangingPassword) ...[
              SizedBox(height: isSmallScreen ? 8 : 12),
              _buildGradientButton(
                text: 'Update Password',
                onPressed: _handleUpdatePassword,
                isSmallScreen: isSmallScreen,
              ),
            ],
          ] else ...[
            // Edit Profile Button
            _buildGradientButton(
              text: 'Edit Profile',
              onPressed: () {
                setState(() {
                  _isEditingProfile = true;
                });
              },
              isSmallScreen: isSmallScreen,
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Logout Button
            _buildOutlineButton(
              text: 'Logout',
              onPressed: _handleLogout,
              isDestructive: true,
              isSmallScreen: isSmallScreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isSmallScreen,
  }) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          height: isSmallScreen ? 44 : 52,
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
              onTap: authProvider.isLoading ? null : onPressed,
              child: Center(
                child: authProvider.isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Text(
                        text,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutlineButton({
    required String text,
    required VoidCallback onPressed,
    required bool isSmallScreen,
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
      height: isSmallScreen ? 44 : 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDestructive 
              ? Colors.red.withOpacity(0.5)
              : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectDate() {
    picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(1900, 1, 1),
      maxTime: DateTime.now().subtract(const Duration(days: 365 * 13)),
      currentTime: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
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

  Future<void> _handleSaveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.updateProfile(
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _selectedGender,
    );

    if (success && mounted) {
      setState(() {
        _isEditingProfile = false;
        _isChangingPassword = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleUpdatePassword() async {
    print("🔄 ProfileScreen._handleUpdatePassword: Starting password update UI flow");
    
    if (_currentPasswordController.text.isEmpty) {
      print("❌ ProfileScreen: Current password is empty");
      _showErrorSnackBar('Please enter your current password');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      print("❌ ProfileScreen: New password too short (${_newPasswordController.text.length} chars)");
      _showErrorSnackBar('New password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      print("❌ ProfileScreen: Password confirmation mismatch");
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    print("✅ ProfileScreen: All validations passed");
    print("📤 ProfileScreen: Current password length: ${_currentPasswordController.text.length}");
    print("📤 ProfileScreen: New password length: ${_newPasswordController.text.length}");

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    print("🔗 ProfileScreen: Calling authProvider.updatePassword");
    final success = await authProvider.updatePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    print("📊 ProfileScreen: Password update result: $success");
    print("📊 ProfileScreen: AuthProvider error: ${authProvider.errorMessage}");
    print("📊 ProfileScreen: AuthProvider state: ${authProvider.state}");

    if (success && mounted) {
      print("✅ ProfileScreen: Password update successful, updating UI");
      setState(() {
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      print("❌ ProfileScreen: Password update failed");
      if (authProvider.errorMessage != null) {
        print("❌ ProfileScreen: Showing error: ${authProvider.errorMessage}");
        _showErrorSnackBar(authProvider.errorMessage!);
      } else {
        print("❌ ProfileScreen: No specific error message, showing generic error");
        _showErrorSnackBar('Password update failed. Please try again.');
      }
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldLogout && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
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