import 'package:flutter/material.dart';
import '../models/studio.dart';
import '../services/api_service.dart';
import '../widgets/workshop_detail_modal.dart';
import '../models/workshop.dart';
import '../services/deep_link_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';
import '../utils/responsive_utils.dart';

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

  Future<void> _shareStudio() async {
    try {
      final shareUrl = DeepLinkService.generateStudioShareUrl(widget.studio.id);
      final shareText = 'Check out ${toTitleCase(widget.studio.name)} on Nachna! 💃🕺\n\nDiscover amazing dance workshops at this studio.\n\nOpen in Nachna app: $shareUrl\n\nDon\'t have Nachna yet? Download it here:\nhttps://apps.apple.com/in/app/nachna/id6746702742';
      
      await Share.share(
        shareText,
        subject: 'Discover ${toTitleCase(widget.studio.name)} on Nachna',
      );
    } catch (e) {
      print('Error sharing studio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to share studio'),
            backgroundColor: Colors.red.withOpacity(0.8),
          ),
        );
      }
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
        child: Stack(
          children: [
            // Main scrollable content
            SafeArea(
              child: ListView(
                padding: EdgeInsets.only(top: ResponsiveUtils.spacingXXLarge(context) * 2),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Studio Header with Image and Info
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
                      ],
                    ),
                    child: Container(
                      padding: ResponsiveUtils.paddingLarge(context),
                      child: Column(
                        children: [
                          // Studio Image and Name
                          Row(
                            children: [
                              // Studio Image
                              Container(
                                width: ResponsiveUtils.avatarSizeLarge(context),
                                height: ResponsiveUtils.avatarSizeLarge(context),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingXLarge(context)),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00D4FF).withOpacity(0.3),
                                      const Color(0xFF9D4EDD).withOpacity(0.3),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: ResponsiveUtils.borderWidthMedium(context),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
                                  child: widget.studio.imageUrl != null
                                      ? Image.network(
                                          'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(widget.studio.imageUrl!)}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildStudioIcon();
                                          },
                                        )
                                      : _buildStudioIcon(),
                                ),
                              ),
                              SizedBox(width: ResponsiveUtils.spacingXLarge(context)),
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
                                            style: TextStyle(
                                              fontSize: ResponsiveUtils.h3(context),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                        // Instagram Icon aligned with text
                                        GestureDetector(
                                          onTap: () => _launchInstagram(widget.studio.instagramLink),
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
                                    SizedBox(height: ResponsiveUtils.spacingSmall(context)),
                                    // Dance Studio badge with share button
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.spacingMedium(context), 
                                            vertical: ResponsiveUtils.spacingSmall(context)
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
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
                                                size: ResponsiveUtils.iconXSmall(context),
                                              ),
                                              SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                              Text(
                                                'Dance Studio',
                                                style: TextStyle(
                                                  color: const Color(0xFF00D4FF),
                                                  fontSize: ResponsiveUtils.micro(context),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                                        // Small Share Button
                                        GestureDetector(
                                          onTap: _shareStudio,
                                          child: Container(
                                            padding: EdgeInsets.all(ResponsiveUtils.spacingSmall(context)),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(ResponsiveUtils.spacingMedium(context)),
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF00D4FF).withOpacity(0.2),
                                                  const Color(0xFF9D4EDD).withOpacity(0.2),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFF00D4FF).withOpacity(0.3),
                                                width: ResponsiveUtils.borderWidthThin(context),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.share_rounded,
                                              size: ResponsiveUtils.iconXSmall(context),
                                              color: const Color(0xFF00D4FF),
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
                  FutureBuilder<CategorizedWorkshopResponse>(
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
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
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
                      } else if (!snapshot.hasData || (snapshot.data!.thisWeek.isEmpty && snapshot.data!.postThisWeek.isEmpty)) {
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
                                  'Check back later for upcoming workshops at ${widget.studio.name}',
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
                        final response = snapshot.data!;
                        final hasThisWeek = response.thisWeek.isNotEmpty;
                        final hasPostThisWeek = response.postThisWeek.isNotEmpty;

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.spacingLarge(context)),
                          child: Column(
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
                                ...response.postThisWeek.map((workshop) => _buildWorkshopCard(_convertToWorkshopSession(workshop))),
                              ],
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

  Widget _buildStudioIcon() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.3),
            const Color(0xFF9D4EDD).withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.business_rounded,
          size: ResponsiveUtils.iconXLarge(context),
          color: Colors.white70,
        ),
      ),
    );
  }

  // Helper method to convert WorkshopListItem to WorkshopSession
  WorkshopSession _convertToWorkshopSession(WorkshopListItem workshop) {
    return WorkshopSession(
      date: workshop.date ?? 'TBA',
      time: workshop.time ?? 'TBA',
      song: workshop.song,
      studioId: workshop.studioId,
      artist: workshop.by,
      artistIdList: workshop.artistIdList,
      paymentLink: workshop.paymentLink,
      pricingInfo: workshop.pricingInfo,
      timestampEpoch: workshop.timestampEpoch,
      eventType: workshop.eventType,
      choreoInstaLink: workshop.choreoInstaLink,
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
            
            // Workshops for this day - convert WorkshopListItem to WorkshopSession
            ...daySchedule.workshops.map((workshop) => _buildWorkshopCard(_convertToWorkshopSession(workshop))),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(WorkshopSession workshop) {
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
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                        color: const Color(0xFF00D4FF),
                        fontSize: ResponsiveUtils.caption(context),
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
                        size: ResponsiveUtils.iconXSmall(context),
                      ),
                      SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                      Expanded(
                        child: Text(
                          toTitleCase(workshop.artist!),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
