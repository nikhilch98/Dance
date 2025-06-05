import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
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
  String? _localProfilePictureUrl;
  
  bool _isEditingProfile = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _genderOptions = ['male', 'female', 'other'];

  bool _isLoading = false;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

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
      _localProfilePictureUrl = user.profilePictureUrl;
      
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final authState = authProvider.state;
        
        // If user is null and we're in unauthenticated state, let AuthWrapper handle navigation
        // Don't show loading screen during logout
        if (user == null && authState == AuthState.unauthenticated) {
          // Return empty container and let AuthWrapper navigate to login
          return const SizedBox.shrink();
        }
        
        // If user is null but we're not in unauthenticated state, show loading
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Sync local state with provider data if they differ
        if (_localProfilePictureUrl != user.profilePictureUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _localProfilePictureUrl = user.profilePictureUrl;
              });
            }
          });
        }
    
    return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Custom App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
              ],
            ),
          ),
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              child: const Align(
                                alignment: Alignment.bottomLeft,
            child: Text(
              'Profile',
              style: TextStyle(
                                    fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                                    letterSpacing: 1.2,
              ),
            ),
          ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
          Container(
                        margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.1),
            ),
            child: IconButton(
                          onPressed: _showLogoutDialog,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFFF006E),
                            size: 24,
              ),
            ),
          ),
        ],
      ),

                  // Profile Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Profile Header Card
                          _buildProfileHeader(user),
                          
                          const SizedBox(height: 24),
                          
                          // Profile Stats
                          _buildProfileStats(user),
                          
                          const SizedBox(height: 24),
                          
                          // Profile Actions
                          _buildProfileActions(user),
                          
                          const SizedBox(height: 24),
                          
                          // Profile Information
                          _buildProfileInfo(user),
                          
                          const SizedBox(height: 24), // Added spacing before delete button

                          // Delete Account Button
                          _buildDeleteAccountSection(authProvider), // Pass AuthProvider

                          const SizedBox(height: 100), // Bottom padding
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    children: [
              // Profile Picture
              Stack(
                children: [
                        Container(
                    width: 120,
                    height: 120,
                          decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      gradient: _localProfilePictureUrl == null
                          ? const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                          ),
                    child: _localProfilePictureUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.network(
                              'https://nachna.com$_localProfilePictureUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading profile image: $error');
                                return _buildDefaultAvatar(user);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildDefaultAvatar(user);
              },
            ),
                          )
                        : _buildDefaultAvatar(user),
                  ),
                  
                  // Upload/Edit Button
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerDialog,
                      child: Container(
                        width: 36,
                        height: 36,
      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
                          border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
          ),
        ],
      ),
                        child: _isUploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
            color: Colors.white,
                                size: 18,
          ),
        ),
      ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Name
              Text(
                user.name ?? 'Dance Enthusiast',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
        ),
                textAlign: TextAlign.center,
          ),
              
              const SizedBox(height: 4),
              
              // Mobile Number
                Text(
                '+91 ${user.mobileNumber}',
                  style: TextStyle(
                  fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Profile Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: user.profileComplete
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFFF006E), const Color(0xFFDC2626)],
            ),
          ),
                child: Text(
                  user.profileComplete ? 'Profile Complete' : 'Complete Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
        ),
        ),
      child: Center(
        child: Text(
          user.name?.isNotEmpty == true 
              ? user.name!.substring(0, 1).toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStats(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
              _buildStatItem('Member Since', _formatMemberSince(user.createdAt)),
              _buildStatDivider(),
              _buildStatItem('Profile', user.profileComplete ? 'Complete' : 'Incomplete'),
              _buildStatDivider(),
              _buildStatItem('Role', user.isAdmin == true ? 'Admin' : 'Member'),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D4FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
                  style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
                  ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildProfileActions(User user) {
    return Row(
        children: [
        Expanded(
          child: _buildActionButton(
            'Edit Profile',
            Icons.edit_rounded,
            const Color(0xFF3B82F6),
            () => _navigateToEditProfile(),
          ),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Change Password',
            Icons.lock_rounded,
            const Color(0xFF8B5CF6),
            () => _showChangePasswordDialog(),
            ),
        ),
        ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
              ),
            ],
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

  Widget _buildProfileInfo(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Full Name', user.name ?? 'Not provided'),
              _buildInfoRow('Date of Birth', user.dateOfBirth ?? 'Not provided'),
              _buildInfoRow('Gender', user.gender ?? 'Not provided'),
              _buildInfoRow('Mobile Number', '+91 ${user.mobileNumber}'),
              _buildInfoRow('Account Type', user.isAdmin == true ? 'Administrator' : 'Member'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
        ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMemberSince(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 30) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}m';
    } else {
      return '${(difference.inDays / 365).floor()}y';
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Handle
                      Container(
                  width: 40,
                  height: 4,
                        decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                const SizedBox(height: 20),
                
                // Title
                Text(
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
                        () => _pickImageWithPermissionCheck(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                      child: _buildImagePickerOption(
                        'Gallery',
                        Icons.photo_library_rounded,
                        const Color(0xFF10B981),
                        () => _pickImageWithPermissionCheck(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_localProfilePictureUrl != null)
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

  Future<void> _pickImageWithPermissionCheck(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      
      if (image != null) {
        await _uploadProfilePicture(File(image.path));
      } else {
        // User cancelled image selection
              setState(() {
          _isUploadingImage = false;
              });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      
      String errorMessage = 'Failed to pick image.';
      if (e.toString().contains('permission')) {
        errorMessage = source == ImageSource.camera 
            ? 'Camera permission denied. Please enable camera access in Settings.'
            : 'Photo library permission denied. Please enable photo access in Settings.';
      } else if (e.toString().contains('camera')) {
        errorMessage = 'Camera not available. Please try using gallery instead.';
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _uploadProfilePicture(File imageFile) async {
    // Loading state is already set in _pickImageWithPermissionCheck
    try {
      final imageUrl = await AuthService.uploadProfilePicture(imageFile);
      
      // Update local state immediately for instant UI feedback
              setState(() {
        _localProfilePictureUrl = imageUrl;
        _isUploadingImage = false;
      });
      
      // Refresh user data in provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshProfile();
      
      _showSuccessSnackBar('Profile picture updated successfully!');
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
  }

      String errorMessage = 'Failed to upload profile picture.';
      if (e.toString().contains('size')) {
        errorMessage = 'Image file is too large. Please choose a smaller image.';
      } else if (e.toString().contains('format')) {
        errorMessage = 'Invalid image format. Please choose a JPEG or PNG image.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _removeProfilePicture() async {
    Navigator.pop(context); // Close bottom sheet
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      await AuthService.removeProfilePicture();
      
      // Update local state immediately for instant UI feedback
      setState(() {
        _localProfilePictureUrl = null;
        _isUploadingImage = false;
      });
      
      // Refresh user data in provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshProfile();
      
      _showSuccessSnackBar('Profile picture removed successfully!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
      _showErrorSnackBar('Failed to remove profile picture: $e');
    }
  }

  void _navigateToEditProfile() {
    Navigator.pushNamed(context, '/profile-setup');
  }

  void _showChangePasswordDialog() {
    // Implementation for change password dialog
    // This would be similar to the existing implementation
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              
              // Use forceLogout() directly to avoid loading state that causes white screen
              print('[ProfileScreen] Using force logout to avoid loading state');
              authProvider.forceLogout();
              print('[ProfileScreen] Force logout completed');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFFF006E)),
            ),
          ),
        ],
      ),
    );
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF006E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountSection(AuthProvider authProvider) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Divider(color: Colors.white.withOpacity(0.2), height: 40),
          GestureDetector(
            onTap: () => _showDeleteAccountConfirmationDialog(authProvider),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.red.withOpacity(0.1), // Subtle red background
                border: Border.all(
                  color: Colors.red.withOpacity(0.4), // Red border
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red[400],
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmationDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            title: const Text(
              'Delete Account?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete your account? This action is irreversible and all your data will be removed.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  await _handleAccountDeletion(authProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAccountDeletion(AuthProvider authProvider) async {
    print('[ProfileScreen] Starting account deletion process');
    
    // Show loading overlay
    bool isDeletionInProgress = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Deleting Account...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Use AuthProvider's deleteAccount method which handles API call, global config clearing, and state management
      final success = await authProvider.deleteAccount();
      
      // Close loading dialog
      if (mounted && isDeletionInProgress) {
        Navigator.of(context).pop();
        isDeletionInProgress = false;
      }
      
      if (success) {
        print('[ProfileScreen] Account deletion successful - AuthWrapper will handle navigation to login');
        // AuthWrapper will automatically navigate to LoginScreen when state becomes unauthenticated
      } else {
        // Show error message if deletion failed
        if (mounted) {
          final errorMessage = authProvider.errorMessage ?? 'Account deletion failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
      
    } catch (e) {
      print('[ProfileScreen] Account deletion failed: $e');
      
      // Close loading dialog
      if (mounted && isDeletionInProgress) {
        Navigator.of(context).pop();
        isDeletionInProgress = false;
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
} 