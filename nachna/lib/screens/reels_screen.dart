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
  
  // Track if using new API
  bool _usingReelsApi = true;

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
    
    _usingReelsApi = true;
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
    final navBarHeight = 96.0; // Bottom nav bar height + margin
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Instagram Reel Preview (tap to open)
        ReelPlayerWidget(reel: reel),

        // Bottom info card overlay
        Positioned(
          bottom: bottomPadding + navBarHeight,
          left: ResponsiveUtils.spacingMedium(context),
          right: ResponsiveUtils.spacingMedium(context),
          child: Container(
            padding: EdgeInsets.all(ResponsiveUtils.spacingMedium(context)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Artist info row with book button
                Row(
                  children: [
                    // Artist avatar
                    _buildArtistAvatars(reel),
                    SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                    
                    // Artist name and studio
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reel.artistName ?? 'Unknown Artist',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.body1(context),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.business_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  reel.studioName,
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.caption(context),
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Book button
                    _buildBookButton(reel),
                  ],
                ),

                // Date and time row
                if (reel.date != null && reel.date!.isNotEmpty && reel.date != 'TBA') ...[
                  SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: const Color(0xFF00D4FF),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reel.date!,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.caption(context),
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      if (reel.time != null && reel.time!.isNotEmpty && reel.time != 'TBA') ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time_rounded,
                          color: const Color(0xFF00D4FF),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reel.time!,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.caption(context),
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Side action buttons - positioned above the info card
        Positioned(
          right: ResponsiveUtils.spacingMedium(context),
          bottom: bottomPadding + navBarHeight + 140,
          child: Column(
            children: [
              // Artist profile button (if artist ID available)
              if (reel.artistIdList != null && reel.artistIdList!.isNotEmpty) ...[
                _buildActionButton(
                  icon: Icons.person_rounded,
                  gradient: const [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                  onTap: () => _navigateToArtist(reel),
                  label: 'Artist',
                ),
                SizedBox(height: ResponsiveUtils.spacingMedium(context)),
              ],
              
              // Instagram button
              _buildActionButton(
                icon: Icons.camera_alt_rounded,
                gradient: const [Color(0xFFE1306C), Color(0xFFC13584)],
                onTap: () => _openInstagramReel(reel),
                label: 'Instagram',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArtistAvatars(Reel reel) {
    final avatarUrls = reel.artistImageUrls ?? [];
    final displayCount = avatarUrls.length.clamp(0, 3);
    
    if (displayCount == 0) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFE1306C), Color(0xFFC13584)],
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    if (displayCount == 1) {
      return Container(
        width: 44,
        height: 44,
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
              ? const LinearGradient(
                  colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                )
              : null,
        ),
        child: avatarUrls[0] == null
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
            : null,
      );
    }

    // Multiple avatars - overlapping
    return SizedBox(
      width: 44 + (displayCount - 1) * 16.0,
      height: 44,
      child: Stack(
        children: List.generate(displayCount, (index) {
          final url = avatarUrls[index];
          return Positioned(
            left: index * 16.0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                image: url != null
                    ? DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: url == null
                    ? const LinearGradient(
                        colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                      )
                    : null,
              ),
              child: url == null
                  ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBookButton(Reel reel) {
    return GestureDetector(
      onTap: () => _handleBooking(reel),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context),
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.4),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: ResponsiveUtils.iconSmall(context),
            ),
            SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
            Text(
              'Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.body2(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: gradient),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                                ),
                              ),
                              child: const Icon(
                                Icons.filter_list_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE1306C).withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Apply Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.body1(context),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (selected.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selected.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
              width: 80,
              height: 80,
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
            const SizedBox(height: 24),
            Text(
              'Loading Reels...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.red.shade800.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to load reels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  setState(() {
                    futureReels = _loadReels();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
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
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
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
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        hasFilters ? 'No matching reels' : 'No choreography videos yet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasFilters
                            ? 'Try adjusting your filters to see more reels'
                            : 'Check back soon for new dance choreography videos!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (hasFilters) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _resetFilters,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                              ),
                            ),
                            child: const Text(
                              'Clear Filters',
                              style: TextStyle(
                                color: Colors.white,
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

  Future<void> _openInstagramReel(Reel reel) async {
    try {
      final uri = Uri.parse(reel.instagramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open Instagram'),
              backgroundColor: Colors.red.withOpacity(0.8),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open Instagram'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
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
