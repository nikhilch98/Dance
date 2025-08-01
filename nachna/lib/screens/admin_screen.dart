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
import 'package:nachna/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../services/first_launch_service.dart';
import '../services/admin_service.dart';
import '../models/app_insights.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/responsive_utils.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
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
  bool isLoadingInstagramLinks = false;
  String? instagramLinksError;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadMissingArtistSessions();
    _loadMissingSongSessions();
    _loadAllArtists();
    _loadAppInsights();
    _loadMissingInstagramLinks();
    // Initialize the global config provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GlobalConfigProvider>().initialize();
    });
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
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.h3(context),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
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
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note, size: 18),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'Songs',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (missingSongSessions.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: Text(
                                    '${missingSongSessions.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person, size: 18),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'Artists',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (missingArtistSessions.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: Text(
                                    '${missingArtistSessions.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Notifications',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Config',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Instagram Links',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.analytics, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Insights',
                                  overflow: TextOverflow.ellipsis,
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
              
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMissingSongsTab(),
                    _buildMissingArtistsTab(),
                    _buildNotificationsTab(),
                    _buildConfigTab(),
                    _buildInstagramLinksTab(),
                    _buildInsightsTab(),
                  ],
                ),
              ),
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
                  return _buildSessionCard(session, Icons.music_note, const Color(0xFFFF4081), showAssignSongButton: true);
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
                  return _buildSessionCard(session, Icons.person, const Color(0xFFFF006E), showAssignButton: true);
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

  Widget _buildSessionCard(Map<String, dynamic> session, IconData icon, Color accentColor, {bool showAssignButton = false, bool showAssignSongButton = false}) {
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
                itemCount: missingInstagramLinkWorkshops.length,
                itemBuilder: (context, index) {
                  final workshop = missingInstagramLinkWorkshops[index];
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
  List<Map<String, dynamic>> choreoLinks = [];
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

    List<Map<String, dynamic>> allChoreoLinks = [];

    for (String artistId in artistIdList) {
      if (artistId.isNotEmpty && artistId != 'TBA' && artistId != 'tba') {
        try {
          final links = await AdminService.getArtistChoreoLinks(artistId);
          allChoreoLinks.addAll(links);
        } catch (e) {
          print('Error loading choreo links for artist $artistId: $e');
        }
      }
    }

    // Remove duplicates based on URL
    final uniqueLinks = <String, Map<String, dynamic>>{};
    for (final link in allChoreoLinks) {
      final url = link['url'] as String;
      if (!uniqueLinks.containsKey(url)) {
        uniqueLinks[url] = link;
      }
    }

    setState(() {
      choreoLinks = uniqueLinks.values.toList();
      isLoadingChoreoLinks = false;
    });
  }

  void _selectChoreoLink(String? url) {
    if (url != null) {
      setState(() {
        selectedChoreoLink = url;
        linkController.text = url;
      });
    }
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
                
                // Existing Choreo Links Dropdown
                if (choreoLinks.isNotEmpty) ...[
                  Text(
                    'Existing Choreo Links for this Artist:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.caption(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacingMedium(context), 
                      vertical: ResponsiveUtils.spacingXSmall(context)
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: ResponsiveUtils.borderWidthThin(context),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedChoreoLink,
                        hint: Text(
                          isLoadingChoreoLinks 
                              ? 'Loading choreo links...' 
                              : 'Select existing choreo link',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: ResponsiveUtils.caption(context),
                          ),
                        ),
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: ResponsiveUtils.caption(context)
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        isExpanded: true,
                        items: choreoLinks.map((Map<String, dynamic> choreoLink) {
                          return DropdownMenuItem<String>(
                            value: choreoLink['url'],
                            child: Text(
                              choreoLink['display_text'] ?? choreoLink['url'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.micro(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: isLoadingChoreoLinks ? null : _selectChoreoLink,
                      ),
                    ),
                  ),
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
                
                // Artist List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: widget.allArtists.length,
                    itemBuilder: (context, index) {
                      final artist = widget.allArtists[index];
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
                    },
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