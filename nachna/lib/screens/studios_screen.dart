import 'package:flutter/material.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import 'studio_detail_screen.dart';
import '../utils/responsive_utils.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'dart:ui';

class StudiosScreen extends StatefulWidget {
  const StudiosScreen({super.key});

  @override
  State<StudiosScreen> createState() => _StudiosScreenState();
}

class _StudiosScreenState extends State<StudiosScreen> {
  late Future<List<Studio>> futureStudios;

  @override
  void initState() {
    super.initState();
    futureStudios = ApiService().fetchStudios();
  }

  // Helper method to convert text to title case
  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Dark base with slight purple tint
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
                    width: ResponsiveUtils.borderWidthThin(context),
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
                                colors: [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
                              ),
                            ),
                            child: Icon(
                              Icons.business_rounded,
                              color: Colors.white,
                              size: ResponsiveUtils.iconSmall(context),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                          Text(
                            'Studios',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.h2(context),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Studios Grid
              Expanded(
                child: FutureBuilder<List<Studio>>(
                  future: futureStudios,
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
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                            strokeWidth: 3,
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
                            style: TextStyle(
                              color: Colors.redAccent, 
                              fontSize: ResponsiveUtils.body1(context)
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'No studios found.',
                          style: TextStyle(
                            color: Colors.white70, 
                            fontSize: ResponsiveUtils.h3(context)
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.spacingLarge(context)
                        ),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ResponsiveUtils.getGridColumns(context),
                            crossAxisSpacing: ResponsiveUtils.spacingLarge(context),
                            mainAxisSpacing: ResponsiveUtils.spacingLarge(context),
                            childAspectRatio: ResponsiveUtils.getChildAspectRatio(context),
                          ),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final studio = snapshot.data![index];
                            return _buildGlassyStudioCard(studio, context);
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

  Widget _buildGlassyStudioCard(Studio studio, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudioDetailScreen(studio: studio),
          ),
        );
      },
      child: Container(
        width: ResponsiveUtils.artistCardWidth(context),
        height: ResponsiveUtils.artistCardHeight(context),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 8),
              blurRadius: 24,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: ResponsiveUtils.paddingLarge(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00D4FF).withOpacity(0.3),
                                const Color(0xFF9D4EDD).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                            child: studio.imageUrl != null
                                ? Image.network(
                                    'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(studio.imageUrl!)}',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildFallbackIcon();
                                    },
                                  )
                                : _buildFallbackIcon(),
                          ),
                        ),
                        // Instagram Icon (responsive size)
                        Positioned(
                          bottom: ResponsiveUtils.spacingSmall(context),
                          right: ResponsiveUtils.spacingSmall(context),
                          child: GestureDetector(
                            onTap: () async {
                              await _launchInstagram(studio.instagramLink);
                            },
                            child: Container(
                              width: ResponsiveUtils.iconSmall(context),
                              height: ResponsiveUtils.iconSmall(context),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: Offset(0, ResponsiveUtils.spacingXSmall(context)),
                                    blurRadius: ResponsiveUtils.spacingSmall(context),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                child: Image.asset(
                                  'instagram-icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to gradient container with camera icon
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.photo_camera,
                                        color: Colors.white,
                                        size: ResponsiveUtils.micro(context),
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
                  SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                  Text(
                    toTitleCase(studio.name),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.caption(context),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.spacingXSmall(context), 
                      vertical: ResponsiveUtils.spacingXSmall(context) * 0.5
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D4FF).withOpacity(0.2),
                          const Color(0xFF9D4EDD).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Text(
                      'Tap to explore',
                      style: TextStyle(
                        color: const Color(0xFF00D4FF),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.3),
            const Color(0xFF9D4EDD).withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.business_rounded,
          size: (ResponsiveUtils.artistImageHeight(context) * 0.3).clamp(32.0, 56.0),
          color: Colors.white70,
        ),
      ),
    );
  }
} 