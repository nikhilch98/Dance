// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workshop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkshopListItem _$WorkshopListItemFromJson(Map<String, dynamic> json) =>
    WorkshopListItem(
      uuid: json['uuid'] as String,
      paymentLink: json['payment_link'] as String,
      studioId: json['studio_id'] as String,
      studioName: json['studio_name'] as String,
      updatedAt: (json['updated_at'] as num).toDouble(),
      by: json['by'] as String?,
      song: json['song'] as String?,
      pricingInfo: json['pricing_info'] as String?,
      timestampEpoch: (json['timestamp_epoch'] as num).toInt(),
      artistId: json['artist_id'] as String?,
      artistImageUrl: json['artist_image_url'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      eventType: json['event_type'] as String?,
    );

Map<String, dynamic> _$WorkshopListItemToJson(WorkshopListItem instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'payment_link': instance.paymentLink,
      'studio_id': instance.studioId,
      'studio_name': instance.studioName,
      'updated_at': instance.updatedAt,
      'by': instance.by,
      'song': instance.song,
      'pricing_info': instance.pricingInfo,
      'timestamp_epoch': instance.timestampEpoch,
      'artist_id': instance.artistId,
      'artist_image_url': instance.artistImageUrl,
      'date': instance.date,
      'time': instance.time,
      'event_type': instance.eventType,
    };

WorkshopSession _$WorkshopSessionFromJson(Map<String, dynamic> json) =>
    WorkshopSession(
      date: json['date'] as String,
      time: json['time'] as String,
      song: json['song'] as String?,
      studioId: json['studio_id'] as String?,
      artist: json['artist'] as String?,
      artistId: json['artist_id'] as String?,
      paymentLink: json['payment_link'] as String,
      pricingInfo: json['pricing_info'] as String?,
      timestampEpoch: (json['timestamp_epoch'] as num).toInt(),
      eventType: json['event_type'] as String?,
    );

Map<String, dynamic> _$WorkshopSessionToJson(WorkshopSession instance) =>
    <String, dynamic>{
      'date': instance.date,
      'time': instance.time,
      'song': instance.song,
      'studio_id': instance.studioId,
      'artist': instance.artist,
      'artist_id': instance.artistId,
      'payment_link': instance.paymentLink,
      'pricing_info': instance.pricingInfo,
      'timestamp_epoch': instance.timestampEpoch,
      'event_type': instance.eventType,
    };

DaySchedule _$DayScheduleFromJson(Map<String, dynamic> json) => DaySchedule(
      day: json['day'] as String,
      workshops: (json['workshops'] as List<dynamic>)
          .map((e) => WorkshopSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DayScheduleToJson(DaySchedule instance) =>
    <String, dynamic>{
      'day': instance.day,
      'workshops': instance.workshops,
    };

CategorizedWorkshopResponse _$CategorizedWorkshopResponseFromJson(
        Map<String, dynamic> json) =>
    CategorizedWorkshopResponse(
      thisWeek: (json['this_week'] as List<dynamic>)
          .map((e) => DaySchedule.fromJson(e as Map<String, dynamic>))
          .toList(),
      postThisWeek: (json['post_this_week'] as List<dynamic>)
          .map((e) => WorkshopSession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CategorizedWorkshopResponseToJson(
        CategorizedWorkshopResponse instance) =>
    <String, dynamic>{
      'this_week': instance.thisWeek,
      'post_this_week': instance.postThisWeek,
    };
