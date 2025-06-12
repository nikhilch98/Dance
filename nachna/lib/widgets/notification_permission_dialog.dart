import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/notification_service.dart';
import '../services/first_launch_service.dart';
import '../utils/responsive_utils.dart';

class NotificationPermissionDialog extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;
  final VoidCallback? onDismissed;
  final String? userId;

  const NotificationPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.onDismissed,
    this.userId,
  });

  @override
  State<NotificationPermissionDialog> createState() => _NotificationPermissionDialogState();
}

class _NotificationPermissionDialogState extends State<NotificationPermissionDialog>
    with SingleTickerProviderStateMixin {
  bool _isRequesting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      // Mark that we've requested permission (regardless of outcome)
      await FirstLaunchService().markNotificationPermissionRequested(userId: widget.userId);
      
      // Request permission from the system
      final result = await NotificationService().requestPermissionsAndGetToken();
      
      if (mounted) {
        if (result['success'] == true) {
          // Permission granted
          widget.onPermissionGranted?.call();
          await _animateOut();
          if (mounted) Navigator.of(context).pop(true);
        } else {
          // Permission denied or error
          widget.onPermissionDenied?.call();
          
          if (result['shouldOpenSettings'] == true) {
            // Show option to open settings
            await _showSettingsDialog();
          } else {
            await _animateOut();
            if (mounted) Navigator.of(context).pop(false);
          }
        }
      }
    } catch (e) {
      print('[NotificationPermissionDialog] Error requesting permission: $e');
      if (mounted) {
        widget.onPermissionDenied?.call();
        await _animateOut();
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    await FirstLaunchService().markNotificationPermissionRequested(userId: widget.userId);
    widget.onDismissed?.call();
    await _animateOut();
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _animateOut() async {
    await _animationController.reverse();
  }

  Future<void> _showSettingsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSettingsDialog(),
    );
  }

  Widget _buildSettingsDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: ResponsiveUtils.paddingLarge(context),
        padding: ResponsiveUtils.paddingXLarge(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: ResponsiveUtils.paddingLarge(context),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.avatarSize(context)),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF006E), Color(0xFFDC2626)],
                    ),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: ResponsiveUtils.iconLarge(context),
                  ),
                ),
                
                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                
                Text(
                  'Open Settings?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.h3(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                
                Text(
                  'To enable notifications, please open Settings and turn on notifications for Nachna.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveUtils.body2(context),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: ResponsiveUtils.spacingXXLarge(context)),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _animateOut().then((_) {
                            if (mounted) Navigator.of(context).pop(false);
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingMedium(context)),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: ResponsiveUtils.body2(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    
                    SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                    
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await NotificationService().openNotificationSettings();
                          await _animateOut();
                          if (mounted) Navigator.of(context).pop(false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingMedium(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Open Settings',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.body2(context),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isRequesting) {
          await _skip();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  margin: ResponsiveUtils.paddingLarge(context),
                  padding: ResponsiveUtils.paddingXLarge(context),
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveUtils.screenWidth(context) * 0.9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            padding: ResponsiveUtils.paddingLarge(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.avatarSize(context)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: ResponsiveUtils.iconXLarge(context),
                            ),
                          ),
                          
                          SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          
                          // Title
                          Text(
                            'Stay Updated!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.h2(context),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                          
                          // Description
                          Text(
                            'Get notified about new dance workshops, favorite artists, and exciting updates from Nachna.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: ResponsiveUtils.body2(context),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          
                          // Benefits list
                          Container(
                            padding: ResponsiveUtils.paddingLarge(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Column(
                              children: [
                                _buildBenefitRow(
                                  Icons.event,
                                  'New workshop announcements',
                                ),
                                SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                                _buildBenefitRow(
                                  Icons.favorite,
                                  'Updates from your favorite artists',
                                ),
                                SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                                _buildBenefitRow(
                                  Icons.flash_on,
                                  'Last-minute workshop changes',
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          
                          // Buttons
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isRequesting ? null : _requestPermission,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D4FF),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingLarge(context)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isRequesting
                                      ? SizedBox(
                                          height: ResponsiveUtils.iconSmall(context),
                                          width: ResponsiveUtils.iconSmall(context),
                                          child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Enable Notifications',
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.body1(context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ),
                              
                              SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                              
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _isRequesting ? null : _skip,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingMedium(context)),
                                  ),
                                  child: Text(
                                    'Maybe Later',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: ResponsiveUtils.body2(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00D4FF),
          size: ResponsiveUtils.iconSmall(context),
        ),
        SizedBox(width: ResponsiveUtils.spacingMedium(context)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: ResponsiveUtils.caption(context),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
} 