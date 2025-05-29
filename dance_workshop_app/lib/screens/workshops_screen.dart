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
                            'All Workshops',
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
                        'Instructor',
                        selectedInstructors.length,
                        const Color(0xFFFF006E),
                        () => _showFilterDialog(
                          title: 'Filter by Instructor',
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
                          itemExtent: 220,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with date and time
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                        ),
                        child: Text(
                          workshop.date ?? 'TBA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          workshop.time ?? 'TBA',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Instructor and Song
                if (workshop.by != null && workshop.by!.isNotEmpty && workshop.by != 'TBA')
                  _buildInfoRow(
                    Icons.person_rounded,
                    'Instructor',
                    workshop.by!,
                    const Color(0xFFFF006E),
                  ),
                
                if (workshop.song != null && workshop.song!.isNotEmpty && workshop.song != 'TBA')
                  _buildInfoRow(
                    Icons.music_note_rounded,
                    'Song',
                    workshop.song!,
                    const Color(0xFF8B5CF6),
                  ),
                
                _buildInfoRow(
                  Icons.business_rounded,
                  'Studio',
                  workshop.studioName,
                  const Color(0xFF00D4FF),
                ),
                
                if (workshop.pricingInfo != null && workshop.pricingInfo!.isNotEmpty && workshop.pricingInfo != 'TBA')
                  _buildInfoRow(
                    Icons.attach_money_rounded,
                    'Pricing',
                    workshop.pricingInfo!,
                    const Color(0xFF10B981),
                  ),
                
                const SizedBox(height: 16),
                
                // Register button
                SizedBox(
                  width: double.infinity,
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.app_registration_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Register Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                color: Colors.white38,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Registration Coming Soon',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 