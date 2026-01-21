import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/artist.dart';
import '../models/studio.dart';
import '../models/workshop.dart';
import '../models/reel.dart';
import './auth_service.dart';
import './http_client_service.dart';

class ApiService {
  // Set the base URL for the API - using production server
  final String baseUrl = 'https://nachna.com';
  
  // Add timeout duration for network requests
  static const Duration requestTimeout = Duration(seconds: 10);
  
  // Get the HTTP client instance
  http.Client get _httpClient => HttpClientService.instance.client;

  // Fetches all studios
  Future<List<Studio>> fetchStudios() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/studios?version=v2'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Studio.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load studios: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching studios: $e');
    }
  }

  // Fetches all artists
  Future<List<Artist>> fetchArtists({bool? hasWorkshops}) async {
    try {
      String url = '$baseUrl/api/artists?version=v2';
      if (hasWorkshops != null) {
        url += '&has_workshops=$hasWorkshops';
      }
      
      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Artist.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load artists: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching artists: $e');
    }
  }

  // Fetches all workshops
  Future<CategorizedWorkshopResponse> fetchAllWorkshops() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/workshops?version=v2'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      // Log compression info in debug mode
      HttpClientService.logCompressionInfo(response);

      if (response.statusCode == 200) {
        dynamic body = json.decode(response.body);
        return CategorizedWorkshopResponse.fromJson(body);
      } else {
        throw Exception('Failed to load workshops: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching workshops: $e');
    }
  }

  // Fetches workshops by artist ID
  Future<List<WorkshopSession>> fetchWorkshopsByArtist(String artistId) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/workshops_by_artist/$artistId?version=v2'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => WorkshopSession.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load artist workshops: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching artist workshops: $e');
    }
  }

  // Fetches workshops by studio ID
  Future<CategorizedWorkshopResponse> fetchWorkshopsByStudio(String studioId) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/workshops_by_studio/$studioId?version=v2'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        dynamic body = json.decode(response.body);
        return CategorizedWorkshopResponse.fromJson(body);
      } else {
        throw Exception('Failed to load studio workshops: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching studio workshops: $e');
    }
  }

  // Fetches app configuration
  static Future<Map<String, dynamic>> getConfig() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await HttpClientService.instance.client
          .get(
            Uri.parse('https://nachna.com/api/config'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load config: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching config: $e');
    }
  }

  // ========================================
  // Reels API Methods
  // ========================================

  /// Fetches available reels with video data from the API.
  /// 
  /// [limit] - Maximum number of reels to fetch (default: 50)
  /// [offset] - Number of reels to skip for pagination (default: 0)
  /// [videoOnly] - If true, only return reels with processed videos (default: true)
  /// [includePending] - If true, include videos being processed (default: false)
  Future<ReelsApiResponse> fetchReels({
    int limit = 50,
    int offset = 0,
    bool videoOnly = true,
    bool includePending = false,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'video_only': videoOnly.toString(),
        'include_pending': includePending.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/api/reels/videos').replace(queryParameters: queryParams);
      
      final response = await _httpClient
          .get(
            uri,
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return ReelsApiResponse.fromJson(body);
      } else {
        throw Exception('Failed to load reels: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching reels: $e');
    }
  }

  /// Fetches video processing status counts.
  Future<VideoStatusCounts> fetchReelsStatus() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/reels/status'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return VideoStatusCounts.fromJson(body);
      } else {
        throw Exception('Failed to load reels status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching reels status: $e');
    }
  }

  /// Gets the video stream URL for a specific reel.
  /// This URL can be passed directly to a video player.
  String getVideoStreamUrl(String choreoLinkId) {
    return '$baseUrl/api/reels/video/$choreoLinkId';
  }

  /// Fetches metadata for a specific video.
  Future<Reel?> fetchReelMetadata(String choreoLinkId) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/reels/video/$choreoLinkId/metadata'),
            headers: HttpClientService.getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return Reel.fromApiResponse(body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load reel metadata: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching reel metadata: $e');
    }
  }
}

/// Response model for the reels list API.
class ReelsApiResponse {
  final List<Reel> reels;
  final int total;
  final bool hasMore;

  ReelsApiResponse({
    required this.reels,
    required this.total,
    required this.hasMore,
  });

  factory ReelsApiResponse.fromJson(Map<String, dynamic> json) {
    final reelsList = (json['reels'] as List<dynamic>)
        .map((e) => Reel.fromApiResponse(e as Map<String, dynamic>))
        .where((r) => r != null)
        .cast<Reel>()
        .toList();

    return ReelsApiResponse(
      reels: reelsList,
      total: json['total'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

/// Video processing status counts.
class VideoStatusCounts {
  final int unprocessed;
  final int pending;
  final int processing;
  final int completed;
  final int failed;
  final int total;

  VideoStatusCounts({
    required this.unprocessed,
    required this.pending,
    required this.processing,
    required this.completed,
    required this.failed,
    required this.total,
  });

  factory VideoStatusCounts.fromJson(Map<String, dynamic> json) {
    return VideoStatusCounts(
      unprocessed: json['unprocessed'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      processing: json['processing'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  double get completionPercentage {
    if (total == 0) return 0;
    return (completed / total) * 100;
  }
} 