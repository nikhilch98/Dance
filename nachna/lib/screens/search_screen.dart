import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/search.dart';
import '../services/search_service.dart';
import '../screens/artist_detail_screen.dart';
import '../models/workshop.dart';
import '../utils/responsive_utils.dart';
import '../utils/payment_link_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  TabController? _tabController;
  Timer? _debounceTimer;
  
  // Search results
  List<SearchArtistResult> _artistResults = [];
  List<WorkshopListItem> _workshopResults = [];
  List<SearchUserResult> _userResults = [];
  
  // Loading states
  bool _isSearching = false;
  String _currentQuery = '';
  bool _showTabs = false;
  bool _showResults = false;
  
  // Recent searches
  List<String> _recentSearches = [];
  
  // Search focus
  FocusNode _searchFocusNode = FocusNode();
  


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    _debounceTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _showTabs = false;
        _showResults = false;
        _artistResults.clear();
        _workshopResults.clear();
        _userResults.clear();
        _isSearching = false;
      });
      return;
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query != _currentQuery) {
        _currentQuery = query;
        _performSearch(query);
      }
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList('recent_searches') ?? [];
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove if already exists
      _recentSearches.remove(query);
      
      // Add to the beginning
      _recentSearches.insert(0, query);
      
      // Keep only last 10 searches
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
      
      await prefs.setStringList('recent_searches', _recentSearches);
      setState(() {});
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.remove(query);
      await prefs.setStringList('recent_searches', _recentSearches);
      setState(() {});
    } catch (e) {
      // Handle error silently
    }
  }

  void _performSearchFromRecent(String query) {
    _searchController.text = query;
    _currentQuery = query;
    _performSearch(query);
    _saveRecentSearch(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _artistResults.clear();
        _workshopResults.clear();
        _userResults.clear();
        _isSearching = false;
        _showTabs = false;
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      // Perform all searches in parallel
      final results = await Future.wait([
        _searchService.searchArtists(query),
        _searchService.searchWorkshops(query),
        _searchService.searchUsers(query),
      ]);

      final artistResults = results[0] as List<SearchArtistResult>;
      final workshopResults = results[1] as List<WorkshopListItem>;
      final userResults = results[2] as List<SearchUserResult>;

      // Save recent search only if we got results
      if (artistResults.isNotEmpty || workshopResults.isNotEmpty || userResults.isNotEmpty) {
        _saveRecentSearch(query);
      }

      // Determine which tabs to show based on results
      final availableTabs = <String>[];
      if (artistResults.isNotEmpty) availableTabs.add('Artists');
      if (workshopResults.isNotEmpty) availableTabs.add('Workshops');
      if (userResults.isNotEmpty) availableTabs.add('Users');

      // Create tab controller only if we have tabs to show
      _tabController?.dispose();
      _tabController = availableTabs.isNotEmpty 
          ? TabController(length: availableTabs.length, vsync: this)
          : null;

      setState(() {
        _artistResults = artistResults;
        _workshopResults = workshopResults;
        _userResults = userResults;
        _isSearching = false;
        _showTabs = availableTabs.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _showTabs = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
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
                _buildHeader(),
                _buildSearchBar(),
                if (_showTabs && _tabController != null) _buildTabBar(),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: ResponsiveUtils.paddingLarge(context),
      child: Text(
        'Search',
        style: TextStyle(
          color: Colors.white,
          fontSize: ResponsiveUtils.h1(context),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
      child: Container(
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
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.body1(context),
              ),
              decoration: InputDecoration(
                hintText: 'Search artists, workshops, or users...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: ResponsiveUtils.body1(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: const Color(0xFF00D4FF),
                  size: ResponsiveUtils.iconMedium(context),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _artistResults.clear();
                            _workshopResults.clear();
                            _userResults.clear();
                            _currentQuery = '';
                          });
                        },
                        child: Icon(
                          Icons.clear,
                          color: Colors.white.withOpacity(0.7),
                          size: ResponsiveUtils.iconSmall(context),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacingLarge(context),
                  vertical: ResponsiveUtils.spacingLarge(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final availableTabs = <Widget>[];
    
    if (_artistResults.isNotEmpty) {
      availableTabs.add(
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_rounded, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Artists',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_artistResults.length}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_workshopResults.isNotEmpty) {
      availableTabs.add(
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_rounded, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Workshops',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_workshopResults.length}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_userResults.isNotEmpty) {
      availableTabs.add(
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_rounded, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Users',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_userResults.length}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: ResponsiveUtils.paddingLarge(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
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
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.all(ResponsiveUtils.spacingXSmall(context)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.body2(context),
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: ResponsiveUtils.body2(context),
              ),
              tabs: availableTabs,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
        ),
      );
    }

    // Show recent searches when search bar is empty
    if (_currentQuery.isEmpty) {
      return _buildRecentSearches();
    }

    // Show no results if search was performed but no results
    if (_showResults && !_showTabs) {
      return _buildEmptyState('No results found for "$_currentQuery"');
    }

    // Show tabs with results
    if (_showTabs && _tabController != null) {
      return _buildDynamicTabBarView();
    }

    return _buildEmptyState('Start typing to search...');
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return _buildEmptyState('No recent searches');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: ResponsiveUtils.paddingLarge(context),
          child: Text(
            'Recent Searches',
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.h2(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return _buildRecentSearchItem(search);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchItem(String search) {
    return GestureDetector(
      onTap: () => _performSearchFromRecent(search),
      child: Container(
        margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingLarge(context), 
          vertical: ResponsiveUtils.spacingMedium(context)
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: Colors.white.withOpacity(0.7),
              size: ResponsiveUtils.iconSmall(context),
            ),
            SizedBox(width: ResponsiveUtils.spacingMedium(context)),
            Expanded(
              child: Text(
                search,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: ResponsiveUtils.body1(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _removeRecentSearch(search),
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.5),
                size: ResponsiveUtils.iconSmall(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicTabBarView() {
    final availableViews = <Widget>[];
    
    if (_artistResults.isNotEmpty) {
      availableViews.add(_buildArtistsList());
    }
    if (_workshopResults.isNotEmpty) {
      availableViews.add(_buildWorkshopsList());
    }
    if (_userResults.isNotEmpty) {
      availableViews.add(_buildUsersList());
    }

    return TabBarView(
      controller: _tabController,
      children: availableViews,
    );
  }



  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: ResponsiveUtils.iconXLarge(context) * 2,
            color: Colors.white.withOpacity(0.3),
          ),
          SizedBox(height: ResponsiveUtils.spacingLarge(context)),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: ResponsiveUtils.body1(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsList() {
    if (_artistResults.isEmpty) {
      return _buildEmptyState('No artists found');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
      itemCount: _artistResults.length,
      itemBuilder: (context, index) {
        final artist = _artistResults[index];
        return _buildArtistCard(artist);
      },
    );
  }

  Widget _buildWorkshopsList() {
    if (_workshopResults.isEmpty) {
      return _buildEmptyState('No workshops found');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
      itemCount: _workshopResults.length,
      itemBuilder: (context, index) {
        final workshop = _workshopResults[index];
        return _buildWorkshopCard(workshop);
      },
    );
  }

  Widget _buildUsersList() {
    if (_userResults.isEmpty) {
      return _buildEmptyState('No users found');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildArtistCard(SearchArtistResult artist) {
    return GestureDetector(
      onTap: () {
        // Navigate to artist detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailScreen(artistId: artist.id),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
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
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: ResponsiveUtils.paddingLarge(context),
              child: Row(
                children: [
                  // Artist Image
                  Container(
                    width: ResponsiveUtils.avatarSize(context),
                    height: ResponsiveUtils.avatarSize(context),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: artist.imageUrl != null
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                            ),
                    ),
                    child: artist.imageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(artist.imageUrl!)}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: ResponsiveUtils.iconMedium(context),
                                  ),
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.white,
                            size: ResponsiveUtils.iconMedium(context),
                          ),
                  ),
                  SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                  // Artist Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.h3(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                        Text(
                          '@${artist.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: ResponsiveUtils.caption(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Instagram Icon
                  GestureDetector(
                    onTap: () async {
                      // Prevent artist detail screen navigation when tapping Instagram icon
                      await _launchInstagram(artist.instagramLink);
                    },
                    child: Image.asset(
                      'instagram-icon.png',
                      width: ResponsiveUtils.iconMedium(context),
                      height: ResponsiveUtils.iconMedium(context),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to camera icon
                        return Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: ResponsiveUtils.iconMedium(context),
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
  }

  Widget _buildWorkshopCard(WorkshopListItem workshop) {
    // Workshop is already in the correct format from the API

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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row with Artist Name and Date Badge
                Row(
                  children: [
                    // Artist Name (Main Title)
                    Expanded(
                      child: Text(
                        workshop.by?.isNotEmpty == true && workshop.by != 'TBA' 
                            ? toTitleCase(workshop.by!) 
                            : 'Dance Workshop',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Date Badge (aligned with artist name)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                      ),
                      child: Text(
                        workshop.date ?? 'TBA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Main Content Row with register button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Artist Avatars (using actual images from search results)
                    _buildArtistAvatars(workshop),
                    
                    const SizedBox(width: 10),
                    
                    // Workshop Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Song Name
                          if (workshop.song?.isNotEmpty == true && workshop.song != 'TBA')
                            Text(
                              toTitleCase(workshop.song!),
                              style: const TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          const SizedBox(height: 2),
                          
                          // Studio
                          Row(
                            children: [
                              Icon(
                                Icons.business_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  toTitleCase(workshop.studioName),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 2),
                          
                          // Time
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  workshop.time ?? 'TBA',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
                    
                    const SizedBox(width: 8),
                    
                    // Video Play Icon (if choreo link is available)
                    if (workshop.choreoInstaLink != null && workshop.choreoInstaLink!.isNotEmpty) ...[
                      GestureDetector(
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
                          padding: const EdgeInsets.all(6),
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
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    
                    // Register Button
                    GestureDetector(
                      onTap: () async {
                        await PaymentLinkUtils.launchPaymentLink(
                          paymentLink: workshop.paymentLink,
                          paymentLinkType: workshop.paymentLinkType,
                          context: context,
                          workshopDetails: {
                            'song': workshop.song,
                            'artist': workshop.by,
                            'studio': workshop.studioName,
                            'date': workshop.date,
                            'time': workshop.time,
                            'pricing': workshop.pricingInfo,
                          },
                          workshopUuid: workshop.uuid,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: workshop.paymentLinkType?.toLowerCase() == 'nachna'
                            ? const LinearGradient(
                                colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                          boxShadow: [
                            BoxShadow(
                              color: workshop.paymentLinkType?.toLowerCase() == 'nachna'
                                ? const Color(0xFF00D4FF).withOpacity(0.3)
                                : const Color(0xFF10B981).withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          workshop.paymentLinkType?.toLowerCase() == 'nachna'
                            ? 'Register with nachna'
                            : 'Register',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(SearchUserResult user) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingMedium(context)),
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
          width: ResponsiveUtils.borderWidthThin(context),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
            blurRadius: ResponsiveUtils.spacingSmall(context),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: ResponsiveUtils.paddingLarge(context),
            child: Row(
              children: [
                // User Profile Picture with enhanced styling
                Container(
                  width: ResponsiveUtils.avatarSize(context),
                  height: ResponsiveUtils.avatarSize(context),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: user.profilePictureUrl != null
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: ResponsiveUtils.spacingSmall(context),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://nachna.com/api/profile-picture/${user.userId}',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildUserAvatar(user.name);
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to default avatar if profile picture doesn't exist or fails to load
                        return _buildUserAvatar(user.name);
                      },
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.h3(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.spacingXSmall(context)),
                      Text(
                        'Joined ${_formatDate(user.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: ResponsiveUtils.caption(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // User Badge Icon
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.spacingSmall(context)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: ResponsiveUtils.iconSmall(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.h3(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }



  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  // Helper method to handle Instagram linking
  Future<void> _launchInstagram(String instagramUrl) async {
    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Instagram: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
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

  // Helper method to build artist avatars
  Widget _buildArtistAvatars(WorkshopListItem workshop) {
    final artistImageUrls = workshop.artistImageUrls ?? [];
    final validImageUrls = artistImageUrls.where((url) => url != null && url.isNotEmpty).toList();
    
    // If no valid images or only one artist, show single avatar
    if (validImageUrls.length <= 1) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: validImageUrls.isEmpty
              ? const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.2),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: validImageUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(validImageUrls[0]!)}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultAvatar(workshop.by);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildDefaultAvatar(workshop.by);
                  },
                ),
              )
            : _buildDefaultAvatar(workshop.by),
      );
    }
    
    // Multiple artists - show overlapping avatars
    final maxAvatars = validImageUrls.length > 3 ? 3 : validImageUrls.length;
    final avatarSize = 36.0;
    final overlapOffset = 24.0;
    
    return SizedBox(
      width: avatarSize + (maxAvatars - 1) * overlapOffset,
      height: 42,
      child: Stack(
        children: [
          for (int i = 0; i < maxAvatars; i++)
            Positioned(
              left: i * overlapOffset,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(validImageUrls[i]!)}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildSmallDefaultAvatar(workshop.by, i);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildSmallDefaultAvatar(workshop.by, i);
                    },
                  ),
                ),
              ),
            ),
          // Show count if more than 3 artists
          if (validImageUrls.length > 3)
            Positioned(
              right: 0,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF1A1A2E).withOpacity(0.9),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+${validImageUrls.length - 2}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String? instructorName) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
        ),
      ),
      child: Center(
        child: Text(
          instructorName?.isNotEmpty == true 
              ? instructorName![0].toUpperCase() 
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallDefaultAvatar(String? instructorName, int index) {
    final colors = [
      [const Color(0xFF00D4FF), const Color(0xFF9C27B0)],
      [const Color(0xFFFF006E), const Color(0xFF8338EC)],
      [const Color(0xFF06FFA5), const Color(0xFF00D4FF)],
    ];
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: colors[index % colors.length],
        ),
      ),
      child: Center(
        child: Text(
          instructorName?.isNotEmpty == true 
              ? instructorName![0].toUpperCase() 
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 