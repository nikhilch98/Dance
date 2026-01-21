import 'workshop.dart';

/// Model representing an Instagram Reel extracted from a workshop's choreoInstaLink.
/// This is a lightweight wrapper that provides embed URL generation and
/// workshop context for display in the Reels tab.
/// 
/// Supports both Instagram embeds (legacy) and native video playback
/// via the GridFS-backed video storage system.
class Reel {
  final String workshopUuid;
  final String instagramUrl;
  final String? reelId;
  final String? songName;
  final String? artistName;
  final List<String>? artistIdList;
  final List<String?>? artistImageUrls;
  final List<String?>? artistInstagramLinks;
  final String studioName;
  final String studioId;
  final String? date;
  final String? time;
  final String? paymentLink;
  final String? paymentLinkType;
  final String? pricingInfo;
  final double? currentPrice;
  final int timestampEpoch;
  
  // New video fields for native playback
  final String? choreoLinkId;  // ID from choreo_links collection
  final String? videoUrl;      // Direct video streaming URL
  final String? videoStatus;   // pending, processing, completed, failed
  final bool hasVideo;         // Whether native video is available

  Reel({
    required this.workshopUuid,
    required this.instagramUrl,
    this.reelId,
    this.songName,
    this.artistName,
    this.artistIdList,
    this.artistImageUrls,
    this.artistInstagramLinks,
    required this.studioName,
    required this.studioId,
    this.date,
    this.time,
    this.paymentLink,
    this.paymentLinkType,
    this.pricingInfo,
    this.currentPrice,
    required this.timestampEpoch,
    // New video fields
    this.choreoLinkId,
    this.videoUrl,
    this.videoStatus,
    this.hasVideo = false,
  });

  /// Extracts the reel ID from an Instagram URL.
  /// Supports formats:
  /// - https://www.instagram.com/reel/ABC123/
  /// - https://instagram.com/reel/ABC123
  /// - https://www.instagram.com/p/ABC123/ (posts)
  static String? extractReelId(String url) {
    // Try to match /reel/ pattern first
    final reelPattern = RegExp(r'instagram\.com/reel/([A-Za-z0-9_-]+)');
    final reelMatch = reelPattern.firstMatch(url);
    if (reelMatch != null) {
      return reelMatch.group(1);
    }

    // Try to match /p/ pattern (posts)
    final postPattern = RegExp(r'instagram\.com/p/([A-Za-z0-9_-]+)');
    final postMatch = postPattern.firstMatch(url);
    if (postMatch != null) {
      return postMatch.group(1);
    }

    return null;
  }

  /// Generates the Instagram embed URL for this reel.
  /// Returns null if reelId is not available.
  String? get embedUrl {
    if (reelId == null) return null;
    return 'https://www.instagram.com/reel/$reelId/embed';
  }

  /// Creates a Reel from a WorkshopListItem.
  /// Returns null if the workshop doesn't have a valid choreoInstaLink.
  static Reel? fromWorkshopListItem(WorkshopListItem workshop) {
    if (workshop.choreoInstaLink == null || workshop.choreoInstaLink!.isEmpty) {
      return null;
    }

    final reelId = extractReelId(workshop.choreoInstaLink!);
    if (reelId == null) {
      return null;
    }

    return Reel(
      workshopUuid: workshop.uuid,
      instagramUrl: workshop.choreoInstaLink!,
      reelId: reelId,
      songName: workshop.song,
      artistName: workshop.by,
      artistIdList: workshop.artistIdList,
      artistImageUrls: workshop.artistImageUrls,
      artistInstagramLinks: workshop.artistInstagramLinks,
      studioName: workshop.studioName,
      studioId: workshop.studioId,
      date: workshop.date,
      time: workshop.time,
      paymentLink: workshop.paymentLink,
      paymentLinkType: workshop.paymentLinkType,
      pricingInfo: workshop.pricingInfo,
      currentPrice: workshop.currentPrice,
      timestampEpoch: workshop.timestampEpoch,
    );
  }

  /// Creates a Reel from a WorkshopSession.
  /// Returns null if the workshop doesn't have a valid choreoInstaLink.
  static Reel? fromWorkshopSession(WorkshopSession workshop, String studioName, String studioId) {
    if (workshop.choreoInstaLink == null || workshop.choreoInstaLink!.isEmpty) {
      return null;
    }

    final reelId = extractReelId(workshop.choreoInstaLink!);
    if (reelId == null) {
      return null;
    }

    return Reel(
      workshopUuid: workshop.uuid ?? '',
      instagramUrl: workshop.choreoInstaLink!,
      reelId: reelId,
      songName: workshop.song,
      artistName: workshop.artist,
      artistIdList: workshop.artistIdList,
      artistImageUrls: workshop.artistImageUrls,
      artistInstagramLinks: workshop.artistInstagramLinks,
      studioName: studioName,
      studioId: studioId,
      date: workshop.date,
      time: workshop.time,
      paymentLink: workshop.paymentLink,
      paymentLinkType: workshop.paymentLinkType,
      pricingInfo: workshop.pricingInfo,
      currentPrice: workshop.currentPrice,
      timestampEpoch: workshop.timestampEpoch ?? 0,
    );
  }

  /// Extracts all valid Reels from a CategorizedWorkshopResponse.
  static List<Reel> fromCategorizedResponse(CategorizedWorkshopResponse response) {
    final reels = <Reel>[];

    // Extract from this week's workshops
    for (final daySchedule in response.thisWeek) {
      for (final workshop in daySchedule.workshops) {
        final reel = fromWorkshopListItem(workshop);
        if (reel != null) {
          reels.add(reel);
        }
      }
    }

    // Extract from post this week workshops
    for (final workshop in response.postThisWeek) {
      final reel = fromWorkshopListItem(workshop);
      if (reel != null) {
        reels.add(reel);
      }
    }

    return reels;
  }

  /// Creates a Reel from API response (from /api/reels/videos endpoint).
  static Reel? fromApiResponse(Map<String, dynamic> json) {
    final instagramUrl = json['instagram_url'] as String?;
    if (instagramUrl == null || instagramUrl.isEmpty) {
      return null;
    }

    final reelId = extractReelId(instagramUrl);
    final hasVideo = json['has_video'] as bool? ?? false;
    
    return Reel(
      workshopUuid: json['id'] as String? ?? '',
      instagramUrl: instagramUrl,
      reelId: reelId,
      songName: json['song'] as String?,
      artistName: json['artist_name'] as String?,
      artistIdList: (json['artist_id_list'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      artistImageUrls: null, // Not provided by API
      artistInstagramLinks: null, // Not provided by API
      studioName: json['studio_name'] as String? ?? '',
      studioId: json['studio_id'] as String? ?? '',
      date: null, // Not provided by API
      time: null, // Not provided by API
      paymentLink: null, // Not provided by API
      paymentLinkType: null, // Not provided by API
      pricingInfo: null, // Not provided by API
      currentPrice: null, // Not provided by API
      timestampEpoch: 0, // Not provided by API
      choreoLinkId: json['id'] as String?,
      videoUrl: json['video_url'] as String?,
      videoStatus: json['video_status'] as String?,
      hasVideo: hasVideo,
    );
  }

  /// Creates a copy of this Reel with video fields updated.
  Reel copyWithVideo({
    String? choreoLinkId,
    String? videoUrl,
    String? videoStatus,
    bool? hasVideo,
  }) {
    return Reel(
      workshopUuid: workshopUuid,
      instagramUrl: instagramUrl,
      reelId: reelId,
      songName: songName,
      artistName: artistName,
      artistIdList: artistIdList,
      artistImageUrls: artistImageUrls,
      artistInstagramLinks: artistInstagramLinks,
      studioName: studioName,
      studioId: studioId,
      date: date,
      time: time,
      paymentLink: paymentLink,
      paymentLinkType: paymentLinkType,
      pricingInfo: pricingInfo,
      currentPrice: currentPrice,
      timestampEpoch: timestampEpoch,
      choreoLinkId: choreoLinkId ?? this.choreoLinkId,
      videoUrl: videoUrl ?? this.videoUrl,
      videoStatus: videoStatus ?? this.videoStatus,
      hasVideo: hasVideo ?? this.hasVideo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Reel && other.workshopUuid == workshopUuid;
  }

  @override
  int get hashCode => workshopUuid.hashCode;
}
