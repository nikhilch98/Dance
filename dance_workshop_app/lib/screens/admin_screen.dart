import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:dance_workshop_app/services/auth_service.dart';
import 'package:dance_workshop_app/services/api_service.dart';
import 'package:dance_workshop_app/models/artist.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  bool isLoadingSongs = false;
  bool isLoadingArtists = false;
  String? songsError;
  String? artistsError;
  List<Map<String, dynamic>> missingSongSessions = [];
  List<Map<String, dynamic>> missingArtistSessions = [];
  List<Artist> allArtists = [];
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMissingSongSessions();
    _loadMissingArtistSessions();
    _loadArtists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadArtists() async {
    try {
      final artists = await ApiService().fetchArtists();
      setState(() {
        allArtists = artists;
      });
    } catch (e) {
      print('Error loading artists: $e');
    }
  }

  Future<void> _loadMissingSongSessions() async {
    setState(() {
      isLoadingSongs = true;
      songsError = null;
    });

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
        setState(() {
          missingSongSessions = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to load workshops missing songs (Error ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        songsError = e.toString();
      });
    } finally {
      setState(() {
        isLoadingSongs = false;
      });
    }
  }

  Future<void> _loadMissingArtistSessions() async {
    setState(() {
      isLoadingArtists = true;
      artistsError = null;
    });

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
        setState(() {
          missingArtistSessions = List<Map<String, dynamic>>.from(json.decode(response.body));
        });
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Admin access required. Contact support if you believe this is an error.');
      } else {
        throw Exception('Failed to load workshops missing artists (Error ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        artistsError = e.toString();
      });
    } finally {
      setState(() {
        isLoadingArtists = false;
      });
    }
  }

  Future<void> _assignArtistToWorkshop(String workshopUuid, Artist artist) async {
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
          'artist_id': artist.id,
          'artist_name': artist.name,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Successfully assigned ${artist.name}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // Refresh the missing artists list
        _loadMissingArtistSessions();
      } else {
        throw Exception('Failed to assign artist (Error ${response.statusCode})');
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                              ),
                            ),
                            child: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Assign Artist',
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
                              session['song'] ?? 'Unknown Workshop',
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
                      const Text(
                        'Select an artist to assign:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: allArtists.length,
                          itemBuilder: (context, index) {
                            final artist = allArtists[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFF006E),
                                  child: Text(
                                    artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
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
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  _assignArtistToWorkshop(session['workshop_uuid'], artist);
                                },
                              ),
                            );
                          },
                        ),
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
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Row(
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
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 28,
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
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
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4081), Color(0xFFE91E63)],
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withOpacity(0.6),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
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
                  return _buildSessionCard(session, Icons.music_note, const Color(0xFFFF4081));
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

  Widget _buildSessionCard(Map<String, dynamic> session, IconData icon, Color accentColor, {bool showAssignButton = false}) {
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
                            session['song'] ?? session['workshop_name'] ?? 'Unknown Workshop',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
} 