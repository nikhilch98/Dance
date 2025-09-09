import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../utils/responsive_utils.dart';
import '../providers/config_provider.dart';
import '../providers/global_config_provider.dart';
import '../providers/reaction_provider.dart';
import 'orders_screen.dart';
import 'rewards_center_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();

  
  String? _selectedGender;
  DateTime? _selectedDate;
  String? _dateOfBirth;
  String? _localProfilePictureUrl;
  
  bool _isEditingProfile = false;
  
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
                    expandedHeight: ResponsiveUtils.isSmallScreen(context) ? 100 : 120,
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
                              padding: ResponsiveUtils.paddingLarge(context),
                              child: Align(
                                alignment: Alignment.bottomLeft,
            child: Text(
              'Profile',
              style: TextStyle(
                                    fontSize: ResponsiveUtils.h1(context),
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
                        margin: EdgeInsets.only(right: ResponsiveUtils.spacingLarge(context)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                          color: Colors.white.withOpacity(0.1),
            ),
            child: IconButton(
                          onPressed: _showLogoutDialog,
                          icon: Icon(
                            Icons.logout_rounded,
                            color: const Color(0xFFFF006E),
                            size: ResponsiveUtils.iconMedium(context),
              ),
            ),
          ),
        ],
      ),

                  // Profile Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveUtils.paddingLarge(context),
                      child: Column(
                        children: [
                          // Profile Header Card
                          _buildProfileHeader(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                          
                          // Profile Stats
                          _buildProfileStats(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                          
                          // Profile Actions
                          _buildProfileActions(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                          
                          // Orders Section
                          _buildOrdersSection(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                          
                          // Rewards Section
                          _buildRewardsSection(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                          
                          // Profile Information
                          _buildProfileInfo(user),
                          
                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context)), // Added spacing before delete button

                          // Delete Account Button
                          _buildDeleteAccountSection(authProvider), // Pass AuthProvider

                          SizedBox(height: ResponsiveUtils.spacingXXLarge(context) * 2), // Bottom padding
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
      padding: ResponsiveUtils.paddingXLarge(context),
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
          width: ResponsiveUtils.borderWidthThin(context),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    children: [
              // Profile Picture
              Stack(
                children: [
                        Container(
                    width: ResponsiveUtils.avatarSizeLarge(context),
                    height: ResponsiveUtils.avatarSizeLarge(context),
                          decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.avatarSizeLarge(context) / 2),
                      gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          blurRadius: ResponsiveUtils.spacingLarge(context),
                          spreadRadius: 2,
                        ),
                      ],
                          ),
                    child: ClipRRect(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.avatarSizeLarge(context) / 2),
                            child: Image.network(
                              'https://nachna.com/api/image/user/${user.userId}',
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildDefaultAvatar(user);
                              },
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to old profile-picture endpoint
                                return Image.network(
                                  'https://nachna.com/api/profile-picture/${user.userId}',
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildDefaultAvatar(user);
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    // Final fallback to default avatar
                                    return _buildDefaultAvatar(user);
                                  },
                                );
                              },
            ),
                          ),
                  ),
                  
                  // Upload/Edit Button
                  Builder(
                    builder: (context) {
                      // Pre-calculate responsive values to avoid MediaQuery in Positioned
                      final iconLarge = ResponsiveUtils.iconLarge(context);
                      final spacingMedium = ResponsiveUtils.spacingMedium(context);
                      final borderWidthMedium = ResponsiveUtils.borderWidthMedium(context);
                      final spacingSmall = ResponsiveUtils.spacingSmall(context);
                      final spacingLarge = ResponsiveUtils.spacingLarge(context);
                      final iconSmall = ResponsiveUtils.iconSmall(context);
                      
                      final buttonSize = iconLarge + spacingMedium;
                      
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showImagePickerDialog(user),
                          child: Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(buttonSize / 2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                              border: Border.all(color: Colors.white, width: borderWidthMedium),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  blurRadius: spacingSmall,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: _isUploadingImage
                                ? SizedBox(
                                    width: spacingLarge,
                                    height: spacingLarge,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: iconSmall,
                                  ),
                          ),
                        ),
                      );
                    }
                  ),
                ],
              ),
              
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              
              // Name
              Text(
                user.name ?? 'Dance Enthusiast',
                style: TextStyle(
                  fontSize: ResponsiveUtils.h2(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
        ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
          ),
              
              SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
              
              // Mobile Number
                Text(
                '+91 ${user.mobileNumber}',
                  style: TextStyle(
                  fontSize: ResponsiveUtils.body2(context),
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              
              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
              
              // Profile Status
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacingMedium(context), 
                  vertical: ResponsiveUtils.spacingXSmall(context)
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                  gradient: LinearGradient(
                    colors: user.profileComplete
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFFF006E), const Color(0xFFDC2626)],
            ),
          ),
                child: Text(
                  user.profileComplete ? 'Profile Complete' : 'Complete Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.micro(context),
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
        borderRadius: BorderRadius.circular(ResponsiveUtils.avatarSizeLarge(context) / 2),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
        ),
        ),
      child: Center(
        child: Text(
          user.name?.isNotEmpty == true 
              ? user.name!.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: ResponsiveUtils.h1(context) * 1.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStats(User user) {
    return Container(
      padding: ResponsiveUtils.paddingLarge(context),
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: ResponsiveUtils.borderWidthThin(context),
        ),
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
              Flexible(child: _buildStatItem('Member Since', _formatMemberSince(user.createdAt))),
              _buildStatDivider(),
              Flexible(child: _buildStatItem('Profile', user.profileComplete ? 'Complete' : 'Incomplete')),
              _buildStatDivider(),
              Flexible(child: _buildStatItem('Role', user.isAdmin == true ? 'Admin' : 'Member')),
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
          style: TextStyle(
            fontSize: ResponsiveUtils.body1(context),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00D4FF),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
        Text(
          label,
                  style: TextStyle(
            fontSize: ResponsiveUtils.micro(context),
            color: Colors.white.withOpacity(0.7),
                  ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: ResponsiveUtils.borderWidthThin(context),
      height: ResponsiveUtils.spacingXXLarge(context) + ResponsiveUtils.spacingLarge(context),
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildProfileActions(User user) {
    return Center(
      child: SizedBox(
        width: ResponsiveUtils.screenWidth(context) * 0.5,
        child: _buildActionButton(
          'Edit Profile',
          Icons.edit_rounded,
          const Color(0xFF3B82F6),
          () => _navigateToEditProfile(),
        ),
      ),
    );
  }

  Widget _buildOrdersSection(User user) {
    return Container(
      padding: ResponsiveUtils.paddingLarge(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: ResponsiveUtils.borderWidthThin(context),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: ResponsiveUtils.paddingSmall(context),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: ResponsiveUtils.iconSmall(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                  Expanded(
                    child: Text(
                      'My Orders',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.body1(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: ResponsiveUtils.iconSmall(context),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              Text(
                'View and manage your workshop registrations',
                style: TextStyle(
                  fontSize: ResponsiveUtils.body2(context),
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  'View All Orders',
                  Icons.receipt_long_rounded,
                  const Color(0xFF3B82F6),
                  () => _navigateToOrders(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsSection(User user) {
    return Container(
      padding: ResponsiveUtils.paddingLarge(context),
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
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D4FF),
                          const Color(0xFF9C27B0),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: ResponsiveUtils.iconMedium(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                  Expanded(
                    child: Text(
                      'Rewards Center',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.body1(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              Container(
                padding: ResponsiveUtils.paddingMedium(context),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          color: const Color(0xFF00D4FF),
                          size: ResponsiveUtils.iconSmall(context),
                        ),
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        Text(
                          'Earn points on every workshop booking',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.caption(context),
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                    Row(
                      children: [
                        Icon(
                          Icons.discount,
                          color: const Color(0xFF10B981),
                          size: ResponsiveUtils.iconSmall(context),
                        ),
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        Text(
                          'Redeem for discounts on future bookings',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.caption(context),
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  'View Rewards Center',
                  Icons.account_balance_wallet,
                  const Color(0xFF00D4FF),
                  () => _navigateToRewardsCenter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingLarge(context)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: ResponsiveUtils.spacingSmall(context),
              spreadRadius: 1,
              ),
            ],
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: ResponsiveUtils.iconSmall(context)),
            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
            Text(
                        text,
              style: TextStyle(
                          color: Colors.white,
                fontSize: ResponsiveUtils.body2(context),
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
      padding: ResponsiveUtils.paddingLarge(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: ResponsiveUtils.borderWidthThin(context),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
              style: TextStyle(
                  fontSize: ResponsiveUtils.body1(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
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
      padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveUtils.screenWidth(context) * 0.35,
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.body2(context),
                color: Colors.white.withOpacity(0.7),
        ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveUtils.body2(context),
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

  void _showImagePickerDialog(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: ResponsiveUtils.paddingLarge(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ResponsiveUtils.cardBorderRadius(context))),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ResponsiveUtils.cardBorderRadius(context))),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Handle
                      Container(
                  width: ResponsiveUtils.spacingXXLarge(context) + ResponsiveUtils.spacingLarge(context),
                  height: ResponsiveUtils.spacingXSmall(context),
                        decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXSmall(context) / 2),
                        ),
                      ),
                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                
                // Title
                Text(
                  'Profile Picture',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.h3(context),
                            fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  ),
                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
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
                      SizedBox(width: ResponsiveUtils.spacingMedium(context)),
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
                SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                if (user.profilePictureUrl != null)
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
        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingLarge(context)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
      children: [
            Icon(icon, color: Colors.white, size: ResponsiveUtils.iconSmall(context)),
            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.body2(context),
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
    // Set loading state
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      final imageUrl = await AuthService.uploadProfilePicture(imageFile);
      
      // Update local state for consistency with backend
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
      
      // Update local state for consistency with backend
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

  void _navigateToOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OrdersScreen()),
    );
  }

  void _navigateToRewardsCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RewardsCenterScreen()),
    );
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
            onPressed: () => _handleLogout(),
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFFF006E)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context); // Close dialog first
    
    print('[ProfileScreen] Starting logout process');
    
    // Show loading overlay to prevent UI glitches
    bool isLogoutInProgress = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Logging out...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Use the full logout method instead of forceLogout for proper cleanup
      print('[ProfileScreen] Calling AuthProvider.logout()');
      await authProvider.logout();
      
      // Also clear other providers explicitly to ensure clean state
      if (mounted) {
        print('[ProfileScreen] Clearing other providers...');
        
        // Clear ConfigProvider
        try {
          final configProvider = Provider.of<ConfigProvider>(context, listen: false);
          configProvider.clearConfig();
          print('[ProfileScreen] ConfigProvider cleared');
        } catch (e) {
          print('[ProfileScreen] Error clearing ConfigProvider: $e');
        }
        
        // Clear GlobalConfigProvider
        try {
          final globalConfigProvider = Provider.of<GlobalConfigProvider>(context, listen: false);
          await globalConfigProvider.clearConfig();
          print('[ProfileScreen] GlobalConfigProvider cleared');
        } catch (e) {
          print('[ProfileScreen] Error clearing GlobalConfigProvider: $e');
        }
        
        // Clear ReactionProvider by removing auth token
        try {
          final reactionProvider = Provider.of<ReactionProvider>(context, listen: false);
          reactionProvider.setAuthToken('');
          print('[ProfileScreen] ReactionProvider cleared');
        } catch (e) {
          print('[ProfileScreen] Error clearing ReactionProvider: $e');
        }
      }
      
      // Close loading dialog if still open
      if (mounted && isLogoutInProgress) {
        Navigator.of(context).pop();
        isLogoutInProgress = false;
      }
      
      // Navigate to login screen immediately and clear all navigation stack
      if (mounted) {
        print('[ProfileScreen] Navigating to login screen');
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', // Go to root route which AuthWrapper will handle
          (route) => false, // Clear all previous routes
        );
      }
      
      print('[ProfileScreen] Logout completed successfully');
      
    } catch (e) {
      print('[ProfileScreen] Logout error: $e');
      
      // Close loading dialog if still open
      if (mounted && isLogoutInProgress) {
        Navigator.of(context).pop();
        isLogoutInProgress = false;
      }
      
      // Force logout even if there was an error and clear all providers
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.forceLogout();
        
        // Force clear other providers
        try {
          Provider.of<ConfigProvider>(context, listen: false).clearConfig();
          Provider.of<GlobalConfigProvider>(context, listen: false).clearConfig();
          Provider.of<ReactionProvider>(context, listen: false).setAuthToken('');
          print('[ProfileScreen] Force cleared all providers');
        } catch (clearError) {
          print('[ProfileScreen] Error force clearing providers: $clearError');
        }
        
        // Navigate to login screen anyway
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
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
          Divider(
            color: Colors.white.withOpacity(0.2), 
            height: ResponsiveUtils.spacingXXLarge(context) + ResponsiveUtils.spacingLarge(context)
          ),
          GestureDetector(
            onTap: () => _showDeleteAccountConfirmationDialog(authProvider),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.spacingLarge(context), 
                horizontal: ResponsiveUtils.spacingLarge(context)
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                color: Colors.red.withOpacity(0.1), // Subtle red background
                border: Border.all(
                  color: Colors.red.withOpacity(0.4), // Red border
                  width: ResponsiveUtils.borderWidthThin(context),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red[400],
                    size: ResponsiveUtils.iconMedium(context),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                  Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontSize: ResponsiveUtils.body2(context),
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
              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
              side: BorderSide(color: Colors.white.withOpacity(0.2), width: ResponsiveUtils.borderWidthThin(context)),
            ),
            title: Text(
              'Delete Account?',
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.h3(context),
              ),
            ),
            content: Text(
              'Are you sure you want to delete your account? This action is irreversible and all your data will be removed.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveUtils.body2(context),
              ),
            ),
                          actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacingLarge(context), 
                      vertical: ResponsiveUtils.spacingSmall(context)
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8), 
                      fontSize: ResponsiveUtils.body2(context)
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacingLarge(context), 
                      vertical: ResponsiveUtils.spacingSmall(context)
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red, 
                      fontSize: ResponsiveUtils.body2(context), 
                      fontWeight: FontWeight.bold
                    ),
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
      builder: (context) => PopScope(
        canPop: false,
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