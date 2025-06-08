import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import '../models/workshop.dart';
import '../widgets/workshop_detail_modal.dart';
import '../widgets/reaction_buttons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class ArtistDetailScreen extends StatefulWidget {
  final Artist? artist;
  final String? artistId;
  final bool fromNotification;

  const ArtistDetailScreen({
    super.key, 
    this.artist,
    this.artistId,
    this.fromNotification = false,
  }) : assert(artist != null || artistId != null, 'Either artist or artistId must be provided');

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late Future<List<WorkshopSession>> futureWorkshops;
  Artist? _artist;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeArtist();
  }

  void _initializeArtist() {
    if (widget.artist != null) {
      _artist = widget.artist;
      futureWorkshops = ApiService().fetchWorkshopsByArtist(_artist!.id);
    } else if (widget.artistId != null) {
      _loadArtistById(widget.artistId!);
    }
  }

  Future<void> _loadArtistById(String artistId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all artists and find the one with matching ID
      final allArtists = await ApiService().fetchArtists();
      final foundArtist = allArtists.firstWhere(
        (artist) => artist.id == artistId,
        orElse: () => throw Exception('Artist not found'),
      );
      
      setState(() {
        _artist = foundArtist;
        _isLoading = false;
      });
      
      futureWorkshops = ApiService().fetchWorkshopsByArtist(artistId);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load artist: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
        Navigator.of(context).pop();
      }
    }
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
    // Show loading state if artist is being loaded
    if (_isLoading || _artist == null) {
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
          child: const SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF00D4FF),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading artist...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
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
              // Artist Header with Image and Info
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
                          
                          // Artist Image and Name
                          Row(
                            children: [
                              // Artist Image
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF006E).withOpacity(0.3),
                                      const Color(0xFF8338EC).withOpacity(0.3),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: _artist?.imageUrl != null
                                      ? Image.network(
                                          'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(_artist!.imageUrl!)}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildArtistIcon();
                                          },
                                        )
                                      : _buildArtistIcon(),
                                ),
                              ),
                              
                              const SizedBox(width: 20),
                              
                              // Artist Name and Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Artist Name with Instagram Icon
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            toTitleCase(_artist?.name ?? ''),
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
                                          onTap: () => _launchInstagram(_artist?.instagramLink ?? ''),
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
                                            const Color(0xFFFF006E).withOpacity(0.2),
                                            const Color(0xFF8338EC).withOpacity(0.2),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFFF006E).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            color: const Color(0xFFFF006E),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Dance Instructor',
                                            style: TextStyle(
                                              color: Color(0xFFFF006E),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Reaction Buttons
                                    ArtistReactionButtons(
                                      artistId: _artist?.id ?? '',
                                      primaryColor: const Color(0xFFFF006E),
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
                child: FutureBuilder<List<WorkshopSession>>(
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
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                                'Check back later for upcoming workshops by ${_artist?.name}',
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
                      // Sort workshops by timestamp before displaying
                      final sortedWorkshops = snapshot.data!;
                      sortedWorkshops.sort((a, b) => a.timestampEpoch.compareTo(b.timestampEpoch));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF006E).withOpacity(0.2),
                                  const Color(0xFF8338EC).withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFFF006E).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFFFF006E).withOpacity(0.2),
                                  ),
                                  child: const Icon(
                                    Icons.event_rounded,
                                    color: Color(0xFFFF006E),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Upcoming Workshops (${sortedWorkshops.length})',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF006E),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Workshops List
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              itemCount: sortedWorkshops.length,
                              itemBuilder: (context, index) {
                                final workshop = sortedWorkshops[index];
                                return _buildWorkshopCard(workshop, index);
                              },
                            ),
                          ),
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

  Widget _buildArtistIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          size: 40,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(WorkshopSession workshop, int index) {
    // Create a staggered animation effect
    final delay = Duration(milliseconds: index * 100);
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
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
                  BoxShadow(
                    color: const Color(0xFFFF006E).withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
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
                                
                                // Instagram Icon (if choreo link is available)
                                if (workshop.choreoInstaLink != null && workshop.choreoInstaLink!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () async {
                                        final uri = Uri.parse(workshop.choreoInstaLink!);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Could not open Instagram link'),
                                                backgroundColor: Colors.red.withOpacity(0.8),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFE1306C).withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
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
                                    color: Color(0xFFFF006E),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            
                            if (workshop.studioId?.isNotEmpty == true && workshop.studioId != 'TBA')
                              Row(
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      toTitleCase(workshop.studioId!),
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
                            
                            // Workshop Type Badge
                            if (workshop.eventType?.isNotEmpty == true && workshop.eventType != 'workshop')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFF8338EC).withOpacity(0.2),
                                    border: Border.all(
                                      color: const Color(0xFF8338EC).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    toTitleCase(workshop.eventType!),
                                    style: const TextStyle(
                                      color: Color(0xFF8338EC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 