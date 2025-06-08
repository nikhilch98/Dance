import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import './studios_screen.dart';
import './artists_screen.dart';
import './workshops_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        
        // Define screens based on admin status
        final screens = <Widget>[
          const StudiosScreen(),
          const ArtistsScreen(),
          const WorkshopsScreen(),
          if (isAdmin) const AdminScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          extendBody: true, // This extends the body behind the bottom nav
          body: Center(
            child: screens.elementAt(_selectedIndex),
          ),
          floatingActionButton: _buildSearchButton(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
          bottomNavigationBar: Container(
            margin: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.transparent, // Ensure transparent background
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      if (isAdmin)
                        _buildNavItem(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin',
                          index: 3,
                          gradient: const [Color(0xFFFF4081), Color(0xFFE91E63)],
                        ),
                      _buildNavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        index: isAdmin ? 4 : 3,
                        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
              size: isSelected ? 24 : 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Container(
      margin: const EdgeInsets.only(top: 50, right: 10),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.3),
                offset: const Offset(0, 4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.search,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
} 