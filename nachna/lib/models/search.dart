import 'package:json_annotation/json_annotation.dart';

part 'search.g.dart';

@JsonSerializable()
class SearchUserResult {
  @JsonKey(name: 'user_id')
  final String userId;
  
  final String name;
  
  @JsonKey(name: 'profile_picture_url')
  final String? profilePictureUrl;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  SearchUserResult({
    required this.userId,
    required this.name,
    this.profilePictureUrl,
    required this.createdAt,
  });

  factory SearchUserResult.fromJson(Map<String, dynamic> json) => _$SearchUserResultFromJson(json);
  Map<String, dynamic> toJson() => _$SearchUserResultToJson(this);
}

@JsonSerializable()
class SearchArtistResult {
  final String id;
  final String name;
  
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  
  @JsonKey(name: 'instagram_link')
  final String instagramLink;

  SearchArtistResult({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.instagramLink,
  });

  factory SearchArtistResult.fromJson(Map<String, dynamic> json) => _$SearchArtistResultFromJson(json);
  Map<String, dynamic> toJson() => _$SearchArtistResultToJson(this);
}

@JsonSerializable()
class SearchWorkshopResult {
  final String uuid;
  final String? song;
  
  @JsonKey(name: 'artist_names')
  final List<String> artistNames;
  
  @JsonKey(name: 'artist_id_list')
  final List<String>? artistIdList;
  
  @JsonKey(name: 'artist_image_urls')
  final List<String?>? artistImageUrls;
  
  @JsonKey(name: 'studio_id')
  final String? studioId;
  
  @JsonKey(name: 'studio_name')
  final String studioName;
  
  final String date;
  final String time;
  
  @JsonKey(name: 'timestamp_epoch')
  final int timestampEpoch;
  
  @JsonKey(name: 'payment_link')
  final String paymentLink;
  
  @JsonKey(name: 'pricing_info')
  final String? pricingInfo;
  
  @JsonKey(name: 'event_type')
  final String? eventType;
  
  @JsonKey(name: 'choreo_insta_link')
  final String? choreoInstaLink;

  SearchWorkshopResult({
    required this.uuid,
    this.song,
    required this.artistNames,
    this.artistIdList,
    this.artistImageUrls,
    this.studioId,
    required this.studioName,
    required this.date,
    required this.time,
    required this.timestampEpoch,
    required this.paymentLink,
    this.pricingInfo,
    this.eventType,
    this.choreoInstaLink,
  });

  factory SearchWorkshopResult.fromJson(Map<String, dynamic> json) => _$SearchWorkshopResultFromJson(json);
  Map<String, dynamic> toJson() => _$SearchWorkshopResultToJson(this);
} 