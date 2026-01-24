import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

import '../models/reel.dart';
import '../services/api_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/payment_link_utils.dart';
import '../widgets/reel_player_widget.dart';
import 'artist_detail_screen.dart';

/// Screen that displays choreography reels in a vertical scrollable format.
/// Similar to Instagram/TikTok reels experience with filtering capabilities.
/// 
/// Loads native videos from the database via /api/reels/videos endpoint.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Reel>> futureReels;
  List<Reel> allReels = [];
  List<Reel> displayedReels = [];

  // State variables for filters
  List<String> availableDates = [];
  List<String> availableInstructors = [];
  List<String> availableStudios = [];

  List<String> selectedDates = [];
  List<String> selectedInstructors = [];
  List<String> selectedStudios = [];

  // PageView controller
  late PageController _pageController;
  int _currentIndex = 0;
  

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    futureReels = _loadReels();
  }

  Future<List<Reel>> _loadReels() async {
    final apiService = ApiService();
    
    // Fetch reels from the API
    // Uses same filtering as "All Workshops" - only workshops from current week onwards
    // with completed video processing
    final reelsResponse = await apiService.fetchReels(
      limit: 100,
      videoOnly: true,
    );
    
    allReels = reelsResponse.reels;
    
    // Initialize filters from API reels
    _initializeFiltersFromApiReels(reelsResponse.reels);
    _applyFilters();
    
    return reelsResponse.reels;
  }
  
  void _initializeFiltersFromApiReels(List<Reel> reels) {
    // Extract unique values from API reels
    availableDates = reels
        .where((r) => r.date != null && r.date!.isNotEmpty && r.date != 'TBA')
        .map((r) => r.date!)
        .toSet()
        .toList()
      ..sort();

    availableInstructors = reels
        .where((r) => r.artistName != null && r.artistName!.isNotEmpty && r.artistName != 'TBA')
        .map((r) => r.artistName!)
        .toSet()
        .toList()
      ..sort();

    availableStudios = reels
        .where((r) => r.studioName.isNotEmpty && r.studioName != 'TBA')
        .map((r) => r.studioName)
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters() {
    setState(() {
      displayedReels = allReels.where((reel) {
        // Date filter
        if (selectedDates.isNotEmpty && (reel.date == null || !selectedDates.contains(reel.date!))) {
          return false;
        }
        // Instructor filter
        if (selectedInstructors.isNotEmpty && (reel.artistName == null || !selectedInstructors.contains(reel.artistName!))) {
          return false;
        }
        // Studio filter
        if (selectedStudios.isNotEmpty && !selectedStudios.contains(reel.studioName)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      selectedDates.clear();
      selectedInstructors.clear();
      selectedStudios.clear();
      _applyFilters();
    });
  }

  bool get hasActiveFilters =>
      selectedDates.isNotEmpty ||
      selectedInstructors.isNotEmpty ||
      selectedStudios.isNotEmpty;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FutureBuilder<List<Reel>>(
        future: futureReels,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (displayedReels.isEmpty) {
            return _buildEmptyState();
          }

          return Stack(
            children: [
              // Full screen PageView for reels
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: displayedReels.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildReelPage(displayedReels[index], index);
                },
              ),

              // Top gradient overlay for filter button
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Header with filter button
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacingLarge(context),
                    vertical: ResponsiveUtils.spacingMedium(context),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Title
                      Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                            ).createShader(bounds),
                            child: Icon(
                              Icons.slow_motion_video_rounded,
                              color: Colors.white,
                              size: ResponsiveUtils.iconLarge(context),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                          Text(
                            'Reels',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.h2(context),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      // Filter button
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          padding: ResponsiveUtils.paddingSmall(context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: hasActiveFilters
                                  ? [const Color(0xFFE1306C), const Color(0xFFC13584)]
                                  : [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                color: Colors.white,
                                size: ResponsiveUtils.iconSmall(context),
                              ),
                              if (hasActiveFilters) ...[
                                SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${selectedDates.length + selectedInstructors.length + selectedStudios.length}',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.micro(context),
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE1306C),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Reel counter indicator
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: ResponsiveUtils.spacingLarge(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${displayedReels.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: ResponsiveUtils.caption(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReelPage(Reel reel, int index) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const navBarHeight = 56.0; // Bottom nav bar height
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player - full screen
        ReelPlayerWidget(reel: reel),

        // Bottom gradient for text readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom info card
        Positioned(
          bottom: bottomPadding + navBarHeight + 4,
          left: ResponsiveUtils.spacingMedium(context),
          right: ResponsiveUtils.spacingMedium(context),
          child: Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row: Artist Name + Instagram icons + Date Badge
                    Row(
                      children: [
                        // Artist Name (tappable) + Instagram icons
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: GestureDetector(
                                  onTap: () => _navigateToArtist(reel),
                                  child: Text(
                                    _toTitleCase(reel.artistName ?? 'Unknown Artist'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.body2(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                              _buildArtistInstagramIcons(reel),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        // Date Badge
                        if (reel.date != null && reel.date!.isNotEmpty && reel.date != 'TBA')
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacingSmall(context),
                              vertical: ResponsiveUtils.spacingXSmall(context),
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                            ),
                            child: Text(
                              reel.date!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.micro(context) * 0.9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                    
                    // Main Content Row: Avatar + Details + Register Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Artist Avatar (tappable)
                        GestureDetector(
                          onTap: () => _navigateToArtist(reel),
                          child: _buildArtistAvatars(reel),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        
                        // Workshop Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Song Name
                              if (reel.songName != null && reel.songName!.isNotEmpty && reel.songName != 'TBA')
                                Text(
                                  _toTitleCase(reel.songName!),
                                  style: TextStyle(
                                    color: const Color(0xFF00D4FF),
                                    fontSize: ResponsiveUtils.caption(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              
                              SizedBox(height: ResponsiveUtils.spacingXSmall(context) * 0.5),
                              
                              // Studio
                              Row(
                                children: [
                                  Icon(
                                    Icons.business_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: ResponsiveUtils.iconXSmall(context),
                                  ),
                                  SizedBox(width: ResponsiveUtils.spacingXSmall(context) * 0.7),
                                  Expanded(
                                    child: Text(
                                      _toTitleCase(reel.studioName),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: ResponsiveUtils.micro(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: ResponsiveUtils.spacingXSmall(context) * 0.5),
                              
                              // Time & Price Row
                              Row(
                                children: [
                                  // Time
                                  if (reel.time != null && reel.time!.isNotEmpty && reel.time != 'TBA') ...[
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.white.withOpacity(0.7),
                                      size: ResponsiveUtils.iconXSmall(context),
                                    ),
                                    SizedBox(width: ResponsiveUtils.spacingXSmall(context) * 0.7),
                                    Text(
                                      reel.time!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: ResponsiveUtils.micro(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  // Price
                                  if (reel.pricingInfo != null && reel.pricingInfo!.isNotEmpty) ...[
                                    if (reel.time != null && reel.time!.isNotEmpty && reel.time != 'TBA')
                                      SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                    Text(
                                      '₹${reel.pricingInfo}',
                                      style: TextStyle(
                                        color: const Color(0xFF10B981),
                                        fontSize: ResponsiveUtils.micro(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ] else if (reel.currentPrice != null) ...[
                                    if (reel.time != null && reel.time!.isNotEmpty && reel.time != 'TBA')
                                      SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                    Text(
                                      '₹${reel.currentPrice!.toInt()}',
                                      style: TextStyle(
                                        color: const Color(0xFF10B981),
                                        fontSize: ResponsiveUtils.micro(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        
                        // Register Button
                        _buildRegisterButton(reel),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  
  Widget _buildArtistAvatars(Reel reel) {
    final avatarUrls = reel.artistImageUrls ?? [];
    final displayCount = avatarUrls.length.clamp(0, 3);
    
    if (displayCount == 0) {
      return Container(
        width: ResponsiveUtils.iconLarge(context),
        height: ResponsiveUtils.iconLarge(context),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFE1306C), Color(0xFFC13584)],
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: ResponsiveUtils.iconSmall(context),
        ),
      );
    }

    if (displayCount == 1) {
      return Container(
        width: ResponsiveUtils.iconLarge(context),
        height: ResponsiveUtils.iconLarge(context),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: avatarUrls[0] != null
              ? DecorationImage(
                  image: NetworkImage(avatarUrls[0]!),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: avatarUrls[0] == null
              ? const LinearGradient(colors: [Color(0xFFE1306C), Color(0xFFC13584)])
              : null,
        ),
        child: avatarUrls[0] == null
            ? Icon(Icons.person_rounded, color: Colors.white, size: ResponsiveUtils.iconSmall(context))
            : null,
      );
    }

    // Multiple avatars - overlapping
    final avatarSize = ResponsiveUtils.iconLarge(context) * 0.8;
    return SizedBox(
      width: avatarSize + (displayCount - 1) * 12.0,
      height: avatarSize,
      child: Stack(
        children: List.generate(displayCount, (index) {
          final url = avatarUrls[index];
          return Positioned(
            left: index * 12.0,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: url != null
                    ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                    : null,
                gradient: url == null
                    ? const LinearGradient(colors: [Color(0xFFE1306C), Color(0xFFC13584)])
                    : null,
              ),
              child: url == null
                  ? Icon(Icons.person_rounded, color: Colors.white, size: avatarSize * 0.5)
                  : null,
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildArtistInstagramIcons(Reel reel) {
    final links = (reel.artistInstagramLinks ?? [])
        .where((e) => (e ?? '').isNotEmpty)
        .cast<String>()
        .toList();

    if (links.isEmpty) return const SizedBox.shrink();

    const maxIcons = 3;
    final showCount = links.length > maxIcons ? maxIcons : links.length;

    List<Widget> icons = List.generate(showCount, (i) {
      return Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : ResponsiveUtils.spacingXSmall(context)),
        child: GestureDetector(
          onTap: () => _launchInstagramProfile(links[i]),
          child: SizedBox(
            width: ResponsiveUtils.iconSmall(context),
            height: ResponsiveUtils.iconSmall(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: [Color(0xFFE4405F), Color(0xFFFCAF45)]),
              ),
              child: Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: ResponsiveUtils.iconXSmall(context) * 0.9,
                ),
              ),
            ),
          ),
        ),
      );
    });

    if (links.length > maxIcons) {
      icons.add(
        Padding(
          padding: EdgeInsets.only(left: ResponsiveUtils.spacingXSmall(context)),
          child: Text(
            '+${links.length - maxIcons}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: ResponsiveUtils.micro(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
  
  Future<void> _launchInstagramProfile(String instagramUrl) async {
    try {
      String? username;
      if (instagramUrl.contains('instagram.com/')) {
        final parts = instagramUrl.split('instagram.com/');
        if (parts.length > 1) {
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
        final uri = Uri.parse(instagramUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {}
  }
  
  Widget _buildRegisterButton(Reel reel) {
    final isNachna = reel.paymentLinkType?.toLowerCase() == 'nachna';
    final hasPaymentLink = (reel.paymentLink?.isNotEmpty ?? false) || isNachna;
    
    if (!hasPaymentLink) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      width: isNachna
          ? (ResponsiveUtils.isSmallScreen(context) ? 85 : 95)
          : (ResponsiveUtils.isSmallScreen(context) ? 60 : 65),
      height: ResponsiveUtils.iconLarge(context),
      child: GestureDetector(
        onTap: () => _handleBooking(reel),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
            gradient: isNachna
                ? const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)])
                : const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
            boxShadow: [
              BoxShadow(
                color: isNachna
                    ? const Color(0xFF00D4FF).withOpacity(0.3)
                    : const Color(0xFF3B82F6).withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              isNachna ? 'Register with nachna' : 'Register',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.micro(context) * 0.85,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
  }


  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: ResponsiveUtils.screenHeight(context) * 0.7,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF0A0A0F),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(ResponsiveUtils.spacingLarge(context))),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: ResponsiveUtils.spacingSmall(context)),
                    width: ResponsiveUtils.spacingLarge(context) * 2,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: ResponsiveUtils.paddingLarge(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(ResponsiveUtils.spacingSmall(context)),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                                ),
                              ),
                              child: Icon(
                                Icons.filter_list_rounded,
                                color: Colors.white,
                                size: ResponsiveUtils.iconSmall(context),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                            Text(
                              'Filter Reels',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.h3(context),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (hasActiveFilters)
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                selectedDates.clear();
                                selectedInstructors.clear();
                                selectedStudios.clear();
                              });
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: Color(0xFFE1306C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Filter sections
                  Expanded(
                    child: ListView(
                      padding: ResponsiveUtils.paddingLarge(context),
                      children: [
                        _buildFilterSection(
                          title: 'Date',
                          icon: Icons.calendar_today_rounded,
                          options: availableDates,
                          selected: selectedDates,
                          accentColor: const Color(0xFF00D4FF),
                          onChanged: (newSelected) {
                            setSheetState(() {
                              selectedDates = newSelected;
                            });
                          },
                        ),
                        SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                        _buildFilterSection(
                          title: 'Artist',
                          icon: Icons.person_rounded,
                          options: availableInstructors,
                          selected: selectedInstructors,
                          accentColor: const Color(0xFFE1306C),
                          onChanged: (newSelected) {
                            setSheetState(() {
                              selectedInstructors = newSelected;
                            });
                          },
                        ),
                        SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                        _buildFilterSection(
                          title: 'Studio',
                          icon: Icons.business_rounded,
                          options: availableStudios,
                          selected: selectedStudios,
                          accentColor: const Color(0xFF8B5CF6),
                          onChanged: (newSelected) {
                            setSheetState(() {
                              selectedStudios = newSelected;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Apply button
                  Padding(
                    padding: EdgeInsets.only(
                      left: ResponsiveUtils.spacingLarge(context),
                      right: ResponsiveUtils.spacingLarge(context),
                      bottom: ResponsiveUtils.spacingLarge(context) + MediaQuery.of(context).padding.bottom,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _applyFilters();
                        // Reset to first page
                        if (_pageController.hasClients && displayedReels.isNotEmpty) {
                          _pageController.jumpToPage(0);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.spacingMedium(context)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE1306C).withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: ResponsiveUtils.spacingMedium(context),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Apply Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.body1(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required List<String> options,
    required List<String> selected,
    required Color accentColor,
    required Function(List<String>) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: ResponsiveUtils.iconSmall(context)),
            SizedBox(width: ResponsiveUtils.spacingSmall(context)),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.body1(context),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (selected.isNotEmpty) ...[
              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacingSmall(context),
                  vertical: ResponsiveUtils.spacingXSmall(context) * 0.5,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                ),
                child: Text(
                  '${selected.length}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.micro(context),
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ResponsiveUtils.spacingSmall(context)),
        Wrap(
          spacing: ResponsiveUtils.spacingSmall(context),
          runSpacing: ResponsiveUtils.spacingSmall(context),
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return GestureDetector(
              onTap: () {
                final newSelected = List<String>.from(selected);
                if (isSelected) {
                  newSelected.remove(option);
                } else {
                  newSelected.add(option);
                }
                onChanged(newSelected);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacingSmall(context),
                  vertical: ResponsiveUtils.spacingSmall(context),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                  gradient: isSelected
                      ? LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)])
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: isSelected ? accentColor : Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.caption(context),
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveUtils.iconLarge(context) * 2,
              height: ResponsiveUtils.iconLarge(context) * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE1306C).withOpacity(0.3),
                    const Color(0xFFC13584).withOpacity(0.3),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingLarge(context)),
            Text(
              'Loading Reels...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveUtils.body1(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
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
      child: Center(
        child: Padding(
          padding: ResponsiveUtils.paddingXLarge(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: ResponsiveUtils.iconLarge(context) * 2,
                height: ResponsiveUtils.iconLarge(context) * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.red.shade800.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: ResponsiveUtils.iconLarge(context),
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              Text(
                'Unable to load reels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.h3(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.spacingSmall(context)),
              Text(
                error,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: ResponsiveUtils.body2(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveUtils.spacingLarge(context)),
              GestureDetector(
                onTap: () {
                  setState(() {
                    futureReels = _loadReels();
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.spacingLarge(context),
                    vertical: ResponsiveUtils.spacingSmall(context),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.body2(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = hasActiveFilters;
    
    return Container(
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
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacingLarge(context),
                vertical: ResponsiveUtils.spacingMedium(context),
              ),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.slow_motion_video_rounded,
                      color: Colors.white,
                      size: ResponsiveUtils.iconLarge(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                  Text(
                    'Reels',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.h2(context),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Center(
                child: Padding(
                  padding: ResponsiveUtils.paddingXLarge(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: ResponsiveUtils.iconLarge(context) * 2.5,
                        height: ResponsiveUtils.iconLarge(context) * 2.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE1306C).withOpacity(0.2),
                              const Color(0xFFC13584).withOpacity(0.2),
                            ],
                          ),
                        ),
                        child: Icon(
                          hasFilters ? Icons.filter_list_off_rounded : Icons.slow_motion_video_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: ResponsiveUtils.iconLarge(context) * 1.3,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                      Text(
                        hasFilters ? 'No matching reels' : 'No choreography videos yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.h3(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                      Text(
                        hasFilters
                            ? 'Try adjusting your filters to see more reels'
                            : 'Check back soon for new dance choreography videos!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: ResponsiveUtils.body2(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasFilters) ...[
                        SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                        GestureDetector(
                          onTap: _resetFilters,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.spacingLarge(context),
                              vertical: ResponsiveUtils.spacingSmall(context),
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                              ),
                            ),
                            child: Text(
                              'Clear Filters',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.body2(context),
                                fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  void _navigateToArtist(Reel reel) {
    if (reel.artistIdList != null && reel.artistIdList!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(artistId: reel.artistIdList!.first),
        ),
      );
    }
  }

  void _handleBooking(Reel reel) {
    // Create workshop details for booking
    final workshopDetails = {
      'song': reel.songName,
      'artist': reel.artistName,
      'studio': reel.studioName,
      'date': reel.date,
      'time': reel.time,
      'pricing': reel.pricingInfo,
    };

    PaymentLinkUtils.launchPaymentLink(
      paymentLink: reel.paymentLink,
      paymentLinkType: reel.paymentLinkType,
      context: context,
      workshopDetails: workshopDetails,
      workshopUuid: reel.workshopUuid,
    );
  }
}
