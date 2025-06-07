class AppInsights {
  final int totalUsers;
  final int totalLikes;
  final int totalFollows;
  final int totalWorkshops;
  final int totalNotificationsSent;
  final String lastUpdated;

  AppInsights({
    required this.totalUsers,
    required this.totalLikes,
    required this.totalFollows,
    required this.totalWorkshops,
    required this.totalNotificationsSent,
    required this.lastUpdated,
  });

  factory AppInsights.fromJson(Map<String, dynamic> json) {
    return AppInsights(
      totalUsers: json['total_users'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      totalFollows: json['total_follows'] ?? 0,
      totalWorkshops: json['total_workshops'] ?? 0,
      totalNotificationsSent: json['total_notifications_sent'] ?? 0,
      lastUpdated: json['last_updated'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_users': totalUsers,
      'total_likes': totalLikes,
      'total_follows': totalFollows,
      'total_workshops': totalWorkshops,
      'total_notifications_sent': totalNotificationsSent,
      'last_updated': lastUpdated,
    };
  }

  @override
  String toString() {
    return 'AppInsights(totalUsers: $totalUsers, totalLikes: $totalLikes, totalFollows: $totalFollows, totalWorkshops: $totalWorkshops, totalNotificationsSent: $totalNotificationsSent, lastUpdated: $lastUpdated)';
  }
} 