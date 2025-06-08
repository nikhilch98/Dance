import 'package:flutter/material.dart';
import '../models/workshop.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  late Future<List<WorkshopListItem>> futureWorkshops;
  List<WorkshopListItem> allWorkshops = [];
  List<WorkshopListItem> displayedWorkshops = [];

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
    futureWorkshops = ApiService().fetchAllWorkshops().then((workshops) {
      allWorkshops = workshops;
      _initializeFilters(allWorkshops);
      _applyFilters(); // Apply initial filters (none selected) and sorting
      return workshops;
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
                constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
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
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: accentColor.withOpacity(0.2),
                                ),
                                child: Icon(
                                  Icons.filter_list_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options[index];
                                final isSelected = tempSelected.contains(option);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
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
                                      style: const TextStyle(color: Colors.white),
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
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [accentColor, accentColor.withOpacity(0.8)],
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).pop(tempSelected),
                                    child: const Text(
                                      'Apply',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
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
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                            ),
                            child: const Icon(
                              Icons.event_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Workshops',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF3B82F6).withOpacity(0.3),
                                  const Color(0xFF1D4ED8).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Text(
                              '${displayedWorkshops.length} Found',
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
                      _buildResetButton(),
                    ],
                  ],
                ),
              ),

              // Workshops Table
              Expanded(
                child: FutureBuilder<List<WorkshopListItem>>(
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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                    } else if (!snapshot.hasData || allWorkshops.isEmpty) {
                      return const Center(
                        child: Text(
                          'No workshops found.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      );
                    } else if (displayedWorkshops.isEmpty) {
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
                                Icons.filter_list_off_rounded,
                                size: 48,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No workshops match your filters',
                                style: TextStyle(color: Colors.white70, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Container(
                        margin: const EdgeInsets.all(16),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayedWorkshops.length,
                          itemExtent: 140,
                          cacheExtent: 1000,
                          itemBuilder: (context, index) {
                            final workshop = displayedWorkshops[index];
                            return _buildMobileWorkshopCard(workshop, index);
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

  Widget _buildFilterChip(String label, int count, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(count > 0 ? 0.2 : 0.1),
              color.withOpacity(count > 0 ? 0.1 : 0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(count > 0 ? 0.5 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              count > 0 ? '$label ($count)' : label,
              style: TextStyle(
                color: count > 0 ? color : Colors.white70,
                fontSize: 12,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
        ),
        child: const Icon(
          Icons.clear_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMobileWorkshopCard(WorkshopListItem workshop, int index) {
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
                    // Multiple Artist Avatars
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
                                    content: Text('Could not open Instagram link'),
                                    backgroundColor: Colors.red.withOpacity(0.8),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
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
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Register Button (vertically aligned with main content)
                    SizedBox(
                      width: 65,
                      height: 30,
                      child: workshop.paymentLink.isNotEmpty
                          ? GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(workshop.paymentLink);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Could not launch ${workshop.paymentLink}'),
                                        backgroundColor: Colors.red.withOpacity(0.8),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                                      offset: const Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
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
                                    fontSize: 9,
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
} 