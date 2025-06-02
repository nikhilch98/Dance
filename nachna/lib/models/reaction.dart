enum EntityType { ARTIST }

enum ReactionType { LIKE, FOLLOW }

class ReactionRequest {
  final String entityId;
  final EntityType entityType;
  final ReactionType reaction;

  ReactionRequest({
    required this.entityId,
    required this.entityType,
    required this.reaction,
  });

  Map<String, dynamic> toJson() {
    return {
      'entity_id': entityId,
      'entity_type': entityType.name,
      'reaction': reaction.name,
    };
  }
}

class ReactionDeleteRequest {
  final String reactionId;

  ReactionDeleteRequest({
    required this.reactionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'reaction_id': reactionId,
    };
  }
}

class ReactionResponse {
  final String id;
  final String userId;
  final String entityId;
  final EntityType entityType;
  final ReactionType reaction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  ReactionResponse({
    required this.id,
    required this.userId,
    required this.entityId,
    required this.entityType,
    required this.reaction,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory ReactionResponse.fromJson(Map<String, dynamic> json) {
    return ReactionResponse(
      id: json['id'],
      userId: json['user_id'],
      entityId: json['entity_id'],
      entityType: EntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
      ),
      reaction: ReactionType.values.firstWhere(
        (e) => e.name == json['reaction'],
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
    );
  }
}

class UserReactionsResponse {
  final List<String> likedArtists;
  final List<String> followedArtists;

  UserReactionsResponse({
    required this.likedArtists,
    required this.followedArtists,
  });

  factory UserReactionsResponse.fromJson(Map<String, dynamic> json) {
    return UserReactionsResponse(
      likedArtists: List<String>.from(json['liked_artists'] ?? []),
      followedArtists: List<String>.from(json['followed_artists'] ?? []),
    );
  }
}

class ReactionStatsResponse {
  final String entityId;
  final EntityType entityType;
  final int likeCount;
  final int followCount;

  ReactionStatsResponse({
    required this.entityId,
    required this.entityType,
    required this.likeCount,
    required this.followCount,
  });

  factory ReactionStatsResponse.fromJson(Map<String, dynamic> json) {
    return ReactionStatsResponse(
      entityId: json['entity_id'],
      entityType: EntityType.values.firstWhere(
        (e) => e.name == json['entity_type'],
      ),
      likeCount: json['like_count'] ?? 0,
      followCount: json['follow_count'] ?? 0,
    );
  }
}

class DeviceTokenRequest {
  final String deviceToken;
  final String platform;

  DeviceTokenRequest({
    required this.deviceToken,
    required this.platform,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_token': deviceToken,
      'platform': platform,
    };
  }
} 