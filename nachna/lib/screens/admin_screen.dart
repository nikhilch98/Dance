import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../providers/global_config_provider.dart';
import '../models/artist.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nachna/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../services/first_launch_service.dart';
import '../services/admin_service.dart';
import '../models/app_insights.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/responsive_utils.dart';
import '../utils/payment_link_utils.dart';
import '../widgets/qr_scanner_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> missingArtistSessions = [];
  List<Map<String, dynamic>> missingSongSessions = [];
  List<Artist> allArtists = [];
  String? artistsError;
  String? songsError;
  bool isLoadingArtists = false;
  bool isLoadingSongs = false;

  // App Insights state
  AppInsights? appInsights;
  bool isLoadingInsights = false;
  String? insightsError;
  
  // APNs Test Form Controllers
  final TextEditingController _deviceTokenController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isTestNotificationLoading = false;
  
  // Artist Notification Test Controllers
  final TextEditingController _artistTitleController = TextEditingController();
  final TextEditingController _artistBodyController = TextEditingController();
  String? _selectedArtistId;
  bool _isArtistNotificationLoading = false;
  
  // Instagram Links state
  List<Map<String, dynamic>> missingInstagramLinkWorkshops = [];
  List<Map<String, dynamic>> filteredInstagramLinkWorkshops = [];
  bool isLoadingInstagramLinks = false;
  String? instagramLinksError;
  // Filters for Instagram Links tab
  List<String> availableByFilters = [];
  List<String> selectedByFilters = [];

  // Registrations List state
  List<Map<String, dynamic>> workshopRegistrations = [];
  List<Map<String, dynamic>> filteredRegistrations = [];
  bool isLoadingRegistrations = false;
  String? registrationsError;
  // Filters for Registrations tab
  List<String> availableArtists = [];
  List<String> availableSongs = [];
  List<String> availableStudios = [];
  String? selectedArtistFilter;
  String? selectedSongFilter;
  String? selectedStudioFilter;
  String searchQuery = '';
  bool _isExportingCSV = false;

  late TabController _tabController;

  // Access control
  List<String> _adminAccessList = [];
  List<Map<String, dynamic>> _availableTabs = [];

  // Define all available tabs with their access keys
  final List<Map<String, dynamic>> _allTabs = [
    {
      'key': 'songs',
      'title': 'Songs',
      'icon': Icons.music_note,
    },
    {
      'key': 'artists',
      'title': 'Artists',
      'icon': Icons.person,
    },
    {
      'key': 'notifications',
      'title': 'Notifications',
      'icon': Icons.notifications,
    },
    {
      'key': 'config',
      'title': 'Config',
      'icon': Icons.settings,
    },
    {
      'key': 'instagram_links',
      'title': 'Instagram Links',
      'icon': Icons.link,
    },
    {
      'key': 'insights',
      'title': 'Insights',
      'icon': Icons.analytics,
    },
    {
      'key': 'data_updates',
      'title': 'Data updates',
      'icon': Icons.data_object,
    },
    {
      'key': 'qr_scanner',
      'title': 'QR Scanner',
      'icon': Icons.qr_code_scanner,
    },
    {
      'key': 'registrations_list',
      'title': 'Registrations List',
      'icon': Icons.list_alt,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with empty tabs first, will be updated after access control
    _availableTabs = [];
    _tabController = TabController(length: 0, vsync: this);
    _initializeAdminAccess();
  }

  Future<void> _initializeAdminAccess() async {
    await _loadUserProfile();
    _filterAvailableTabs();

    // Log access control information for debugging
    debugPrint('🔐 ADMIN ACCESS CONTROL:');
    debugPrint('  - Raw admin_access_list: $_adminAccessList');
    debugPrint('  - Has "all" access: ${_adminAccessList.contains('all')}');
    debugPrint('  - Available tabs: ${_availableTabs.map((tab) => tab['key']).toList()}');
    debugPrint('  - Tab count: ${_availableTabs.length}');

    // Update TabController with available tabs
    _tabController.dispose();
    setState(() {
      _tabController = TabController(length: _availableTabs.length, vsync: this);
    });

    _loadMissingArtistSessions();
    _loadMissingSongSessions();
    _loadAllArtists();
    _loadAppInsights();
    _loadMissingInstagramLinks();
    _loadWorkshopRegistrations();

    // Initialize the global config provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GlobalConfigProvider>().initialize();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        _adminAccessList = authProvider.user!.adminAccessList ?? [];
        debugPrint('👤 USER PROFILE LOADED:');
        debugPrint('  - User ID: ${authProvider.user!.userId}');
        debugPrint('  - Is Admin: ${authProvider.user!.isAdmin}');
        debugPrint('  - Admin Access List: $_adminAccessList');
      } else {
        debugPrint('⚠️ No user profile available');
        _adminAccessList = [];
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile for admin access: $e');
      _adminAccessList = []; // Default to no access if error
    }
  }

  void _filterAvailableTabs() {
    if (_adminAccessList.contains('all')) {
      // Show all tabs if 'all' is in access list
      _availableTabs = List.from(_allTabs);
      debugPrint('✅ FULL ACCESS: All tabs enabled (${_availableTabs.length} tabs)');
    } else {
      // Filter tabs based on access list
      final beforeCount = _allTabs.length;
      _availableTabs = _allTabs.where((tab) {
        final hasAccess = _adminAccessList.contains(tab['key']);
        if (!hasAccess) {
          debugPrint('🚫 ACCESS DENIED: ${tab['key']} tab not in access list');
        }
        return hasAccess;
      }).toList();
      debugPrint('🔍 FILTERED ACCESS: $beforeCount → ${_availableTabs.length} tabs enabled');
      debugPrint('  - Allowed tabs: ${_availableTabs.map((tab) => tab['key']).toList()}');
    }
  }

  /// Load application insights and statistics
  Future<void> _loadAppInsights() async {
    if (mounted) {
      setState(() {
        isLoadingInsights = true;
        insightsError = null;
      });
    }

    try {
      final data = await AdminService.getAppInsights();
      if (data != null && mounted) {
        setState(() {
          appInsights = AppInsights.fromJson(data);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          insightsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInsights = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceTokenController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _artistTitleController.dispose();
    _artistBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadAllArtists() async {
    try {
      final artists = await ApiService().fetchArtists(hasWorkshops: null); // null means all artists
      if (mounted) {
        setState(() {
          allArtists = artists;
        });
      }
    } catch (e) {
      print('Error loading artists: $e');
    }
  }

  Future<void> _loadMissingSongSessions() async {
    if (mounted) {
      setState(() {
        isLoadingSongs = true;
        songsError = null;
      });
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('https://nachna.com/admin/api/missing_song_sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            missingSongSessions = List<Map<String, dynamic>>.from(json.decode(response.body));
          });
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to load workshops missing songs (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          songsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSongs = false;
        });
      }
    }
  }

  Future<void> _loadMissingArtistSessions() async {
    if (mounted) {
      setState(() {
        isLoadingArtists = true;
        artistsError = null;
      });
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('https://nachna.com/admin/api/missing_artist_sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            missingArtistSessions = List<Map<String, dynamic>>.from(json.decode(response.body));
          });
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to load workshops missing artists (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          artistsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingArtists = false;
        });
      }
    }
  }

  Future<void> _assignArtistToWorkshop(String workshopUuid, List<Artist> artists) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.put(
        Uri.parse('https://nachna.com/admin/api/workshops/$workshopUuid/assign_artist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'artist_id_list': artists.map((artist) => artist.id).toList(),
          'artist_name_list': artists.map((artist) => artist.name).toList(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          final artistNames = artists.map((artist) => artist.name).join(' X ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully assigned $artistNames'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh the missing artists list
          _loadMissingArtistSessions();
        }
      } else {
        throw Exception('Failed to assign artists (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _assignSongToWorkshop(String workshopUuid, String songName) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.put(
        Uri.parse('https://nachna.com/admin/api/workshops/$workshopUuid/assign_song'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'song': songName,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully assigned song: $songName'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh the missing songs list
          _loadMissingSongSessions();
        }
      } else {
        throw Exception('Failed to assign song (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showAssignArtistDialog(Map<String, dynamic> session) async {
    if (allArtists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No artists available. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AssignArtistDialog(
          session: session,
          allArtists: allArtists,
          onAssignArtist: _assignArtistToWorkshop,
        );
      },
    );
  }

  Future<void> _showAssignSongDialog(Map<String, dynamic> session) async {
    final TextEditingController songController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
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
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4081), Color(0xFFE91E63)],
                              ),
                            ),
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Assign Song',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Workshop Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session['original_by_field'] ?? 'Unknown Workshop',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📅 ${session['date']} • 📍 ${session['studio_name']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Song Input Field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: songController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter song name...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                            prefixIcon: Icon(
                              Icons.music_note,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.withOpacity(0.3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final songName = songController.text.trim();
                                if (songName.isNotEmpty) {
                                  Navigator.of(context).pop();
                                  _assignSongToWorkshop(session['workshop_uuid'], songName);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ Please enter a song name'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4081),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Assign',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // Modern AppBar with glass effect
              Container(
                margin: ResponsiveUtils.paddingLarge(context),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
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
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.spacingXLarge(context), 
                        horizontal: ResponsiveUtils.spacingXXLarge(context)
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: ResponsiveUtils.paddingSmall(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4081), Color(0xFFE91E63)],
                              ),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: ResponsiveUtils.iconMedium(context),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Dashboard',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.h3(context),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                                Text(
                                  _adminAccessList.isEmpty
                                    ? 'Access: No Admin Permissions'
                                    : 'Access: ${_adminAccessList.contains('all') ? 'All Permissions' : _adminAccessList.join(', ')}',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.caption(context),
                                    color: _adminAccessList.isEmpty
                                      ? Colors.red.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Show tabs only if available
              if (_availableTabs.isNotEmpty) ...[
                // Tab Bar
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacingLarge(context),
                    vertical: ResponsiveUtils.spacingSmall(context)
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
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
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF4081), Color(0xFFE91E63)],
                          ),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withOpacity(0.6),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.body2(context),
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: ResponsiveUtils.body2(context),
                        ),
                        tabs: _availableTabs.map((tab) {
                          final tabKey = tab['key'] as String;
                          final tabTitle = tab['title'] as String;
                          final tabIcon = tab['icon'] as IconData;

                          // Special handling for badge counts
                          int? badgeCount;
                          if (tabKey == 'songs') {
                            badgeCount = missingSongSessions.length;
                          } else if (tabKey == 'artists') {
                            badgeCount = missingArtistSessions.length;
                          }

                          return Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tabIcon, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    tabTitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (badgeCount != null && badgeCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    child: Text(
                                      '$badgeCount',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _availableTabs.map((tab) {
                      final tabKey = tab['key'] as String;
                      switch (tabKey) {
                        case 'songs':
                          return _buildMissingSongsTab();
                        case 'artists':
                          return _buildMissingArtistsTab();
                        case 'notifications':
                          return _buildNotificationsTab();
                        case 'config':
                          return _buildConfigTab();
                        case 'instagram_links':
                          return _buildInstagramLinksTab();
                        case 'insights':
                          return _buildInsightsTab();
                        case 'data_updates':
                          return _buildDataUpdatesTab();
                        case 'qr_scanner':
                          return _buildQRScannerTab();
                        case 'registrations_list':
                          return _buildRegistrationsListTab();
                        default:
                          return const Center(
                            child: Text('Tab not implemented'),
                          );
                      }
                    }).toList(),
                  ),
                ),
              ] else ...[
                // No access message
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.1),
                            Colors.red.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Access Restricted',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You do not have permission to access any admin features.\n\nPlease contact your administrator to request access.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingSongsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingSongs)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else if (songsError != null)
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        songsError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMissingSongSessions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (missingSongSessions.isEmpty)
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.1),
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All workshops have songs assigned! 🎉',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: missingSongSessions.length,
                itemBuilder: (context, index) {
                  final session = missingSongSessions[index];
                  return _buildSessionCard(
                    session,
                    Icons.music_note,
                    const Color(0xFFFF4081),
                    showAssignSongButton: true,
                    showRegisterButton: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMissingArtistsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingArtists)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF006E)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else if (artistsError != null)
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artistsError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMissingArtistSessions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (missingArtistSessions.isEmpty)
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.1),
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All workshops have artists assigned! 🎉',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: missingArtistSessions.length,
                itemBuilder: (context, index) {
                  final session = missingArtistSessions[index];
                  return _buildSessionCard(
                    session,
                    Icons.person,
                    const Color(0xFFFF006E),
                    showAssignButton: true,
                    showRegisterButton: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // APNs Test Section
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                          ),
                        ),
                        child: const Icon(
                          Icons.phone_iphone,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test APNs Notification',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Send a test notification directly to a device',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _APNsTestWidget(),
                ],
              ),
            ),
            
            // Artist Notification Test Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                          ),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Artist Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Send notifications to users following an artist',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ArtistNotificationTestWidget(allArtists: allArtists),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigTab() {
    return Consumer<GlobalConfigProvider>(
      builder: (context, configProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
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
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                              ),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Global Configuration',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current app configuration and tokens',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (configProvider.isLoading)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFF00D4FF),
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Control Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: configProvider.isLoading 
                                  ? null 
                                  : () async {
                                      await configProvider.fullSync();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('✅ Configuration synced successfully'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.sync, size: 18),
                              label: const Text(
                                'Sync Config',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: configProvider.isLoading 
                                  ? null 
                                  : () {
                                      configProvider.debugPrintConfig();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('📋 Config printed to console'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.bug_report, size: 18),
                              label: const Text(
                                'Debug Log',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Reset First Launch Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: configProvider.isLoading 
                                  ? null 
                                  : () async {
                                      await configProvider.resetFirstLaunchStatus();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('🔄 First launch status reset! Restart app to test notification dialog.'),
                                            backgroundColor: Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF006E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text(
                                'Reset First Launch',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Reset Notification Permission for Current User Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: configProvider.isLoading 
                                  ? null 
                                  : () async {
                                      try {
                                        // Get current user ID
                                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                        final userId = authProvider.user?.userId;
                                        
                                        if (userId == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('❌ No user logged in'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        // Reset notification permission for this user
                                        await FirstLaunchService().resetNotificationPermissionForUser(userId);
                                        
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('🔔 Notification permission reset for user: $userId\nRestart app to see permission dialog.'),
                                              backgroundColor: Colors.orange,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('❌ Error resetting notification permission: $e'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.notifications_off, size: 18),
                              label: const Text(
                                'Reset User Notifications',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Debug Token Button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: configProvider.isLoading 
                                  ? null 
                                  : () async {
                                      try {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('🔍 Requesting device token... Check console for logs.'),
                                            backgroundColor: Colors.blue,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        
                                        final result = await NotificationService().requestPermissionsAndGetToken();
                                        
                                        if (mounted) {
                                          final success = result['success'] as bool? ?? false;
                                          final token = result['token'] as String?;
                                          final error = result['error'] as String?;
                                          
                                          if (success && token != null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('✅ Token received: ${token.substring(0, 20)}...'),
                                                backgroundColor: Colors.green,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('❌ Failed: ${error ?? "Unknown error"}'),
                                                backgroundColor: Colors.red,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('❌ Error: $e'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.bug_report, size: 18),
                              label: const Text(
                                'Debug Token Request',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Admin Access Permissions
                _buildAdminAccessCard(),

                const SizedBox(height: 20),

                // Status Summary
                _buildConfigStatusCard(configProvider),
                
                const SizedBox(height: 20),
                
                // Token Details
                _buildTokenDetailsCard(configProvider),
                
                const SizedBox(height: 20),
                
                // Raw Config Display
                _buildRawConfigCard(configProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigStatusCard(GlobalConfigProvider configProvider) {
    final status = configProvider.getStatusSummary();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Configuration Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Device Token',
                  status['hasDeviceToken'] as bool,
                  Icons.phone_android,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Auth Token',
                  status['hasAuthToken'] as bool,
                  Icons.lock,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'User ID',
                  status['hasUserId'] as bool,
                  Icons.person,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Notifications',
                  status['notificationsEnabled'] as bool,
                  Icons.notifications,
                ),
              ),
            ],
          ),
          
          if (status['lastSyncAge'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last sync: ${status['lastSyncAge']} minutes ago',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isActive, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive 
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        border: Border.all(
          color: isActive 
              ? Colors.green.withOpacity(0.4)
              : Colors.red.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildTokenDetailsCard(GlobalConfigProvider configProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.token,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Token Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildTokenDetailRow(
            'Device Token',
            configProvider.formatTokenForDisplay(configProvider.deviceToken),
            Icons.phone_android,
            Colors.blue,
          ),
          
          _buildTokenDetailRow(
            'Auth Token',
            configProvider.formatTokenForDisplay(configProvider.authToken),
            Icons.lock,
            Colors.purple,
          ),
          
          _buildTokenDetailRow(
            'User ID',
            configProvider.userId ?? 'Not set',
            Icons.person,
            Colors.green,
          ),
          
          _buildTokenDetailRow(
            'Last Updated',
            configProvider.formatDateForDisplay(configProvider.lastUpdated),
            Icons.update,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTokenDetailRow(String label, String value, IconData icon, Color color) {
    // Determine if this value is copyable (non-empty and not "Not set")
    final bool isCopyable = value.isNotEmpty && value != 'Not set' && !value.startsWith('●');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCopyable) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _copyToClipboard(context, label, _getFullValueForCopy(label, value)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.copy,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getFullValueForCopy(String label, String displayValue) {
    // Get the full token value for copying (not the truncated display version)
    final configProvider = context.read<GlobalConfigProvider>();
    
    switch (label) {
      case 'Device Token':
        return configProvider.deviceToken ?? '';
      case 'Auth Token':
        return configProvider.authToken ?? '';
      case 'User ID':
        return configProvider.userId ?? '';
      case 'Last Updated':
        return configProvider.lastUpdated?.toIso8601String() ?? '';
      default:
        return displayValue;
    }
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    if (value.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: value)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$label copied to clipboard!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Widget _buildRawConfigCard(GlobalConfigProvider configProvider) {
    final configData = configProvider.getConfigForAdmin();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.code,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Raw Configuration Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withOpacity(0.3),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: SelectableText(
              _formatConfigDataForDisplay(configData),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatConfigDataForDisplay(Map<String, dynamic> config) {
    final buffer = StringBuffer();
    config.forEach((key, value) {
      if (value != null) {
        buffer.writeln('$key: $value');
      } else {
        buffer.writeln('$key: null');
      }
    });
    return buffer.toString();
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
    IconData icon,
    Color accentColor, {
    bool showAssignButton = false,
    bool showAssignSongButton = false,
    bool showRegisterButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session['workshop_name'] ?? session['song'] ?? 'Unknown Workshop',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  session['original_by_field'] ?? session['artist_name'] ?? 'Unknown Artist',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                session['date'] ?? 'Unknown Date',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (session['studio_name'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    session['studio_name'],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (session['time'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  session['time'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withOpacity(0.3),
                            accentColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Text(
                        'Missing',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showAssignButton) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignArtistDialog(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF006E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text(
                        'Assign Artist',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                if (showAssignSongButton) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignSongDialog(session),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4081),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.music_note, size: 20),
                      label: const Text(
                        'Assign Song',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                if (showRegisterButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Ensure workshop UUID is available before proceeding
                        // API returns 'workshop_uuid', fallback to 'uuid' for compatibility
                        final workshopUuid = (session['workshop_uuid'] ?? session['uuid'] ?? '').toString();
                        if (workshopUuid.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Workshop information not available'),
                              backgroundColor: Colors.red.withOpacity(0.8),
                            ),
                          );
                          return;
                        }
                        
                        await PaymentLinkUtils.launchPaymentLink(
                          paymentLink: (session['payment_link'] ?? '').toString(),
                          paymentLinkType: (session['payment_link_type'] ?? 'url')?.toString(),
                          context: context,
                          workshopDetails: {
                            'song': (session['song'] ?? '').toString(),
                            'artist': (session['original_by_field'] ?? '').toString(),
                            'studio': (session['studio_name'] ?? '').toString(),
                            'date': (session['date'] ?? '').toString(),
                            'time': (session['time'] ?? '').toString(),
                          },
                          workshopUuid: workshopUuid,
                          workshop: null, // Admin screen doesn't support rewards
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (session['payment_link_type']?.toString().toLowerCase() == 'nachna')
                          ? const Color(0xFF00D4FF)
                          : const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: (session['payment_link_type']?.toString().toLowerCase() == 'nachna') ? 8 : 0,
                        shadowColor: (session['payment_link_type']?.toString().toLowerCase() == 'nachna')
                          ? const Color(0xFF00D4FF).withOpacity(0.5)
                          : null,
                      ),
                      child: Text(
                        (session['payment_link_type']?.toString().toLowerCase() == 'nachna')
                          ? 'Register with nachna'
                          : 'Register',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                          ),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App Insights',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Application statistics and metrics',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLoadingInsights)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFF00D4FF),
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Refresh Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoadingInsights ? null : _loadAppInsights,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Refresh Insights',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Error State
            if (insightsError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text(
                          'Error Loading Insights',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      insightsError!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Insights Cards
            if (appInsights != null) ...[
              // User Statistics
              _buildInsightCard(
                title: 'Total Users',
                value: appInsights!.totalUsers.toString(),
                icon: Icons.people,
                color: const Color(0xFF3B82F6),
                description: 'Registered users in the app',
              ),
              
              const SizedBox(height: 16),
              
              // Engagement Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Total Likes',
                      value: appInsights!.totalLikes.toString(),
                      icon: Icons.favorite,
                      color: const Color(0xFFFF006E),
                      description: 'User-Artist likes',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Total Follows',
                      value: appInsights!.totalFollows.toString(),
                      icon: Icons.notifications_active,
                      color: const Color(0xFF10B981),
                      description: 'User-Artist follows',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Content Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Workshops',
                      value: appInsights!.totalWorkshops.toString(),
                      icon: Icons.event,
                      color: const Color(0xFF8B5CF6),
                      description: 'Total workshops',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Notifications',
                      value: appInsights!.totalNotificationsSent.toString(),
                      icon: Icons.send,
                      color: const Color(0xFFFF8C00),
                      description: 'Notifications sent',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Last Updated
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Last updated: ${_formatDateTime(appInsights!.lastUpdated)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataUpdatesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                  ),
                  child: const Icon(Icons.data_object, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Data updates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Add Artist button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddArtistDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text(
                'Add artist',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddArtistDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController aliasesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                              ),
                            ),
                            child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Artist ID field
                      TextField(
                        controller: idController,
                        decoration: InputDecoration(
                          labelText: 'Artist ID',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
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
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),

                      // Artist Name field
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Artist name',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
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
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 12),

                      // Artist Aliases field
                      TextField(
                        controller: aliasesController,
                        decoration: InputDecoration(
                          labelText: 'Artist aliases (comma separated)',
                          hintText: 'e.g., aadil, ak, khan',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
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
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final id = idController.text.trim();
                                final name = nameController.text.trim();
                                final aliasesText = aliasesController.text.trim();

                                // Parse aliases from comma-separated string
                                final List<String> aliases = aliasesText.isEmpty
                                    ? []
                                    : aliasesText
                                        .split(',')
                                        .map((s) => s.trim().toLowerCase())
                                        .where((s) => s.isNotEmpty)
                                        .toList();

                                if (id.isEmpty || name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter both artist ID and name'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final ok = await AdminService.addArtist(
                                    artistId: id,
                                    artistName: name,
                                    artistAliases: aliases,
                                  );
                                  if (!mounted) return;

                                  if (ok) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Artist added successfully'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to add artist'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
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
          width: ResponsiveUtils.borderWidthMedium(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: ResponsiveUtils.paddingMedium(context),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                  color: color.withOpacity(0.2),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: ResponsiveUtils.iconMedium(context),
                ),
              ),
              SizedBox(width: ResponsiveUtils.spacingMedium(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: ResponsiveUtils.caption(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.h2(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingMedium(context)),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: ResponsiveUtils.micro(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _APNsTestWidget() {
    return _APNsTestForm();
  }

  Widget _APNsTestForm() {
    return StatefulBuilder(
      builder: (context, setState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Token Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Token',
        style: TextStyle(
                      color: Colors.white,
          fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _deviceTokenController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Enter device token or use current device token',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final notificationService = NotificationService();
                          final currentToken = notificationService.deviceToken;
                          if (currentToken != null) {
                            setState(() {
                              _deviceTokenController.text = currentToken;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No device token available. Make sure notifications are enabled.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Use Current', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Title Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Title',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter notification title',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Body Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Body',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bodyController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter notification message',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isTestNotificationLoading ? null : () async {
                    final deviceToken = _deviceTokenController.text.trim();
                    final title = _titleController.text.trim();
                    final body = _bodyController.text.trim();
                    
                    if (deviceToken.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a device token'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a notification title'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (body.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a notification body'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _isTestNotificationLoading = true;
                    });
                    
                    try {
                      final success = await AdminService.sendTestNotification(
                        deviceToken: deviceToken,
                        title: title,
                        body: body,
                      );
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Test notification sent successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        
                        // Clear the form
                        setState(() {
                          _deviceTokenController.clear();
                          _titleController.clear();
                          _bodyController.clear();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Failed to send test notification'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isTestNotificationLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isTestNotificationLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send Test Notification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ArtistNotificationTestWidget({required List<Artist> allArtists}) {
    return StatefulBuilder(
      builder: (context, setState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artist Selection Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Artist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedArtistId,
                        hint: Text(
                          allArtists.isEmpty 
                              ? 'No artists available' 
                              : 'Choose an artist (${allArtists.length} available)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Colors.white),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        isExpanded: true,
                        items: allArtists.map((Artist artist) {
                          return DropdownMenuItem<String>(
                            value: artist.id,
      child: Text(
                              artist.name,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: allArtists.isEmpty ? null : (String? newValue) {
                          setState(() {
                            _selectedArtistId = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Title Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Title (Optional)',
                    style: TextStyle(
                      color: Colors.white,
          fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _artistTitleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Leave empty for default title',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Body Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Body (Optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _artistBodyController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Leave empty for default message',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isArtistNotificationLoading || _selectedArtistId == null) ? null : () async {
                    if (_selectedArtistId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an artist'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _isArtistNotificationLoading = true;
                    });
                    
                    try {
                      final success = await AdminService.sendTestArtistNotification(_selectedArtistId!);
                      
                      if (success) {
                        final selectedArtist = allArtists.firstWhere(
                          (artist) => artist.id == _selectedArtistId,
                          orElse: () => Artist(
                            id: _selectedArtistId!, 
                            name: 'Selected Artist',
                            instagramLink: '',
                          ),
                        );
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Test notification sent to followers of ${selectedArtist.name}!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        
                        // Clear the form
                        setState(() {
                          _selectedArtistId = null;
                          _artistTitleController.clear();
                          _artistBodyController.clear();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Failed to send test artist notification'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isArtistNotificationLoading = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isArtistNotificationLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _selectedArtistId == null 
                              ? 'Select an Artist First'
                              : 'Send Test Artist Notification',
        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              // Info Text
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will send notifications to all users who follow the selected artist and have notifications enabled.',
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  /// Load workshops with missing Instagram links
  Future<void> _loadMissingInstagramLinks() async {
    setState(() {
      isLoadingInstagramLinks = true;
      instagramLinksError = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('https://nachna.com/admin/api/workshops/missing-instagram-links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            missingInstagramLinkWorkshops = data.cast<Map<String, dynamic>>();
            _initializeInstagramFilters();
            _applyInstagramFilters();
          });
        }
      } else {
        throw Exception('Failed to load workshops missing Instagram links (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          instagramLinksError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInstagramLinks = false;
        });
      }
    }
  }

  void _initializeInstagramFilters() {
    final names = <String>{};
    for (final w in missingInstagramLinkWorkshops) {
      final by = (w['by'] ?? '').toString().trim();
      if (by.isNotEmpty && by.toLowerCase() != 'tba') {
        names.add(by);
      }
    }
    availableByFilters = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void _applyInstagramFilters() {
    if (selectedByFilters.isEmpty) {
      filteredInstagramLinkWorkshops = List<Map<String, dynamic>>.from(missingInstagramLinkWorkshops);
    } else {
      filteredInstagramLinkWorkshops = missingInstagramLinkWorkshops.where((w) {
        final by = (w['by'] ?? '').toString();
        return selectedByFilters.contains(by);
      }).toList();
    }
  }

  Future<void> _showByFilterDialog() async {
    List<String> tempSelected = List.from(selectedByFilters);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: ResponsiveUtils.screenHeight(context) * 0.7,
              maxWidth: ResponsiveUtils.screenWidth(context) * 0.9,
            ),
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
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Padding(
                    padding: ResponsiveUtils.paddingXLarge(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacingSmall(context)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                            color: const Color(0xFFFF006E).withOpacity(0.2),
                          ),
                          child: Icon(Icons.filter_list_rounded, color: const Color(0xFFFF006E), size: ResponsiveUtils.iconSmall(context)),
                        ),
                        SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                        Text(
                          'Filter by Artist (by)',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.h3(context),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                        SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableByFilters.length,
                            itemBuilder: (context, index) {
                              final option = availableByFilters[index];
                              final isSelected = tempSelected.contains(option);
                              return Container(
                                margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                  color: isSelected ? const Color(0xFFFF006E).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFFF006E).withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: CheckboxListTile(
                                  title: Text(option, style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.body2(context))),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        tempSelected.add(option);
                                      } else {
                                        tempSelected.remove(option);
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                  checkColor: Colors.white,
                                  activeColor: const Color(0xFFFF006E),
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: ResponsiveUtils.body2(context))),
                                ),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                  gradient: const LinearGradient(colors: [Color(0xFFFF006E), Color(0xFF8338EC)]),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedByFilters = tempSelected;
                                      _applyInstagramFilters();
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: ResponsiveUtils.body2(context))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildByFilterChip() {
    final count = selectedByFilters.length;
    return GestureDetector(
      onTap: availableByFilters.isEmpty ? null : _showByFilterDialog,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context),
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF006E).withOpacity(count > 0 ? 0.2 : 0.1),
              const Color(0xFF8338EC).withOpacity(count > 0 ? 0.1 : 0.05),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFF006E).withOpacity(count > 0 ? 0.5 : 0.2),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: ResponsiveUtils.iconXSmall(context), color: const Color(0xFFFF006E)),
            SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
            Text(
              count > 0 ? 'Artist (by) ($count)' : 'Artist (by)',
              style: TextStyle(
                color: count > 0 ? const Color(0xFFFF006E) : Colors.white70,
                fontSize: ResponsiveUtils.micro(context),
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildByResetButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedByFilters.clear();
          _applyInstagramFilters();
        });
      },
      child: Container(
        padding: ResponsiveUtils.paddingSmall(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
          gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
        ),
        child: Icon(Icons.clear_rounded, color: Colors.white, size: ResponsiveUtils.iconSmall(context)),
      ),
    );
  }

  /// Update Instagram link for a workshop
  Future<void> _updateInstagramLink(String workshopId, String instagramLink) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

              final response = await http.put(
          Uri.parse('https://nachna.com/admin/api/workshops/$workshopId/instagram-link'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'choreo_insta_link': instagramLink,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Instagram link updated successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh the list
          _loadMissingInstagramLinks();
        }
      } else {
        throw Exception('Failed to update Instagram link (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Build Instagram Links tab
  Widget _buildInstagramLinksTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter row
          Row(
            children: [
              _buildByFilterChip(),
              if (selectedByFilters.isNotEmpty) ...[
                SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                _buildByResetButton(),
              ],
            ],
          ),
          SizedBox(height: ResponsiveUtils.spacingSmall(context)),
          if (isLoadingInstagramLinks)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else if (instagramLinksError != null)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading Instagram links',
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        instagramLinksError!,
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.7),
          fontSize: 14,
        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMissingInstagramLinks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (missingInstagramLinkWorkshops.isEmpty)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.1),
                        Colors.green.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All workshops have Instagram links!',
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No workshops are missing Instagram links.',
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filteredInstagramLinkWorkshops.length,
                itemBuilder: (context, index) {
                  final workshop = filteredInstagramLinkWorkshops[index];
                  return _buildInstagramLinkWorkshopCard(workshop);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Build individual workshop card for Instagram links
  Widget _buildInstagramLinkWorkshopCard(Map<String, dynamic> workshop) {
    return _InstagramLinkWorkshopCard(
      workshop: workshop,
      onUpdateInstagramLink: _updateInstagramLink,
      onLaunchInstagramUrl: _launchInstagramUrl,
    );
  }

  /// Launch Instagram URL
  Future<void> _launchInstagramUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open Instagram: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build QR Scanner tab
  Widget _buildQRScannerTab() {
    return const QRScannerWidget();
  }

  /// Load workshop registrations
  Future<void> _loadWorkshopRegistrations() async {
    if (mounted) {
      setState(() {
        isLoadingRegistrations = true;
        registrationsError = null;
      });
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No authentication token');

      final response = await http.get(
        Uri.parse('https://nachna.com/admin/api/workshop-registrations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final registrations = List<Map<String, dynamic>>.from(data['registrations'] ?? []);

        // Extract unique artists, songs, and studios for filters
        final artists = <String>{};
        final songs = <String>{};
        final studios = <String>{};

        for (final registration in registrations) {
          if (registration['artist_name'] != null && registration['artist_name'].toString().isNotEmpty) {
            artists.add(registration['artist_name']);
          }
          if (registration['workshop_song'] != null && registration['workshop_song'].toString().isNotEmpty) {
            songs.add(registration['workshop_song']);
          }
          if (registration['studio_name'] != null && registration['studio_name'].toString().isNotEmpty) {
            studios.add(registration['studio_name']);
          }
        }

        if (mounted) {
          setState(() {
            workshopRegistrations = registrations;
            availableArtists = artists.toList()..sort();
            availableSongs = songs.toList()..sort();
            availableStudios = studios.toList()..sort();
            _applyRegistrationFilters();
          });
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to load workshop registrations (Error ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          registrationsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRegistrations = false;
        });
      }
    }
  }

  /// Apply filters to registrations
  void _applyRegistrationFilters() {
    filteredRegistrations = workshopRegistrations.where((registration) {
      // Artist filter
      if (selectedArtistFilter != null && registration['artist_name'] != selectedArtistFilter) {
        return false;
      }

      // Song filter
      if (selectedSongFilter != null && registration['workshop_song'] != selectedSongFilter) {
        return false;
      }

      // Studio filter
      if (selectedStudioFilter != null && registration['studio_name'] != selectedStudioFilter) {
        return false;
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final name = (registration['name'] ?? '').toString().toLowerCase();
        final phone = (registration['phone'] ?? '').toString();

        if (!name.contains(query) && !phone.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Build Registrations List tab
  Widget _buildRegistrationsListTab() {
    return CustomScrollView(
      slivers: [
        // Filters Section
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters Row
                Column(
                  children: [
                    // First Row: Artist and Song Filters
                    Row(
                      children: [
                        // Artist Filter
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedArtistFilter,
                                hint: Text(
                                  'All Artists',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF1A1A2E),
                                style: const TextStyle(color: Colors.white),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'All Artists',
                                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ),
                                  ...availableArtists.map((artist) {
                                    return DropdownMenuItem<String>(
                                      value: artist,
                                      child: Text(
                                        artist,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedArtistFilter = value;
                                    _applyRegistrationFilters();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        // Song Filter
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedSongFilter,
                                hint: Text(
                                  'All Songs',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF1A1A2E),
                                style: const TextStyle(color: Colors.white),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'All Songs',
                                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ),
                                  ...availableSongs.map((song) {
                                    return DropdownMenuItem<String>(
                                      value: song,
                                      child: Text(
                                        song,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedSongFilter = value;
                                    _applyRegistrationFilters();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Second Row: Studio Filter
                    Row(
                      children: [
                        // Studio Filter
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedStudioFilter,
                                hint: Text(
                                  'All Studios',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                dropdownColor: const Color(0xFF1A1A2E),
                                style: const TextStyle(color: Colors.white),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'All Studios',
                                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ),
                                  ...availableStudios.map((studio) {
                                    return DropdownMenuItem<String>(
                                      value: studio,
                                      child: Text(
                                        studio,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedStudioFilter = value;
                                    _applyRegistrationFilters();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        // Clear Filters Button
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                selectedArtistFilter = null;
                                selectedSongFilter = null;
                                selectedStudioFilter = null;
                                searchQuery = '';
                                _applyRegistrationFilters();
                              });
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Compact Search and Actions Row
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withOpacity(0.5),
                              size: 16,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                              _applyRegistrationFilters();
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Clear Button
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedArtistFilter = null;
                          selectedSongFilter = null;
                          selectedStudioFilter = null;
                          searchQuery = '';
                          _applyRegistrationFilters();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 11)),
                    ),

                    const SizedBox(width: 6),

                    // Refresh Button
                    ElevatedButton(
                      onPressed: isLoadingRegistrations ? null : _loadWorkshopRegistrations,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(70, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Refresh', style: TextStyle(fontSize: 11)),
                    ),

                    const SizedBox(width: 6),

                    // CSV Export Button
                    ElevatedButton(
                      onPressed: (filteredRegistrations.isEmpty || _isExportingCSV) ? null : _exportRegistrationsToCSV,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(80, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _isExportingCSV
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Export', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Summary Statistics
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Summary Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (selectedArtistFilter != null || selectedSongFilter != null || selectedStudioFilter != null || searchQuery.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF00D4FF).withOpacity(0.2),
                              border: Border.all(
                                color: const Color(0xFF00D4FF).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Filtered',
                              style: TextStyle(
                                color: const Color(0xFF00D4FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRegistrationSummary(),
                  ],
                ),

                const SizedBox(height: 16),

                // Results Count
                Text(
                  '${filteredRegistrations.length} registrations found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Loading State
        if (isLoadingRegistrations)
          SliverToBoxAdapter(
            child: Container(
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4081)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          )

        // Error State
        else if (registrationsError != null)
          SliverToBoxAdapter(
            child: Container(
              height: 300,
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading registrations',
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        registrationsError!,
                        style: TextStyle(
                          color: Colors.red.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWorkshopRegistrations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )

        // Empty State
        else if (filteredRegistrations.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              height: 300,
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        color: Colors.orange,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No registrations found',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or refresh the data.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )

        // Registrations List
        else
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final registration = filteredRegistrations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRegistrationCard(registration),
                  );
                },
                childCount: filteredRegistrations.length,
              ),
            ),
          ),
      ],
    );
  }

  /// Build individual registration card
  Widget _buildRegistrationCard(Map<String, dynamic> registration) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and phone
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registration['name'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registration['phone'] ?? 'N/A',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.3),
                        const Color(0xFF10B981).withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '₹${(registration['final_amount'] ?? 0).toString()}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Workshop Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  _buildRegistrationDetailRow(
                    Icons.person,
                    'Artist',
                    registration['artist_name'] ?? 'N/A',
                    const Color(0xFFFF006E),
                  ),
                  const SizedBox(height: 8),
                  _buildRegistrationDetailRow(
                    Icons.music_note,
                    'Song',
                    registration['workshop_song'] ?? 'N/A',
                    const Color(0xFFFF4081),
                  ),
                  const SizedBox(height: 8),
                  _buildRegistrationDetailRow(
                    Icons.business,
                    'Studio',
                    registration['studio_name'] ?? 'N/A',
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _buildRegistrationDetailRow(
                    Icons.calendar_today,
                    'Date',
                    registration['workshop_date'] ?? 'N/A',
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 8),
                  _buildRegistrationDetailRow(
                    Icons.access_time,
                    'Time',
                    registration['workshop_time'] ?? 'N/A',
                    const Color(0xFF00D4FF),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build registration detail row
  Widget _buildRegistrationDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build Registration Summary
  Widget _buildRegistrationSummary() {
    // Show statistics for current filtered results (or all if no filters applied)
    final hasActiveFilters = selectedArtistFilter != null ||
                            selectedSongFilter != null ||
                            selectedStudioFilter != null ||
                            searchQuery.isNotEmpty;

    final dataToShow = hasActiveFilters ? filteredRegistrations : workshopRegistrations;
    final totalRegistrations = dataToShow.length;
    final totalRevenue = dataToShow.fold<double>(0.0, (sum, reg) => sum + ((reg['final_amount'] as num?)?.toDouble() ?? 0.0)).toInt();
    final uniqueUsers = Set.from(dataToShow.map((reg) => reg['phone'])).length;
    final uniqueWorkshops = Set.from(dataToShow.map((reg) => '${reg['artist_name']}-${reg['workshop_song']}-${reg['workshop_date']}')).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Total Registrations
          Expanded(
            child: _buildSummaryStatCard(
              value: totalRegistrations.toString(),
              label: 'Total Registrations',
              icon: Icons.people,
              color: const Color(0xFF00D4FF),
            ),
          ),

          // Total Revenue
          Expanded(
            child: _buildSummaryStatCard(
              value: '₹${_formatNumber(totalRevenue)}',
              label: 'Total Revenue',
              icon: Icons.attach_money,
              color: const Color(0xFF10B981),
            ),
          ),

          // Unique Users
          Expanded(
            child: _buildSummaryStatCard(
              value: uniqueUsers.toString(),
              label: 'Unique Users',
              icon: Icons.person_outline,
              color: const Color(0xFFFF006E),
            ),
          ),

          // Workshops
          Expanded(
            child: _buildSummaryStatCard(
              value: uniqueWorkshops.toString(),
              label: 'Workshops',
              icon: Icons.event,
              color: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual summary stat card
  Widget _buildSummaryStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build Admin Access Permissions Card
  Widget _buildAdminAccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Admin Access Permissions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Access Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _adminAccessList.isEmpty
                ? Colors.red.withOpacity(0.1)
                : _adminAccessList.contains('all')
                  ? Colors.green.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              border: Border.all(
                color: _adminAccessList.isEmpty
                  ? Colors.red.withOpacity(0.3)
                  : _adminAccessList.contains('all')
                    ? Colors.green.withOpacity(0.3)
                    : Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _adminAccessList.isEmpty
                    ? Icons.block
                    : _adminAccessList.contains('all')
                      ? Icons.check_circle
                      : Icons.info,
                  color: _adminAccessList.isEmpty
                    ? Colors.red
                    : _adminAccessList.contains('all')
                      ? Colors.green
                      : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminAccessList.isEmpty
                          ? 'No Admin Access'
                          : _adminAccessList.contains('all')
                            ? 'Full Admin Access'
                            : 'Limited Admin Access',
                        style: TextStyle(
                          color: _adminAccessList.isEmpty
                            ? Colors.red
                            : _adminAccessList.contains('all')
                              ? Colors.green
                              : Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _adminAccessList.isEmpty
                          ? 'You do not have any admin permissions.'
                          : _adminAccessList.contains('all')
                            ? 'You have access to all admin features.'
                            : 'You have limited admin access.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_adminAccessList.isNotEmpty && !_adminAccessList.contains('all')) ...[
            const SizedBox(height: 16),
            const Text(
              'Granted Permissions:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _adminAccessList.map((permission) {
                final tabInfo = _allTabs.firstWhere(
                  (tab) => tab['key'] == permission,
                  orElse: () => {'title': permission, 'icon': Icons.settings},
                );
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D4FF).withOpacity(0.2),
                        const Color(0xFF9C27B0).withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabInfo['icon'] as IconData? ?? Icons.settings,
                        color: const Color(0xFF00D4FF),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabInfo['title'] as String? ?? permission,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Format number with commas for display
  String _formatNumber(int number) {
    final String numStr = number.toString();
    final StringBuffer result = StringBuffer();

    for (int i = 0; i < numStr.length; i++) {
      if (i > 0 && (numStr.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(numStr[i]);
    }

    return result.toString();
  }

  /// Export registrations to CSV
  Future<void> _exportRegistrationsToCSV() async {
    try {
      // Show loading indicator
      setState(() => _isExportingCSV = true);

      // Get data to export (filtered or all)
      final hasActiveFilters = selectedArtistFilter != null ||
                              selectedSongFilter != null ||
                              selectedStudioFilter != null ||
                              searchQuery.isNotEmpty;
      final dataToExport = hasActiveFilters ? filteredRegistrations : workshopRegistrations;

      if (dataToExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data to export'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Create CSV content
      final headers = ['Name', 'Phone', 'Final Amount', 'Artist Name', 'Workshop Song', 'Workshop Date', 'Workshop Time', 'Studio Name'];
      final csvRows = dataToExport.map((registration) => [
        '"${(registration['name'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['phone'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['final_amount'] ?? 0).toString().replaceAll('"', '""')}"',
        '"${(registration['artist_name'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['workshop_song'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['workshop_date'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['workshop_time'] ?? '').toString().replaceAll('"', '""')}"',
        '"${(registration['studio_name'] ?? '').toString().replaceAll('"', '""')}"',
      ]);

      final csvContent = [headers.join(','), ...csvRows.map((row) => row.join(','))].join('\n');

      // Create temporary file
      final directory = await getTemporaryDirectory();
      final fileName = 'workshop_registrations_${DateTime.now().toIso8601String().split('T')[0]}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Workshop Registrations Export',
        subject: 'Workshop Registrations CSV',
        sharePositionOrigin: Rect.fromLTWH(100, 100, 200, 50), // Valid rectangle within screen bounds
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ CSV exported successfully (${dataToExport.length} records)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to export CSV: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingCSV = false);
      }
    }
  }
}

class _InstagramLinkWorkshopCard extends StatefulWidget {
  final Map<String, dynamic> workshop;
  final Function(String, String) onUpdateInstagramLink;
  final Function(String) onLaunchInstagramUrl;

  const _InstagramLinkWorkshopCard({
    super.key,
    required this.workshop,
    required this.onUpdateInstagramLink,
    required this.onLaunchInstagramUrl,
  });

  @override
  State<_InstagramLinkWorkshopCard> createState() => _InstagramLinkWorkshopCardState();
}

class _InstagramLinkWorkshopCardState extends State<_InstagramLinkWorkshopCard> {
  final TextEditingController linkController = TextEditingController();
  Map<String, List<Map<String, dynamic>>> choreoLinksByArtist = {};
  Map<String, String> artistNames = {};
  bool isLoadingChoreoLinks = false;
  String? selectedChoreoLink;

  @override
  void initState() {
    super.initState();
    _loadChoreoLinksForArtists();
    linkController.addListener(() {
      setState(() {}); // Rebuild when text changes to show/hide preview button
    });
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  Future<void> _loadChoreoLinksForArtists() async {
    final artistIdList = widget.workshop['artist_id_list'] as List<dynamic>?;
    if (artistIdList == null || artistIdList.isEmpty) return;

    setState(() {
      isLoadingChoreoLinks = true;
    });

    Map<String, List<Map<String, dynamic>>> groupedLinks = {};

    for (String artistId in artistIdList) {
      if (artistId.isNotEmpty && artistId != 'TBA' && artistId != 'tba') {
        try {
          final links = await AdminService.getArtistChoreoLinks(artistId);

          // Only include links that actually belong to this specific artist
          final artistSpecificLinks = links.where((link) {
            final linkArtistIds = link['artist_id_list'] as List<dynamic>?;
            return linkArtistIds != null && linkArtistIds.contains(artistId);
          }).toList();

          if (artistSpecificLinks.isNotEmpty) {
            groupedLinks[artistId] = artistSpecificLinks;

            // Get artist name from workshop 'by' field or artist_id
            final byField = widget.workshop['by']?.toString() ?? '';
            artistNames[artistId] = byField.isNotEmpty && byField != 'TBA'
                ? byField
                : artistId;
          }
        } catch (e) {
          print('Error loading choreo links for artist $artistId: $e');
        }
      }
    }

    setState(() {
      choreoLinksByArtist = groupedLinks;
      isLoadingChoreoLinks = false;
    });
  }

  void _selectChoreoLink(String url) {
    setState(() {
      selectedChoreoLink = url;
      linkController.text = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingLarge(context)),
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
          width: ResponsiveUtils.borderWidthMedium(context),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: ResponsiveUtils.paddingXLarge(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workshop Info
                Row(
                  children: [
                    Container(
                      padding: ResponsiveUtils.paddingMedium(context),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                        ),
                      ),
                      child: Icon(
                        Icons.link,
                        color: Colors.white,
                        size: ResponsiveUtils.iconMedium(context),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.workshop['workshop_name'] ?? widget.workshop['song'] ?? 'Unknown Workshop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.body1(context),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                          Text(
                            'By: ${widget.workshop['by'] ?? 'Unknown Artist'}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: ResponsiveUtils.caption(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                
                // Existing Choreo Links Grouped by Artist
                if (choreoLinksByArtist.isNotEmpty) ...[
                  Text(
                    'Existing Choreo Links (tap to select):',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.caption(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacingSmall(context)),

                  // Display links grouped by artist
                  ...choreoLinksByArtist.entries.map((entry) {
                    final artistId = entry.key;
                    final links = entry.value;
                    final artistName = artistNames[artistId] ?? artistId;

                    return Container(
                      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: ResponsiveUtils.borderWidthThin(context),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.white.withOpacity(0.1),
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacingMedium(context),
                            vertical: ResponsiveUtils.spacingXSmall(context),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: const Color(0xFF00D4FF),
                                size: ResponsiveUtils.iconSmall(context),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                              Expanded(
                                child: Text(
                                  artistName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.caption(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacingSmall(context),
                                  vertical: ResponsiveUtils.spacingXSmall(context) / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                ),
                                child: Text(
                                  '${links.length}',
                                  style: TextStyle(
                                    color: const Color(0xFF00D4FF),
                                    fontSize: ResponsiveUtils.micro(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          iconColor: Colors.white.withOpacity(0.7),
                          collapsedIconColor: Colors.white.withOpacity(0.7),
                          children: links.map((link) {
                            final url = link['url'] as String;
                            final song = link['song'] as String? ?? 'Unknown Song';
                            final isSelected = selectedChoreoLink == url;

                            return InkWell(
                              onTap: () => _selectChoreoLink(url),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.spacingLarge(context),
                                  vertical: ResponsiveUtils.spacingMedium(context),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00D4FF).withOpacity(0.15)
                                      : Colors.transparent,
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withOpacity(0.05),
                                      width: ResponsiveUtils.borderWidthThin(context),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: const Color(0xFF00D4FF),
                                        size: ResponsiveUtils.iconSmall(context),
                                      )
                                    else
                                      Icon(
                                        Icons.link,
                                        color: Colors.white.withOpacity(0.5),
                                        size: ResponsiveUtils.iconSmall(context),
                                      ),
                                    SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFF00D4FF)
                                                  : Colors.white,
                                              fontSize: ResponsiveUtils.micro(context),
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: ResponsiveUtils.spacingXSmall(context) / 2),
                                          Text(
                                            url,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: ResponsiveUtils.micro(context) * 0.85,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }).toList(),

                  SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                ],
                
                // Artist Instagram Link Button
                if (widget.workshop['artist_instagram_links'] != null && 
                    (widget.workshop['artist_instagram_links'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Artist Instagram:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.caption(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                      Wrap(
                        spacing: ResponsiveUtils.spacingSmall(context),
                        runSpacing: ResponsiveUtils.spacingSmall(context),
                        children: (widget.workshop['artist_instagram_links'] as List).map<Widget>((link) {
                          return ElevatedButton.icon(
                            onPressed: () => widget.onLaunchInstagramUrl(link.toString()),
                            icon: Icon(Icons.open_in_new, size: ResponsiveUtils.iconXSmall(context)),
                            label: Text(
                              'Open Artist IG',
                              style: TextStyle(fontSize: ResponsiveUtils.micro(context)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE1306C),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacingMedium(context), 
                                vertical: ResponsiveUtils.spacingSmall(context)
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXLarge(context)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                    ],
                  ),
                
                // Instagram Link Input
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: linkController,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.caption(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Paste Instagram link here...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: ResponsiveUtils.caption(context),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                            borderSide: BorderSide(
                              color: const Color(0xFFE91E63), 
                              width: ResponsiveUtils.borderWidthMedium(context)
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacingLarge(context), 
                            vertical: ResponsiveUtils.spacingMedium(context)
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    
                    // Preview Instagram Button (if link is pasted)
                    if (linkController.text.trim().isNotEmpty)
                      ElevatedButton(
                        onPressed: () => widget.onLaunchInstagramUrl(linkController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE1306C),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacingLarge(context), 
                            vertical: ResponsiveUtils.spacingMedium(context)
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                          ),
                        ),
                        child: Icon(Icons.open_in_new, size: ResponsiveUtils.iconSmall(context)),
                      ),
                    
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    
                    // Paste Button
                    ElevatedButton(
                      onPressed: () async {
                        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                        if (clipboardData?.text != null) {
                          setState(() {
                            linkController.text = clipboardData!.text!;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacingLarge(context), 
                          vertical: ResponsiveUtils.spacingMedium(context)
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                        ),
                      ),
                      child: Icon(Icons.paste, size: ResponsiveUtils.iconSmall(context)),
                    ),
                    
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: () {
                        if (linkController.text.trim().isNotEmpty) {
                          widget.onUpdateInstagramLink(widget.workshop['workshop_id'], linkController.text.trim());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please enter an Instagram link'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacingLarge(context), 
                          vertical: ResponsiveUtils.spacingMedium(context)
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                        ),
                      ),
                      child: Icon(Icons.check, size: ResponsiveUtils.iconSmall(context)),
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
}

class _AssignArtistDialog extends StatefulWidget {
  final Map<String, dynamic> session;
  final List<Artist> allArtists;
  final Function(String, List<Artist>) onAssignArtist;

  const _AssignArtistDialog({
    required this.session,
    required this.allArtists,
    required this.onAssignArtist,
  });

  @override
  State<_AssignArtistDialog> createState() => _AssignArtistDialogState();
}

class _AssignArtistDialogState extends State<_AssignArtistDialog> {
  List<String> selectedArtistIds = [];
  List<Artist> selectedArtists = [];

  // Get suggested artists based on original_by_field
  List<Artist> get suggestedArtists {
    final originalByField = widget.session['original_by_field'] ?? '';
    if (originalByField.isEmpty) return [];
    
    final firstLetter = originalByField[0].toUpperCase();
    return widget.allArtists
        .where((artist) => artist.name.isNotEmpty && artist.name[0].toUpperCase() == firstLetter)
        .toList();
  }

  // Get the original artist name for display
  String get originalArtistName {
    return widget.session['original_by_field'] ?? 'Unknown Artist';
  }

  // Get regular artists (excluding suggested ones)
  List<Artist> get regularArtists {
    final suggestedIds = suggestedArtists.map((artist) => artist.id).toSet();
    return widget.allArtists
        .where((artist) => !suggestedIds.contains(artist.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
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
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Artist',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select artists for this workshop',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Artist List with Suggested and Regular sections
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Suggested Artists Section
                      if (suggestedArtists.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: const Color(0xFFFFD700),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Suggested Artists',
                                style: TextStyle(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${suggestedArtists.length}',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Based on original artist: $originalArtistName',
                            style: TextStyle(
                              color: const Color(0xFFFFD700),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        ...suggestedArtists.map((artist) {
                      final isSelected = selectedArtistIds.contains(artist.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected 
                                  ? const Color(0xFFFFD700).withOpacity(0.3)
                                  : const Color(0xFFFFD700).withOpacity(0.1),
                              border: Border.all(
                                color: isSelected 
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFFFD700).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFFD700),
                                child: Text(
                                  artist.name.isNotEmpty ? artist.name[0].toUpperCase() : 'A',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                artist.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFFFFD700),
                                    )
                                  : const Icon(
                                      Icons.circle_outlined,
                                      color: Color(0xFFFFD700),
                                    ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    selectedArtistIds.remove(artist.id);
                                    selectedArtists.removeWhere((a) => a.id == artist.id);
                                  } else {
                                    selectedArtistIds.add(artist.id);
                                    selectedArtists.add(artist);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                      ] else ...[
                        // No suggested artists message
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No suggested artists found for "$originalArtistName"',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Regular Artists Section
                      if (regularArtists.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'All Artists',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${regularArtists.length}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...regularArtists.map((artist) {
                          final isSelected = selectedArtistIds.contains(artist.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF00D4FF)
                                : Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF00D4FF),
                            child: Text(
                              artist.name.isNotEmpty ? artist.name[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            artist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF00D4FF),
                                )
                              : const Icon(
                                  Icons.circle_outlined,
                                  color: Colors.white54,
                                ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedArtistIds.remove(artist.id);
                                selectedArtists.removeWhere((a) => a.id == artist.id);
                              } else {
                                selectedArtistIds.add(artist.id);
                                selectedArtists.add(artist);
                              }
                            });
                          },
                        ),
                      );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
                
                // Assign Button
                if (selectedArtistIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onAssignArtist(widget.session['workshop_uuid'], selectedArtists);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF006E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Assign ${selectedArtistIds.length} Artist${selectedArtistIds.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
  }

} 