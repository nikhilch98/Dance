import 'package:flutter/material.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import '../widgets/workshop_detail_modal.dart';
import '../models/workshop.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class StudioDetailScreen extends StatefulWidget {
  final Studio studio;

  const StudioDetailScreen({Key? key, required this.studio}) : super(key: key);

  @override
  _StudioDetailScreenState createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends State<StudioDetailScreen> {
  late Future<CategorizedWorkshopResponse> futureWorkshops;

  @override
  void initState() {
    super.initState();
    futureWorkshops = ApiService().fetchWorkshopsByStudio(widget.studio.id);
  }

  void _showWorkshopDetails(WorkshopSession workshop) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return WorkshopDetailModal(workshop: workshop);
      },
    );
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _launchInstagram(String instagramUrl) async {
    try {
      final uri = Uri.parse(instagramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web browser
        final webUri = Uri.parse(instagramUrl);
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print('Error launching Instagram: $e');
    }
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
              // Studio Header with Image and Info
              Container(
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Back button row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back Button
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white.withOpacity(0.1),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              
                              // Empty space for balance
                              const SizedBox(width: 40),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Studio Image and Name
                          Row(
                            children: [
                              // Studio Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00D4FF).withOpacity(0.3),
                                      const Color(0xFF9D4EDD).withOpacity(0.3),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: widget.studio.imageUrl != null
                                      ? Image.network(
                                          'https://nachna.com/proxy-image/?url=${Uri.encodeComponent(widget.studio.imageUrl!)}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildStudioIcon();
                                          },
                                        )
                                      : _buildStudioIcon(),
                                ),
                              ),
                              
                              const SizedBox(width: 20),
                              
                              // Studio Name and Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Studio Name with Instagram Icon
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            toTitleCase(widget.studio.name),
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Instagram Icon aligned with text
                                        GestureDetector(
                                          onTap: () => _launchInstagram(widget.studio.instagramLink),
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(5),
                                              child: Image.asset(
                                                'instagram-icon.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  // Fallback to gradient container with camera icon
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(5),
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.camera_alt_rounded,
                                                      color: Colors.white,
                                                      size: 12,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF00D4FF).withOpacity(0.2),
                                            const Color(0xFF9D4EDD).withOpacity(0.2),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.business_rounded,
                                            color: const Color(0xFF00D4FF),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Dance Studio',
                                            style: TextStyle(
                                              color: Color(0xFF00D4FF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
              
              // Workshops Content
              Expanded(
                child: FutureBuilder<CategorizedWorkshopResponse>(
        future: futureWorkshops,
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: Colors.red.withOpacity(0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading workshops',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
              ),
            );
          } else if (!snapshot.hasData || (snapshot.data!.thisWeek.isEmpty && snapshot.data!.postThisWeek.isEmpty)) {
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
                                Icons.event_busy_rounded,
                                size: 64,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No workshops scheduled',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back later for upcoming workshops at ${widget.studio.name}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
              ),
            );
          } else {
            final response = snapshot.data!;
            final hasThisWeek = response.thisWeek.isNotEmpty;
            final hasPostThisWeek = response.postThisWeek.isNotEmpty;

            return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
              children: [
                // This Week section
                          if (hasThisWeek) ...[
                            _buildSectionHeader('This Week', Icons.calendar_today_rounded, const Color(0xFF00D4FF)),
                            const SizedBox(height: 12),
                            ...response.thisWeek.map((daySchedule) => _buildDaySection(daySchedule)),
                          ],

                          // Spacing between sections
                          if (hasThisWeek && hasPostThisWeek) const SizedBox(height: 32),

                          // Upcoming Workshops section
                          if (hasPostThisWeek) ...[
                            _buildSectionHeader('Upcoming Workshops', Icons.upcoming_rounded, const Color(0xFF9D4EDD)),
                            const SizedBox(height: 12),
                            ...response.postThisWeek.map((workshop) => _buildWorkshopCard(workshop)),
                          ],
                          
                          const SizedBox(height: 20),
                        ],
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

  Widget _buildStudioIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          size: 40,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
                    children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
                        style: TextStyle(
              fontSize: 20,
                          fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(DaySchedule daySchedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                // Day Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                  ),
                                child: Text(
                                  daySchedule.day,
                                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Workshops for this day
                ...daySchedule.workshops.map((workshop) => _buildCompactWorkshopCard(workshop)),
              ],
            ),
                                  ),
                                ),
                              ),
    );
  }

  Widget _buildWorkshopCard(WorkshopSession workshop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Material(
            color: Colors.transparent,
                                    child: InkWell(
              borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showWorkshopDetails(workshop),
                                      child: Padding(
                padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                    // Header with Date and Time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workshop.date,
                                              style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                                                fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                          ),
                          child: Text(
                            workshop.time,
                            style: const TextStyle(
                                                color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Workshop Details
                    if (workshop.song?.isNotEmpty == true && workshop.song != 'TBA')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          toTitleCase(workshop.song!),
                          style: const TextStyle(
                            color: Color(0xFF00D4FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                    
                    if (workshop.artist?.isNotEmpty == true && workshop.artist != 'TBA')
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              toTitleCase(workshop.artist!),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                      ),
                    ],
                  ),

                    if (workshop.pricingInfo?.isNotEmpty == true && workshop.pricingInfo != 'TBA')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                    children: [
                            Icon(
                              Icons.currency_rupee_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                workshop.pricingInfo!,
                        style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
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
      ),
    );
  }

  Widget _buildCompactWorkshopCard(WorkshopSession workshop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
                                    ),
                                     child: InkWell(
        borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showWorkshopDetails(workshop),
        child: Row(
          children: [
            // Time Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF00D4FF).withOpacity(0.2),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                ),
              ),
              child: Text(
                workshop.time,
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Workshop Info
            Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                  if (workshop.song?.isNotEmpty == true && workshop.song != 'TBA')
                                            Text(
                      toTitleCase(workshop.song!),
                                              style: const TextStyle(
                                                color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                                            ),
                  if (workshop.artist?.isNotEmpty == true && workshop.artist != 'TBA')
                                            Text(
                      'with ${toTitleCase(workshop.artist!)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
            
            // Arrow Icon
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 16,
                      ),
                    ],
                  ),
      ),
    );
  }
} 