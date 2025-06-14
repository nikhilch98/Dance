import 'package:flutter/material.dart';
import '../models/artist.dart';
import '../services/api_service.dart';
import '../models/workshop.dart';
import '../widgets/workshop_detail_modal.dart';
import '../widgets/reaction_buttons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../utils/responsive_utils.dart';

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
                  const Text(
                    'Loading artist...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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
        child: Stack(
          children: [
            // Main scrollable content
            SafeArea(
              child: ListView(
                padding: EdgeInsets.only(top: ResponsiveUtils.spacingXXLarge(context) * 2),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Artist Header with Image and Info
                  Container(
                    margin: ResponsiveUtils.paddingLarge(context),
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
                    child: Container(
                      padding: ResponsiveUtils.paddingLarge(context),
                          child: Column(
                            children: [
                                                            // Artist Image and Name
                              Row(
                                children: [
                                  // Artist Image - Larger size
                                  Container(
                                    width: ResponsiveUtils.avatarSizeLarge(context) * 1.4,
                                    height: ResponsiveUtils.avatarSizeLarge(context) * 1.4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXLarge(context)),
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFFF006E).withOpacity(0.3),
                                          const Color(0xFF8338EC).withOpacity(0.3),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: ResponsiveUtils.borderWidthMedium(context),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
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
                                  
                                  SizedBox(width: ResponsiveUtils.spacingXLarge(context)),
                                  
                                  // Artist Name and Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Artist Name - Extended
                                        Text(
                                          toTitleCase(_artist?.name ?? ''),
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.body1(context),
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                                        // Dance Instructor with Instagram Icon
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: ResponsiveUtils.spacingSmall(context), 
                                                vertical: ResponsiveUtils.spacingXSmall(context)
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
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
                                                    size: ResponsiveUtils.iconXSmall(context),
                                                  ),
                                                  SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                                                  Text(
                                                    'Dance Instructor',
                                                    style: TextStyle(
                                                      color: const Color(0xFFFF006E),
                                                      fontSize: ResponsiveUtils.micro(context),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                            // Instagram Icon moved here
                                            GestureDetector(
                                              onTap: () => _launchInstagram(_artist?.instagramLink ?? ''),
                                              child: Container(
                                                width: ResponsiveUtils.iconSmall(context),
                                                height: ResponsiveUtils.iconSmall(context),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXSmall(context)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      offset: const Offset(0, 2),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXSmall(context)),
                                                  child: Image.asset(
                                                    'instagram-icon.png',
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      // Fallback to gradient container with camera icon
                                                      return Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXSmall(context)),
                                                          gradient: const LinearGradient(
                                                            colors: [Color(0xFFE4405F), Color(0xFFFCAF45)],
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.camera_alt_rounded,
                                                          color: Colors.white,
                                                          size: ResponsiveUtils.spacingMedium(context),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                                        // Like and Follow Buttons Row
                                        Row(
                                          children: [
                                            // Like Button
                                            Expanded(
                                              child: Container(
                                                height: ResponsiveUtils.buttonHeight(context) * 0.7,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    // Handle like action
                                                  },
                                                  icon: Icon(
                                                    Icons.favorite_outline_rounded,
                                                    size: ResponsiveUtils.iconXSmall(context),
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    'Like',
                                                    style: TextStyle(
                                                      fontSize: ResponsiveUtils.micro(context),
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFFF006E).withOpacity(0.2),
                                                    elevation: 0,
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: ResponsiveUtils.spacingSmall(context),
                                                      vertical: ResponsiveUtils.spacingXSmall(context),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                                      side: BorderSide(
                                                        color: const Color(0xFFFF006E).withOpacity(0.3),
                                                        width: ResponsiveUtils.borderWidthThin(context),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                            // Follow Button
                                            Expanded(
                                              child: Container(
                                                height: ResponsiveUtils.buttonHeight(context) * 0.7,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    // Handle follow action
                                                  },
                                                  icon: Icon(
                                                    Icons.person_add_outlined,
                                                    size: ResponsiveUtils.iconXSmall(context),
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    'Follow',
                                                    style: TextStyle(
                                                      fontSize: ResponsiveUtils.micro(context),
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF8338EC).withOpacity(0.2),
                                                    elevation: 0,
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: ResponsiveUtils.spacingSmall(context),
                                                      vertical: ResponsiveUtils.spacingXSmall(context),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                                      side: BorderSide(
                                                        color: const Color(0xFF8338EC).withOpacity(0.3),
                                                        width: ResponsiveUtils.borderWidthThin(context),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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
              
              // Workshops Content
              FutureBuilder<List<WorkshopSession>>(
                  future: futureWorkshops,
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
                          margin: ResponsiveUtils.paddingLarge(context),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: ResponsiveUtils.iconXLarge(context) * 1.3,
                                color: Colors.red.withOpacity(0.7),
                              ),
                              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                              Text(
                                'Error loading workshops',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.9),
                                  fontSize: ResponsiveUtils.body2(context),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  color: Colors.red.withOpacity(0.7),
                                  fontSize: ResponsiveUtils.caption(context),
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
                          margin: ResponsiveUtils.paddingLarge(context),
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
                                Icons.event_busy_rounded,
                                size: ResponsiveUtils.iconXLarge(context) * 1.7,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                              Text(
                                'No workshops scheduled',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.body1(context),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                              Text(
                                'Check back later for upcoming workshops by ${_artist?.name}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: ResponsiveUtils.caption(context),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // Sort workshops by timestamp before displaying
                      final sortedWorkshops = snapshot.data!;
                      sortedWorkshops.sort((a, b) => a.timestampEpoch.compareTo(b.timestampEpoch));

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Header
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacingXLarge(context), 
                                vertical: ResponsiveUtils.spacingLarge(context)
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF006E).withOpacity(0.2),
                                    const Color(0xFF8338EC).withOpacity(0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFF006E).withOpacity(0.3),
                                  width: ResponsiveUtils.borderWidthThin(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: ResponsiveUtils.paddingSmall(context),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                      color: const Color(0xFFFF006E).withOpacity(0.2),
                                    ),
                                    child: Icon(
                                      Icons.event_rounded,
                                      color: const Color(0xFFFF006E),
                                      size: ResponsiveUtils.iconSmall(context),
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                                  Text(
                                    'Upcoming Workshops (${sortedWorkshops.length})',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.body1(context),
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF006E),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                            
                            // Workshops List
                            ...sortedWorkshops.map((workshop) => _buildWorkshopCard(workshop, sortedWorkshops.indexOf(workshop))),
                            
                            SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            ),
            
            // Fixed back button at top-left
            Builder(
              builder: (context) {
                // Pre-calculate responsive values and add safe area padding
                final mediaQuery = MediaQuery.of(context);
                final topPadding = mediaQuery.padding.top;
                final spacingMedium = ResponsiveUtils.spacingMedium(context);
                final spacingLarge = ResponsiveUtils.spacingLarge(context);
                final paddingSmall = ResponsiveUtils.paddingSmall(context);
                final iconMedium = ResponsiveUtils.iconMedium(context);
                
                return Positioned(
                  top: topPadding + spacingMedium,
                  left: spacingLarge,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: paddingSmall,
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: iconMedium,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF006E).withOpacity(0.3),
            const Color(0xFF8338EC).withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: ResponsiveUtils.iconXLarge(context),
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
              margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: ResponsiveUtils.borderWidthThin(context),
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                  onTap: () => _showWorkshopDetails(workshop),
                  child: Padding(
                    padding: ResponsiveUtils.paddingLarge(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Date and Time
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workshop.date,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.body2(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            
                            // Instagram Icon (if choreo link is available)
                            if (workshop.choreoInstaLink != null && workshop.choreoInstaLink!.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(right: ResponsiveUtils.spacingSmall(context)),
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
                                    width: ResponsiveUtils.iconMedium(context) * 1.3,
                                    height: ResponsiveUtils.iconMedium(context),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
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
                                    child: Center(
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: ResponsiveUtils.body2(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacingSmall(context), 
                                vertical: ResponsiveUtils.spacingXSmall(context)
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF006E), Color(0xFF8338EC)],
                                ),
                              ),
                              child: Text(
                                workshop.time,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ResponsiveUtils.micro(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                        
                        // Workshop Details
                        if (workshop.song?.isNotEmpty == true && workshop.song != 'TBA')
                          Padding(
                            padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
                            child: Text(
                              toTitleCase(workshop.song!),
                              style: TextStyle(
                                color: const Color(0xFFFF006E),
                                fontSize: ResponsiveUtils.caption(context),
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
                                size: ResponsiveUtils.iconXSmall(context),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                              Expanded(
                                child: Text(
                                  toTitleCase(workshop.studioId!),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: ResponsiveUtils.caption(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        
                        if (workshop.pricingInfo?.isNotEmpty == true && workshop.pricingInfo != 'TBA')
                          Padding(
                            padding: EdgeInsets.only(top: ResponsiveUtils.spacingSmall(context)),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.currency_rupee_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                  size: ResponsiveUtils.iconXSmall(context),
                                ),
                                SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                Expanded(
                                  child: Text(
                                    workshop.pricingInfo!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: ResponsiveUtils.micro(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Workshop Type Badge
                        if (workshop.eventType?.isNotEmpty == true && workshop.eventType != 'workshop')
                          Padding(
                            padding: EdgeInsets.only(top: ResponsiveUtils.spacingSmall(context)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.spacingSmall(context), 
                                vertical: ResponsiveUtils.spacingXSmall(context)
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                color: const Color(0xFF8338EC).withOpacity(0.2),
                                border: Border.all(
                                  color: const Color(0xFF8338EC).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                toTitleCase(workshop.eventType!),
                                style: TextStyle(
                                  color: const Color(0xFF8338EC),
                                  fontSize: ResponsiveUtils.micro(context),
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
        );
      },
    );
  }
}
