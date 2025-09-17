import 'package:json_annotation/json_annotation.dart';

part 'workshop.g.dart';

@JsonSerializable()
class WorkshopListItem {
  final String uuid;
  @JsonKey(name: 'payment_link')
  final String paymentLink;
  @JsonKey(name: 'payment_link_type')
  final String? paymentLinkType;
  @JsonKey(name: 'studio_id')
  final String studioId;
  @JsonKey(name: 'studio_name')
  final String studioName;
  @JsonKey(name: 'updated_at')
  final double updatedAt;
  final String? by;
  final String? song;
  @JsonKey(name: 'pricing_info')
  final String? pricingInfo;
  @JsonKey(name: 'current_price')
  final double? currentPrice;
  @JsonKey(name: 'timestamp_epoch')
  final int timestampEpoch;
  @JsonKey(name: 'artist_id_list')
  final List<String>? artistIdList;
  @JsonKey(name: 'artist_image_urls')
  final List<String?>? artistImageUrls;
  @JsonKey(name: 'artist_instagram_links')
  final List<String?>? artistInstagramLinks;
  final String? date;
  final String? time;
  @JsonKey(name: 'event_type')
  final String? eventType;
  @JsonKey(name: 'choreo_insta_link')
  final String? choreoInstaLink;

  WorkshopListItem({
    required this.uuid,
    required this.paymentLink,
    this.paymentLinkType,
    required this.studioId,
    required this.studioName,
    required this.updatedAt,
    this.by,
    this.song,
    this.pricingInfo,
    this.currentPrice,
    required this.timestampEpoch,
    this.artistIdList,
    this.artistImageUrls,
    this.artistInstagramLinks,
    this.date,
    this.time,
    this.eventType,
    this.choreoInstaLink,
  });

  factory WorkshopListItem.fromJson(Map<String, dynamic> json) => _$WorkshopListItemFromJson(json);
  Map<String, dynamic> toJson() => _$WorkshopListItemToJson(this);
}

@JsonSerializable()
class WorkshopSession {
  final String? uuid;
  final String? date;
  final String? time;
  final String? song;
  @JsonKey(name: 'studio_id')
  final String? studioId;
  final String? artist;
  @JsonKey(name: 'artist_id_list')
  final List<String>? artistIdList;
  @JsonKey(name: 'artist_image_urls')
  final List<String?>? artistImageUrls;
  @JsonKey(name: 'artist_instagram_links')
  final List<String?>? artistInstagramLinks;
  @JsonKey(name: 'payment_link')
  final String? paymentLink;
  @JsonKey(name: 'payment_link_type')
  final String? paymentLinkType;
  @JsonKey(name: 'pricing_info')
  final String? pricingInfo;
  @JsonKey(name: 'current_price')
  final double? currentPrice;
  @JsonKey(name: 'timestamp_epoch')
  final int? timestampEpoch;
  @JsonKey(name: 'event_type')
  final String? eventType;
  @JsonKey(name: 'choreo_insta_link')
  final String? choreoInstaLink;

  // Getter for unique workshop ID
  String get id => timestampEpoch?.toString() ?? 'unknown';

  WorkshopSession({
    this.uuid,
    this.date,
    this.time,
    this.song,
    this.studioId,
    this.artist,
    this.artistIdList,
    this.artistImageUrls,
    this.artistInstagramLinks,
    this.paymentLink,
    this.paymentLinkType,
    this.pricingInfo,
    this.currentPrice,
    this.timestampEpoch,
    this.eventType,
    this.choreoInstaLink,
  });

  factory WorkshopSession.fromJson(Map<String, dynamic> json) => _$WorkshopSessionFromJson(json);
  Map<String, dynamic> toJson() => _$WorkshopSessionToJson(this);
}

@JsonSerializable()
class DaySchedule {
  final String day;
  final List<WorkshopListItem> workshops;

  DaySchedule({
    required this.day,
    required this.workshops,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) => _$DayScheduleFromJson(json);
  Map<String, dynamic> toJson() => _$DayScheduleToJson(this);
}

@JsonSerializable()
class CategorizedWorkshopResponse {
  @JsonKey(name: 'this_week')
  final List<DaySchedule> thisWeek;
  @JsonKey(name: 'post_this_week')
  final List<WorkshopListItem> postThisWeek;

  CategorizedWorkshopResponse({
    required this.thisWeek,
    required this.postThisWeek,
  });

  factory CategorizedWorkshopResponse.fromJson(Map<String, dynamic> json) => _$CategorizedWorkshopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CategorizedWorkshopResponseToJson(this);
} 