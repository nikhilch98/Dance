import 'package:json_annotation/json_annotation.dart';

part 'studio.g.dart';

@JsonSerializable()
class Studio {
  final String id;
  final String name;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'instagram_link')
  final String instagramLink;

  Studio({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.instagramLink,
  });

  factory Studio.fromJson(Map<String, dynamic> json) => _$StudioFromJson(json);
  Map<String, dynamic> toJson() => _$StudioToJson(this);
} 