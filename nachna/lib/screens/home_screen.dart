import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../services/pending_order_service.dart';
import './studios_screen.dart';
import './artists_screen.dart';
import './workshops_screen.dart';
import './reels_screen.dart';
import './profile_screen.dart';
import './admin_screen.dart';
import './search_screen.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  late PageController _pageController;
  bool? _isAdminCached;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);
  }
  
  /// Check for pending orders (can be called when user returns to app)
  Future<void> checkPendingOrders() async {
    try {
      await PendingOrderService.instance.checkAndNavigateToPendingOrder();
    } catch (e) {
      print('[HomeScreen] Error checking pending orders: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Configure system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    return Consumer<ConfigProvider>(
      builder: (context, configProvider, child) {
        // Ensure config is loaded when HomeScreen is built
        if (configProvider.state == ConfigState.initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            configProvider.loadConfig();
          });
        }
        
        final isAdmin = configProvider.isAdmin;
        if (_isAdminCached != isAdmin) {
          // Rebuild the page controller if the number of tabs changes
          _isAdminCached = isAdmin;
          final maxIndex = isAdmin ? 6 : 5;
          if (_selectedIndex > maxIndex) {
            _selectedIndex = maxIndex;
          }
          _pageController.dispose();
          _pageController = PageController(initialPage: _selectedIndex);
        }
        
        // Define screens based on admin status
        // Order: Studios(0), Artists(1), Workshops(2), Reels(3), Search(4), [Admin(5)], Profile(5/6)
        final screens = <Widget>[
          const StudiosScreen(key: PageStorageKey('studios')),
          const ArtistsScreen(key: PageStorageKey('artists')),
          const WorkshopsScreen(key: PageStorageKey('workshops')),
          const ReelsScreen(key: PageStorageKey('reels')),
          const SearchScreen(key: PageStorageKey('search')),
          if (isAdmin) const AdminScreen(key: PageStorageKey('admin')),
          const ProfileScreen(key: PageStorageKey('profile')),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          extendBody: true, // This extends the body behind the bottom nav
          body: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: screens,
          ),

          bottomNavigationBar: Builder(
            builder: (context) {
              // Pre-calculate responsive values to avoid multiple MediaQuery calls
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final navBarMargin = (screenWidth * 0.04).clamp(12.0, 20.0);
              final navBarHeight = (screenHeight * 0.095).clamp(70.0, 90.0);
              final navBarBorderRadius = (screenWidth * 0.06).clamp(20.0, 28.0);
              final horizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);
              final verticalPadding = (screenHeight * 0.015).clamp(10.0, 16.0);

              return Container(
                margin: EdgeInsets.all(navBarMargin),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(navBarBorderRadius),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(navBarBorderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: navBarHeight,
                      decoration: const BoxDecoration(
                        color: Colors.transparent, // Ensure transparent background
                      ),
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        icon: Icons.business_rounded,
                        label: 'Studios',
                        index: 0,
                        gradient: const [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
                      ),
                      _buildNavItem(
                        icon: Icons.people_rounded,
                        label: 'Artists',
                        index: 1,
                        gradient: const [Color(0xFFFF006E), Color(0xFF8338EC)],
                      ),
                      _buildNavItem(
                        icon: Icons.event_rounded,
                        label: 'Workshops',
                        index: 2,
                        gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      _buildNavItem(
                        icon: Icons.slow_motion_video_rounded,
                        label: 'Reels',
                        index: 3,
                        gradient: const [Color(0xFFE1306C), Color(0xFFC13584)],
                      ),
                      _buildNavItem(
                        icon: Icons.search_rounded,
                        label: 'Search',
                        index: 4,
                        gradient: const [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                      ),
                      if (isAdmin)
                        _buildNavItem(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin',
                          index: 5,
                          gradient: const [Color(0xFFFF4081), Color(0xFFE91E63)],
                        ),
                      _buildNavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        index: isAdmin ? 6 : 5,
                        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
            },
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required List<Color> gradient,
  }) {
    final isSelected = _selectedIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = (screenWidth * 0.055).clamp(18.0, 26.0);
    final selectedIconSize = (screenWidth * 0.06).clamp(20.0, 28.0);
    final fontSize = (screenWidth * 0.025).clamp(9.0, 12.0);
    final horizontalPadding = (screenWidth * 0.025).clamp(8.0, 14.0);
    final verticalPadding = (screenWidth * 0.02).clamp(6.0, 10.0);
    final borderRadius = (screenWidth * 0.04).clamp(12.0, 18.0);

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? horizontalPadding : horizontalPadding * 0.7,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: isSelected
              ? LinearGradient(colors: gradient)
              : LinearGradient(
                  colors: [
                    gradient[0].withOpacity(0.1),
                    gradient[1].withOpacity(0.1),
                  ],
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: isSelected ? selectedIconSize : iconSize,
            ),
            if (isSelected) ...[
              SizedBox(width: screenWidth * 0.015),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


} 