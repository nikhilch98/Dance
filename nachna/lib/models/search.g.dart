// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchUserResult _$SearchUserResultFromJson(Map<String, dynamic> json) =>
    SearchUserResult(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SearchUserResultToJson(SearchUserResult instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'name': instance.name,
      'profile_picture_url': instance.profilePictureUrl,
      'created_at': instance.createdAt.toIso8601String(),
    };

SearchArtistResult _$SearchArtistResultFromJson(Map<String, dynamic> json) =>
    SearchArtistResult(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      instagramLink: json['instagram_link'] as String,
    );

Map<String, dynamic> _$SearchArtistResultToJson(SearchArtistResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'image_url': instance.imageUrl,
      'instagram_link': instance.instagramLink,
    };

SearchWorkshopResult _$SearchWorkshopResultFromJson(
        Map<String, dynamic> json) =>
    SearchWorkshopResult(
      uuid: json['uuid'] as String,
      song: json['song'] as String?,
      artistNames: (json['artist_names'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      studioName: json['studio_name'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      timestampEpoch: (json['timestamp_epoch'] as num).toInt(),
      paymentLink: json['payment_link'] as String,
      pricingInfo: json['pricing_info'] as String?,
      eventType: json['event_type'] as String?,
    );

Map<String, dynamic> _$SearchWorkshopResultToJson(
        SearchWorkshopResult instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'song': instance.song,
      'artist_names': instance.artistNames,
      'studio_name': instance.studioName,
      'date': instance.date,
      'time': instance.time,
      'timestamp_epoch': instance.timestampEpoch,
      'payment_link': instance.paymentLink,
      'pricing_info': instance.pricingInfo,
      'event_type': instance.eventType,
    };
