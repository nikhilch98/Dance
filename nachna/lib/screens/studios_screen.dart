import 'package:flutter/material.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import 'studio_detail_screen.dart';
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
                                colors: [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
                              ),
                            ),
                            child: const Icon(
                              Icons.business_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Studios',
                            style: TextStyle(
                              fontSize: 28,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
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
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No studios found.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
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
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final studio = snapshot.data![index];
                            return _buildGlassyStudioCard(studio);
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

  Widget _buildGlassyStudioCard(Studio studio) {
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
              color: const Color(0xFF00D4FF).withOpacity(0.1),
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
                                const Color(0xFF00D4FF).withOpacity(0.3),
                                const Color(0xFF9D4EDD).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
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
                        // Instagram Icon (reduced size)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () async {
                              await _launchInstagram(studio.instagramLink);
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'instagram-icon.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to gradient container with camera icon
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                        ),
                              ),
                              child: const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                                        size: 14,
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
                  const SizedBox(height: 12),
                  Text(
                    toTitleCase(studio.name),
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
                          const Color(0xFF00D4FF).withOpacity(0.2),
                          const Color(0xFF9D4EDD).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Text(
                      'Tap to explore',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
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
            const Color(0xFF00D4FF).withOpacity(0.3),
            const Color(0xFF9D4EDD).withOpacity(0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.business_rounded,
          size: 48,
          color: Colors.white70,
        ),
      ),
    );
  }
} 