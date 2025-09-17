import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

import '../models/workshop.dart';
import '../services/api_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/payment_link_utils.dart';
import '../models/artist.dart';
import 'artist_detail_screen.dart';

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  late Future<CategorizedWorkshopResponse> futureWorkshops;
  List<WorkshopListItem> allWorkshops = [];
  List<WorkshopListItem> displayedWorkshops = [];
  CategorizedWorkshopResponse? categorizedWorkshops;

  // State variables for filters
  List<String> availableDates = [];
  List<String> availableInstructors = [];
  List<String> availableStudios = [];

  List<String> selectedDates = [];
  List<String> selectedInstructors = [];
  List<String> selectedStudios = [];

  // State variables for sorting
  String currentSortColumn = 'date'; // Default sort column
  bool isSortAscending = true; // Default sort direction

  // Helper method to convert text to title case
  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  void initState() {
    super.initState();
    futureWorkshops = ApiService().fetchAllWorkshops().then((response) {
      // Flatten the categorized response into a single list for filtering
      List<WorkshopListItem> allWorkshopsList = [];
      
      // Add workshops from this week
      for (var daySchedule in response.thisWeek) {
        allWorkshopsList.addAll(daySchedule.workshops);
      }
      
      // Add workshops from post this week
      allWorkshopsList.addAll(response.postThisWeek);
      
      allWorkshops = allWorkshopsList;
      categorizedWorkshops = response;
      _initializeFilters(allWorkshops);
      _applyFilters(); // Apply initial filters (none selected) and sorting
      return response;
    });
  }

  void _initializeFilters(List<WorkshopListItem> workshops) {
    // Extract unique values for each filter, filtering out null/empty/TBA values
    availableDates = workshops
        .where((w) => w.date != null && w.date!.isNotEmpty && w.date != 'TBA')
        .map((w) => w.date!)
        .toSet()
        .toList()
      ..sort();
    
    availableInstructors = workshops
        .where((w) => w.by != null && w.by!.isNotEmpty && w.by != 'TBA')
        .map((w) => w.by!)
        .toSet()
        .toList()
      ..sort();
    
    availableStudios = workshops
        .where((w) => w.studioName.isNotEmpty && w.studioName != 'TBA')
        .map((w) => w.studioName)
        .toSet()
        .toList()
      ..sort();

    setState(() {}); // Update UI after initializing filters
  }

  void _applyFilters() {
    setState(() {
      displayedWorkshops = allWorkshops.where((workshop) {
        // Date filter
        if (selectedDates.isNotEmpty && (workshop.date == null || !selectedDates.contains(workshop.date!))) {
          return false;
        }
        // Instructor filter
        if (selectedInstructors.isNotEmpty && (workshop.by == null || !selectedInstructors.contains(workshop.by!))) {
          return false;
        }
        // Studio filter
        if (selectedStudios.isNotEmpty && !selectedStudios.contains(workshop.studioName)) {
          return false;
        }
        return true; // Keep the workshop if it passes all filters
      }).toList();
      _applySorting(); // Apply sorting after filtering
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

   // Helper method to show filter dialog with modern design
  Future<void> _showFilterDialog({
    required String title,
    required List<String> options,
    required List<String> selected,
    required Function(List<String>) onSelected,
    required Color accentColor,
  }) async {
    List<String> tempSelected = List.from(selected);
    await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: ResponsiveUtils.screenHeight(context) * 0.7, 
                  maxWidth: ResponsiveUtils.screenWidth(context) * 0.9
                ),
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
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: ResponsiveUtils.paddingXLarge(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: ResponsiveUtils.paddingSmall(context),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                  color: accentColor.withOpacity(0.2),
                                ),
                                child: Icon(
                                  Icons.filter_list_rounded,
                                  color: accentColor,
                                  size: ResponsiveUtils.iconSmall(context),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.h3(context),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options[index];
                                final isSelected = tempSelected.contains(option);
                                return Container(
                                  margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                    color: isSelected
                                        ? accentColor.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    title: Text(
                                      option,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: ResponsiveUtils.body2(context),
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          tempSelected.add(option);
                                        } else {
                                          tempSelected.remove(option);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    checkColor: Colors.white,
                                    activeColor: accentColor,
                                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: ResponsiveUtils.body2(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingMedium(context)),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                    gradient: LinearGradient(
                                      colors: [accentColor, accentColor.withOpacity(0.8)],
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).pop(tempSelected),
                                    child: Text(
                                      'Apply',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: ResponsiveUtils.body2(context),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result != null) {
        onSelected(result);
        _applyFilters();
      }
    });
  }

  void _applySorting() {
    displayedWorkshops.sort((a, b) {
      int comparisonResult = 0;

      switch (currentSortColumn) {
        case 'date':
        case 'time':
          // Use timestampEpoch for accurate date/time sorting
          comparisonResult = (a.timestampEpoch).compareTo(b.timestampEpoch);
          break;
        case 'instructor':
          comparisonResult = (a.by ?? '').toLowerCase().compareTo((b.by ?? '').toLowerCase());
          break;
        case 'song':
          comparisonResult = (a.song ?? '').toLowerCase().compareTo((b.song ?? '').toLowerCase());
          break;
        case 'studio':
          comparisonResult = a.studioName.toLowerCase().compareTo(b.studioName.toLowerCase());
          break;
      }

      return isSortAscending ? comparisonResult : -comparisonResult;
    });
  }

  void _onSortColumn(String column) {
    setState(() {
      if (currentSortColumn == column) {
        isSortAscending = !isSortAscending;
      } else {
        currentSortColumn = column;
        isSortAscending = true;
      }
      _applySorting(); // Apply sorting immediately
    });
  }

  // Open Instagram app if possible, else fallback to web
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open Instagram link'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
    }
  }

  Widget _buildArtistInstagramIcons(WorkshopListItem workshop) {
    final links = (workshop.artistInstagramLinks ?? [])
        .where((e) => (e ?? '').isNotEmpty)
        .cast<String>()
        .toList();

    if (links.isEmpty) return const SizedBox.shrink();

    final maxIcons = 3;
    final showCount = links.length > maxIcons ? maxIcons : links.length;

    List<Widget> icons = List.generate(showCount, (i) {
      return Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : ResponsiveUtils.spacingXSmall(context)),
        child: GestureDetector(
          onTap: () => _launchInstagramProfile(links[i]),
          child: SizedBox(
            width: ResponsiveUtils.iconSmall(context),
            height: ResponsiveUtils.iconSmall(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'instagram-icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
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
                  );
                },
              ),
            ),
          ),
        ),
      );
    });

    if (links.length > maxIcons) {
      final remaining = links.length - maxIcons;
      icons.add(
        Padding(
          padding: EdgeInsets.only(left: ResponsiveUtils.spacingXSmall(context)),
          child: GestureDetector(
            onTap: () => _showInstagramLinksSheet(links),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacingXSmall(context),
                vertical: 2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF006E).withOpacity(0.25),
                    const Color(0xFF8338EC).withOpacity(0.25),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                '+$remaining',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.micro(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  Future<void> _showInstagramLinksSheet(List<String> links) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(ResponsiveUtils.spacingLarge(context)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: ResponsiveUtils.borderWidthThin(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: ResponsiveUtils.paddingLarge(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.spacingXSmall(context)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(colors: [Color(0xFFE4405F), Color(0xFFFCAF45)]),
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: ResponsiveUtils.iconXSmall(context)),
                        ),
                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                        Text(
                          'Artists’ Instagram',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.body1(context),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: Colors.white70, size: ResponsiveUtils.iconSmall(context)),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                    ...links.map((l) => Padding(
                          padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.of(context).pop();
                              await _launchInstagramProfile(l);
                            },
                            child: Row(
                              children: [
                                SizedBox(
                                  width: ResponsiveUtils.iconMedium(context),
                                  height: ResponsiveUtils.iconMedium(context),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset('assets/icons/instagram.png', fit: BoxFit.cover),
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                Expanded(
                                  child: Text(
                                    l,
                                    style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.body2(context)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.open_in_new_rounded, color: Colors.white70, size: ResponsiveUtils.iconXSmall(context)),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
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
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                            ),
                            child: Icon(
                              Icons.event_rounded,
                              color: Colors.white,
                              size: ResponsiveUtils.iconMedium(context),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingLarge(context)),
                          Text(
                            'Workshops',
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
                                  const Color(0xFF3B82F6).withOpacity(0.3),
                                  const Color(0xFF1D4ED8).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Text(
                              '${displayedWorkshops.length} Found',
                              style: TextStyle(
                                color: const Color(0xFF3B82F6),
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
              
              // Modern Filter Controls
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.spacingLarge(context), 
                  vertical: ResponsiveUtils.spacingSmall(context)
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        'Date',
                        selectedDates.length,
                        const Color(0xFF10B981),
                        () => _showFilterDialog(
                          title: 'Filter by Date',
                          options: availableDates,
                          selected: selectedDates,
                          onSelected: (newSelected) => selectedDates = newSelected,
                          accentColor: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    Expanded(
                      child: _buildFilterChip(
                        'Artist',
                        selectedInstructors.length,
                        const Color(0xFFFF006E),
                        () => _showFilterDialog(
                          title: 'Filter by Artist',
                          options: availableInstructors,
                          selected: selectedInstructors,
                          onSelected: (newSelected) => selectedInstructors = newSelected,
                          accentColor: const Color(0xFFFF006E),
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    Expanded(
                      child: _buildFilterChip(
                        'Studio',
                        selectedStudios.length,
                        const Color(0xFF8B5CF6),
                        () => _showFilterDialog(
                          title: 'Filter by Studio',
                          options: availableStudios,
                          selected: selectedStudios,
                          onSelected: (newSelected) => selectedStudios = newSelected,
                          accentColor: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    if (selectedDates.isNotEmpty || selectedInstructors.isNotEmpty || selectedStudios.isNotEmpty) ...[
                      SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                      _buildResetButton(),
                    ],
                  ],
                ),
              ),

              // Workshops Table
              Expanded(
                child: FutureBuilder<CategorizedWorkshopResponse>(
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
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(
                                color: Colors.redAccent, 
                                fontSize: ResponsiveUtils.body2(context)
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      } else if (!snapshot.hasData || allWorkshops.isEmpty) {
                        return Center(
                          child: Text(
                            'No workshops found.',
                            style: TextStyle(
                              color: Colors.white70, 
                              fontSize: ResponsiveUtils.body1(context)
                            ),
                          ),
                        );
                      } else if (displayedWorkshops.isEmpty) {
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
                                  Icons.filter_list_off_rounded,
                                  size: ResponsiveUtils.iconXLarge(context) * 1.3,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                SizedBox(height: ResponsiveUtils.spacingLarge(context)),
                                Text(
                                  'No workshops match your filters',
                                  style: TextStyle(
                                    color: Colors.white70, 
                                    fontSize: ResponsiveUtils.body1(context)
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Check if filters are active
                        bool hasActiveFilters = selectedDates.isNotEmpty || 
                                              selectedInstructors.isNotEmpty || 
                                              selectedStudios.isNotEmpty;

                        if (hasActiveFilters) {
                          // Show filtered results as a simple list
                          return Container(
                            margin: ResponsiveUtils.paddingLarge(context),
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: displayedWorkshops.length,
                              itemExtent: ResponsiveUtils.isSmallScreen(context) ? 130 : 140,
                              cacheExtent: 1000,
                              itemBuilder: (context, index) {
                                final workshop = displayedWorkshops[index];
                                return _buildMobileWorkshopCard(workshop, index);
                              },
                            ),
                          );
                        } else {
                          // Show categorized workshops when no filters are active
                          final response = snapshot.data!;
                          final hasThisWeek = response.thisWeek.isNotEmpty;
                          final hasPostThisWeek = response.postThisWeek.isNotEmpty;

                          return Container(
                            margin: ResponsiveUtils.paddingLarge(context),
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // This Week section
                                if (hasThisWeek) ...[
                                  _buildSectionHeader('This Week', Icons.calendar_today_rounded, const Color(0xFF00D4FF)),
                                  SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                                  ...response.thisWeek.map((daySchedule) => _buildDaySection(daySchedule)),
                                ],

                                // Spacing between sections
                                if (hasThisWeek && hasPostThisWeek) SizedBox(height: ResponsiveUtils.spacingXXLarge(context) * 1.3),

                                // Upcoming Workshops section
                                if (hasPostThisWeek) ...[
                                  _buildSectionHeader('Upcoming Workshops', Icons.upcoming_rounded, const Color(0xFF9D4EDD)),
                                  SizedBox(height: ResponsiveUtils.spacingMedium(context)),
                                  ...response.postThisWeek.map((workshop) => _buildMobileWorkshopCard(workshop, response.postThisWeek.indexOf(workshop))),
                                ],
                                SizedBox(height: ResponsiveUtils.spacingXLarge(context)),
                              ],
                            ),
                          );
                        }
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

  Widget _buildFilterChip(String label, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context), 
          vertical: ResponsiveUtils.spacingSmall(context)
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(count > 0 ? 0.2 : 0.1),
              color.withOpacity(count > 0 ? 0.1 : 0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(count > 0 ? 0.5 : 0.2),
            width: ResponsiveUtils.borderWidthThin(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: ResponsiveUtils.iconXSmall(context),
              color: color,
            ),
            SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
            Flexible(
              child: Text(
                count > 0 ? '$label ($count)' : label,
                style: TextStyle(
                  color: count > 0 ? color : Colors.white70,
                  fontSize: ResponsiveUtils.micro(context),
                  fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _resetFilters,
      child: Container(
        padding: ResponsiveUtils.paddingSmall(context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
        ),
        child: Icon(
          Icons.clear_rounded,
          color: Colors.white,
          size: ResponsiveUtils.iconSmall(context),
        ),
      ),
    );
  }

  Widget _buildMobileWorkshopCard(WorkshopListItem workshop, int index) {
    return Container(
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
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Padding(
            padding: ResponsiveUtils.paddingMedium(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row with Artist Name + Instagram icons and Date Badge
                Row(
                  children: [
                    // Name + Instagram icons tightly beside the name (no extra gap)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              workshop.by?.isNotEmpty == true && workshop.by != 'TBA'
                                  ? toTitleCase(workshop.by!)
                                  : 'Dance Workshop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.body2(context),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                          _buildArtistInstagramIcons(workshop),
                        ],
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),

                    // Date Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.spacingSmall(context), 
                        vertical: ResponsiveUtils.spacingXSmall(context)
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                      ),
                      child: Text(
                        workshop.date ?? 'TBA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.micro(context) * 0.9,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                
                // Main Content Row with register button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Multiple Artist Avatars
                    _buildArtistAvatars(workshop),
                    
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    
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
                                  toTitleCase(workshop.studioName),
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
                          
                          // Time
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                color: Colors.white.withOpacity(0.7),
                                size: ResponsiveUtils.iconXSmall(context),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingXSmall(context) * 0.7),
                              Expanded(
                                child: Text(
                                  workshop.time ?? 'TBA',
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
                        ],
                      ),
                    ),
                    
                    SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                    
                    // Play Button (if choreo link is available)
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
                            width: ResponsiveUtils.iconLarge(context),
                            height: ResponsiveUtils.iconLarge(context),
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
                                size: ResponsiveUtils.iconSmall(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Register Button (vertically aligned with main content)
                    SizedBox(
                      width: workshop.paymentLinkType?.toLowerCase() == 'nachna' 
                        ? (ResponsiveUtils.isSmallScreen(context) ? 85 : 95)
                        : (ResponsiveUtils.isSmallScreen(context) ? 60 : 65),
                      height: ResponsiveUtils.iconLarge(context),
                      child: ((workshop.paymentLink?.isNotEmpty ?? false) || workshop.paymentLinkType?.toLowerCase() == 'nachna')
                          ? GestureDetector(
                              onTap: () async {
                                // Ensure workshop UUID or timestamp is available before proceeding
                                final workshopIdentifier = workshop.uuid?.isNotEmpty == true
                                    ? workshop.uuid!
                                    : workshop.timestampEpoch?.toString();

                                if (workshopIdentifier == null || workshopIdentifier.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Workshop information not available'),
                                      backgroundColor: Colors.red.withOpacity(0.8),
                                    ),
                                  );
                                  return;
                                }
                                
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
                                  workshopUuid: workshopIdentifier,
                                  workshop: WorkshopSession(
                                    uuid: workshop.uuid,
                                    date: workshop.date,
                                    time: workshop.time,
                                    song: workshop.song,
                                    studioId: workshop.studioId,
                                    artist: workshop.by,
                                    artistIdList: workshop.artistIdList,
                                    artistImageUrls: workshop.artistImageUrls,
                                    artistInstagramLinks: workshop.artistInstagramLinks,
                                    paymentLink: workshop.paymentLink,
                                    paymentLinkType: workshop.paymentLinkType,
                                    pricingInfo: workshop.pricingInfo,
                                    currentPrice: workshop.currentPrice,
                                    timestampEpoch: workshop.timestampEpoch,
                                    eventType: workshop.eventType,
                                    choreoInstaLink: workshop.choreoInstaLink,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                  gradient: workshop.paymentLinkType?.toLowerCase() == 'nachna' 
                                    ? const LinearGradient(
                                        colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: workshop.paymentLinkType?.toLowerCase() == 'nachna'
                                        ? const Color(0xFF00D4FF).withOpacity(0.3)
                                        : const Color(0xFF3B82F6).withOpacity(0.3),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    workshop.paymentLinkType?.toLowerCase() == 'nachna' 
                                      ? 'Register with nachna'
                                      : 'Register',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.micro(context) * 0.85,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingSmall(context)),
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Soon',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: ResponsiveUtils.micro(context) * 0.9,
                                    fontWeight: FontWeight.w500,
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
        ),
      ),
    );
  }

  Widget _buildArtistAvatars(WorkshopListItem workshop) {
    final artistImageUrls = workshop.artistImageUrls ?? [];
    final artistIdList = workshop.artistIdList ?? [];
    final validImageUrls = artistImageUrls.where((url) => url != null && url.isNotEmpty).toList();

    // If no valid images or only one artist, show single avatar
    if (validImageUrls.length <= 1) {
      return GestureDetector(
        onTap: () {
          if (artistIdList.isNotEmpty && artistIdList[0].isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ArtistDetailScreen(artistId: artistIdList[0])),
            );
          }
        },
        child: Container(
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
        ),
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
              child: GestureDetector(
                onTap: () {
                  if (artistIdList.length > i && artistIdList[i].isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ArtistDetailScreen(artistId: artistIdList[i])),
                    );
                  }
                },
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
              ? instructorName!.substring(0, 1).toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.spacingXLarge(context), 
        vertical: ResponsiveUtils.spacingLarge(context)
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: ResponsiveUtils.borderWidthThin(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: ResponsiveUtils.paddingSmall(context),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
              color: color.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: color,
              size: ResponsiveUtils.iconSmall(context),
            ),
          ),
          SizedBox(width: ResponsiveUtils.spacingMedium(context)),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveUtils.body1(context),
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
      margin: EdgeInsets.only(bottom: ResponsiveUtils.spacingLarge(context)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.cardBorderRadius(context)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: ResponsiveUtils.borderWidthThin(context),
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.paddingLarge(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.spacingMedium(context), 
                vertical: ResponsiveUtils.spacingSmall(context)
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
              ),
              child: Text(
                daySchedule.day,
                style: TextStyle(
                  fontSize: ResponsiveUtils.body2(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingMedium(context)),
            
            // Workshops for this day
            ...daySchedule.workshops.map((workshop) => Padding(
              padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
              child: _buildMobileWorkshopCard(workshop, daySchedule.workshops.indexOf(workshop)),
            )),
          ],
        ),
      ),
    );
  }
}
