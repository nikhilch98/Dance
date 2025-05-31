import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import 'artist_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  late Future<List<Artist>> futureArtists;
  List<Artist> allArtists = [];
  List<Artist> displayedArtists = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    futureArtists = ApiService().fetchArtists().then((artists) {
      setState(() {
        allArtists = artists;
        displayedArtists = artists;
      });
      return artists;
    });
    _searchController.addListener(_filterArtists);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterArtists);
    _searchController.dispose();
    super.dispose();
  }

  void _filterArtists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        displayedArtists = allArtists;
      } else {
        displayedArtists = allArtists.where((artist) {
          return artist.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Helper method to handle Instagram linking
  Future<void> _launchInstagram(String instagramUrl) async {
    // Extract Instagram username from URL format: https://www.instagram.com/{username}/
    String? username;
    if (instagramUrl.contains('instagram.com/')) {
      final parts = instagramUrl.split('instagram.com/');
      if (parts.length > 1) {
        // Remove trailing slash and any query parameters
        username = parts[1].split('/')[0].split('?')[0];
      }
    }
    
    if (username != null && username.isNotEmpty) {
      final appUrl = 'instagram://user?username=$username';
      final webUrl = 'https://instagram.com/$username';

      if (await canLaunchUrl(Uri.parse(appUrl))) {
        await launchUrl(Uri.parse(appUrl));
      } else {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    } else {
      // Fallback to original URL if username extraction fails
      final webUrl = Uri.parse(instagramUrl);
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $instagramUrl'),
              backgroundColor: Colors.red.withOpacity(0.8),
            ),
          );
        }
      }
    }
  }

  // Helper method to convert text to title case
  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
                                colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                              ),
                            ),
                            child: const Icon(
                              Icons.people_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Artists',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF006E).withOpacity(0.3),
                                  const Color(0xFF8338EC).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Text(
                              '${displayedArtists.length} Found',
                              style: const TextStyle(
                                color: Color(0xFFFF006E),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Glassy Search Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
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
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search for your favorite artists...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                            ),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.clear_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Artists Grid
              Expanded(
                child: FutureBuilder<List<Artist>>(
                  future: futureArtists,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
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
                      );
                    } else if (snapshot.hasError) {
                      return Center(
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
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    } else if (!snapshot.hasData || displayedArtists.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No artists match your search'
                                    : 'No artists found',
                                style: const TextStyle(color: Colors.white70, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: displayedArtists.length,
                          itemBuilder: (context, index) {
                            final artist = displayedArtists[index];
                            return _buildGlassyArtistCard(artist);
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyArtistCard(Artist artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      child: Container(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 8),
              blurRadius: 24,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFFFF006E).withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF006E).withOpacity(0.3),
                                const Color(0xFF8338EC).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: artist.imageUrl != null
                                ? Image.network(
                                    'https://nachna.com/proxy-image/?url=${Uri.encodeComponent(artist.imageUrl!)}',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildFallbackIcon();
                                    },
                                  )
                                : _buildFallbackIcon(),
                          ),
                        ),
                        // Instagram Icon (reduced size)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () async {
                              // Try to open Instagram app first, fallback to browser
                              final instagramUrl = artist.instagramLink;
                              
                              await _launchInstagram(instagramUrl);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE4405F).withOpacity(0.5),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    toTitleCase(artist.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF006E).withOpacity(0.2),
                          const Color(0xFF8338EC).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Text(
                      'View workshops',
                      style: TextStyle(
                        color: Color(0xFFFF006E),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF006E).withOpacity(0.3),
            const Color(0xFF8338EC).withOpacity(0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 48,
          color: Colors.white70,
        ),
      ),
    );
  }
} 