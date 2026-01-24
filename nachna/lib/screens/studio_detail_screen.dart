import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

import '../models/studio.dart';
import '../services/api_service.dart';
import '../widgets/workshop_detail_modal.dart';
import '../models/workshop.dart';
import '../services/deep_link_service.dart';
import '../services/share_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/payment_link_utils.dart';
import '../utils/string_extensions.dart';
import '../utils/url_launcher_utils.dart';
import '../widgets/cached_image.dart';
import 'artist_detail_screen.dart';

class StudioDetailScreen extends StatefulWidget {
  final Studio studio;

  const StudioDetailScreen({super.key, required this.studio});

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

  Future<void> _launchInstagram(String instagramUrl) async {
    await UrlLauncherUtils.launchInstagram(instagramUrl);
  }

  Future<void> _shareStudio() async {
    try {
      final shareUrl = DeepLinkService.generateStudioShareUrl(widget.studio.id);
      final shareText = 'Check out ${widget.studio.name.toTitleCase()} on Nachna!\n\nDiscover amazing dance workshops at this studio.\n\nOpen in Nachna app: $shareUrl\n\nDon\'t have Nachna yet? Download it here:\nhttps://apps.apple.com/in/app/nachna/id6746702742';

      await ShareService.showShareOptions(
        context: context,
        text: shareText,
        instagramShareUrl: shareUrl,
        instagramTopColor: '#9D4EDD',
        instagramBottomColor: '#00D4FF',
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
                                child: widget.studio.id.isNotEmpty
                                    ? CachedImage.rectangular(
                                        imageUrl: 'https://nachna.com/api/image/studio/${widget.studio.id}',
                                        borderRadius: ResponsiveUtils.spacingLarge(context),
                                        fallbackText: widget.studio.name,
                                        fallbackGradientColors: [
                                          const Color(0xFF00D4FF).withOpacity(0.7),
                                          const Color(0xFF9D4EDD).withOpacity(0.7),
                                        ],
                                      )
                                    : _buildStudioIcon(),
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
                                            widget.studio.name.toTitleCase(),
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

  Widget _buildArtistInstagramIcons(WorkshopSession workshop) {
    final links = (workshop.artistInstagramLinks ?? [])
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

  Future<void> _launchInstagramProfile(String instagramUrl) async {
    await UrlLauncherUtils.launchInstagramProfile(instagramUrl, context: context);
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
                          'Artists\' Instagram',
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

  Widget _buildArtistAvatars(WorkshopSession workshop) {
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
              ? CachedImage.rectangular(
                  imageUrl: 'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(validImageUrls[0]!)}',
                  width: 42,
                  height: 42,
                  borderRadius: 10,
                  fallbackText: workshop.artist,
                  fallbackGradientColors: const [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                )
              : _buildDefaultAvatar(workshop.artist),
        ),
      );
    }
    
    // Multiple artists - show overlapping avatars
    final maxAvatars = validImageUrls.length > 3 ? 3 : validImageUrls.length;
    const avatarSize = 36.0;
    const overlapOffset = 24.0;
    
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
                  child: CachedImage.rectangular(
                    imageUrl: 'https://nachna.com/api/proxy-image/?url=${Uri.encodeComponent(validImageUrls[i]!)}',
                    width: avatarSize,
                    height: avatarSize,
                    borderRadius: 6,
                    fallbackText: workshop.artist,
                    fallbackGradientColors: _getAvatarGradientColors(i),
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

  List<Color> _getAvatarGradientColors(int index) {
    final colors = [
      [const Color(0xFF00D4FF), const Color(0xFF9C27B0)],
      [const Color(0xFFFF006E), const Color(0xFF8338EC)],
      [const Color(0xFF06FFA5), const Color(0xFF00D4FF)],
    ];
    return colors[index % colors.length];
  }

  Widget _buildSmallDefaultAvatar(String? instructorName, int index) {
    final colors = _getAvatarGradientColors(index);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: colors,
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

  // Helper method to convert WorkshopListItem to WorkshopSession
  WorkshopSession _convertToWorkshopSession(WorkshopListItem workshop) {
    return WorkshopSession(
      uuid: workshop.uuid,
      date: workshop.date ?? 'TBA',
      time: workshop.time ?? 'TBA',
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
            ...daySchedule.workshops.map((workshop) => Padding(
              padding: EdgeInsets.only(bottom: ResponsiveUtils.spacingSmall(context)),
              child: _buildWorkshopCard(_convertToWorkshopSession(workshop)),
            )),
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
                              workshop.artist?.isNotEmpty == true && workshop.artist != 'TBA'
                                  ? workshop.artist!.toTitleCase()
                                  : 'Dance Workshop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ResponsiveUtils.body2(context),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
                          _buildArtistInstagramIcons(workshop),
                        ],
                      ),
                    ),

                    // Date Badge (aligned with artist name)
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
                    // Artist Avatars
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
                              workshop.song!.toTitleCase(),
                              style: TextStyle(
                                color: const Color(0xFF00D4FF),
                                fontSize: ResponsiveUtils.caption(context),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          SizedBox(height: ResponsiveUtils.spacingXSmall(context) * 0.5),
                          
                          // Studio (we know it's the current studio, so we can show it or skip it)
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
                                  widget.studio.name.toTitleCase(),
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
                                    'artist': workshop.artist,
                                    'studio': widget.studio.name,
                                    'date': workshop.date,
                                    'time': workshop.time,
                                    'pricing': workshop.pricingInfo,
                                  },
                                  workshopUuid: workshopIdentifier,
                                  workshop: workshop,
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
}
