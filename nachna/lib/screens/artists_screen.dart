import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import 'artist_detail_screen.dart';
import '../widgets/reaction_buttons.dart';
import '../widgets/cached_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../utils/responsive_utils.dart';

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
    futureArtists = ApiService().fetchArtists(hasWorkshops: true).then((artists) {
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
                                  colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                                ),
                              ),
                              child: Icon(
                                Icons.people_rounded,
                                color: Colors.white,
                                size: ResponsiveUtils.iconMedium(context),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                            Text(
                              'Artists',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.h2(context),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacingMedium(context),
                                vertical: ResponsiveUtils.spacingSmall(context)
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXLarge(context)),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF006E).withOpacity(0.3),
                                    const Color(0xFF8338EC).withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Text(
                                '${displayedArtists.length} Found',
                                style: TextStyle(
                                  color: const Color(0xFFFF006E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: ResponsiveUtils.micro(context),
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
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.body2(context)),
                        decoration: InputDecoration(
                          hintText: 'Search for your favorite artists...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: ResponsiveUtils.body2(context),
                          ),
                          prefixIcon: Container(
                            margin: ResponsiveUtils.paddingMedium(context),
                            padding: ResponsiveUtils.paddingSmall(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                              ),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: ResponsiveUtils.iconSmall(context),
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Container(
                                    padding: EdgeInsets.all(ResponsiveUtils.spacingXSmall(context)),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    child: Icon(
                                      Icons.clear_rounded,
                                      color: Colors.white,
                                      size: ResponsiveUtils.iconXSmall(context),
                                    ),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.spacingXLarge(context),
                            vertical: ResponsiveUtils.spacingXLarge(context),
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
                            padding: ResponsiveUtils.paddingXLarge(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: CircularProgressIndicator(
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF006E)),
                              strokeWidth: ResponsiveUtils.borderWidthMedium(context),
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Container(
                            margin: ResponsiveUtils.paddingXLarge(context),
                            padding: ResponsiveUtils.paddingXLarge(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
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
                              style: TextStyle(color: Colors.redAccent, fontSize: ResponsiveUtils.body2(context)),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      } else if (!snapshot.hasData || displayedArtists.isEmpty) {
                        return Center(
                          child: Container(
                            margin: ResponsiveUtils.paddingXLarge(context),
                            padding: ResponsiveUtils.paddingXLarge(context),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
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
                                  size: ResponsiveUtils.iconXLarge(context),
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No artists match your search'
                                      : 'No artists found',
                                  style: TextStyle(color: Colors.white70, fontSize: ResponsiveUtils.body2(context)),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: ResponsiveUtils.getGridColumns(context),
                              crossAxisSpacing: ResponsiveUtils.spacingLarge(context),
                              mainAxisSpacing: ResponsiveUtils.spacingLarge(context),
                              childAspectRatio: ResponsiveUtils.getChildAspectRatio(context),
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
      ),
    );
  }

  Widget _buildGlassyArtistCard(Artist artist) {
    // Calculate responsive values once to avoid MediaQuery in widget tree
    final spacingSmall = ResponsiveUtils.spacingSmall(context);
    final spacingXSmall = ResponsiveUtils.spacingXSmall(context);
    final spacingLarge = ResponsiveUtils.spacingLarge(context);
    final iconSmall = ResponsiveUtils.iconSmall(context);
    final microSize = ResponsiveUtils.micro(context);
    final cardBorderRadius = ResponsiveUtils.cardBorderRadius(context);
    final borderWidthMedium = ResponsiveUtils.borderWidthMedium(context);

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
          borderRadius: BorderRadius.circular(cardBorderRadius),
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
            width: borderWidthMedium,
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
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(spacingLarge),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF006E).withOpacity(0.3),
                            const Color(0xFF8338EC).withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(spacingLarge),
                        child: Stack(
                          children: [
                            artist.id.isNotEmpty
                                ? CachedImage.rectangular(
                                    imageUrl: 'https://nachna.com/api/image/artist/${artist.id}',
                                    width: double.infinity,
                                    height: double.infinity,
                                    borderRadius: 0,
                                    fallbackText: artist.name,
                                    fallbackGradientColors: [
                                      const Color(0xFFFF006E).withOpacity(0.7),
                                      const Color(0xFF8338EC).withOpacity(0.7),
                                    ],
                                  )
                                : _buildFallbackIcon(),
                            // Instagram Icon (responsive size)
                            Positioned(
                              bottom: spacingSmall,
                              right: spacingSmall,
                              child: GestureDetector(
                                onTap: () async {
                                  await _launchInstagram(artist.instagramLink);
                                },
                                child: Container(
                                  width: iconSmall * 1.3,
                                  height: iconSmall * 1.3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(spacingSmall),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: Offset(0, spacingXSmall),
                                        blurRadius: spacingSmall,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(spacingSmall),
                                    child: Image.asset(
                                      'instagram-icon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // Fallback to gradient container with camera icon
                                        return Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(spacingSmall),
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.photo_camera,
                                            color: Colors.white,
                                            size: microSize * 1.2,
                                          ),
                                        );
                                      },
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
                  SizedBox(height: spacingSmall),
                  Text(
                    toTitleCase(artist.name),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.caption(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacingXSmall),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacingXSmall, vertical: spacingXSmall / 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(spacingSmall),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF006E).withOpacity(0.2),
                          const Color(0xFF8338EC).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Text(
                      'Tap to explore',
                      style: TextStyle(
                        color: const Color(0xFFFF006E),
                        fontSize: ResponsiveUtils.micro(context),
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
      width: double.infinity,
      height: double.infinity,
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