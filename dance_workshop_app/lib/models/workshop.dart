import 'package:json_annotation/json_annotation.dart';

part 'workshop.g.dart';

@JsonSerializable()
class WorkshopListItem {
  final String uuid;
  @JsonKey(name: 'payment_link')
  final String paymentLink;
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
  @JsonKey(name: 'timestamp_epoch')
  final int timestampEpoch;
  @JsonKey(name: 'artist_id')
  final String? artistId;
  final String? date;
  final String? time;
  @JsonKey(name: 'event_type')
  final String? eventType;

  WorkshopListItem({
    required this.uuid,
    required this.paymentLink,
    required this.studioId,
    required this.studioName,
    required this.updatedAt,
    this.by,
    this.song,
    this.pricingInfo,
    required this.timestampEpoch,
    this.artistId,
    this.date,
    this.time,
    this.eventType,
  });

  factory WorkshopListItem.fromJson(Map<String, dynamic> json) => _$WorkshopListItemFromJson(json);
  Map<String, dynamic> toJson() => _$WorkshopListItemToJson(this);
}

@JsonSerializable()
class WorkshopSession {
  final String date;
  final String time;
  final String? song;
  @JsonKey(name: 'studio_id')
  final String? studioId;
  final String? artist;
  @JsonKey(name: 'artist_id')
  final String? artistId;
  @JsonKey(name: 'payment_link')
  final String paymentLink;
  @JsonKey(name: 'pricing_info')
  final String? pricingInfo;
  @JsonKey(name: 'timestamp_epoch')
  final int timestampEpoch;
  @JsonKey(name: 'event_type')
  final String? eventType;

  WorkshopSession({
    required this.date,
    required this.time,
    this.song,
    this.studioId,
    this.artist,
    this.artistId,
    required this.paymentLink,
    this.pricingInfo,
    required this.timestampEpoch,
    this.eventType,
  });

  factory WorkshopSession.fromJson(Map<String, dynamic> json) => _$WorkshopSessionFromJson(json);
  Map<String, dynamic> toJson() => _$WorkshopSessionToJson(this);
}

@JsonSerializable()
class DaySchedule {
  final String day;
  final List<WorkshopSession> workshops;

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
  final List<WorkshopSession> postThisWeek;

  CategorizedWorkshopResponse({
    required this.thisWeek,
    required this.postThisWeek,
  });

  factory CategorizedWorkshopResponse.fromJson(Map<String, dynamic> json) => _$CategorizedWorkshopResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CategorizedWorkshopResponseToJson(this);
} 