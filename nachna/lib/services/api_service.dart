import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/artist.dart';
import '../models/studio.dart';
import '../models/workshop.dart';
import '../models/reel.dart';
import '../utils/error_handler.dart';
import './auth_service.dart';
import './http_client_service.dart';

/// Service class for making API calls to the Nachna backend.
///
/// Provides methods for fetching studios, artists, workshops, and reels.
/// Includes automatic retry logic with exponential backoff for transient failures.
class ApiService {
  /// Base URL for the Nachna API (production server).
  final String baseUrl = 'https://nachna.com';

  /// Timeout duration for network requests.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Maximum number of retry attempts for failed requests.
  static const int maxRetries = 3;

  /// Initial delay before first retry (doubles with each attempt).
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  /// HTTP client instance for making requests.
  http.Client get _httpClient => HttpClientService.instance.client;

  /// Execute an HTTP request with exponential backoff retry logic.
  ///
  /// Retries on timeout, network errors, and 5xx server errors.
  /// Uses exponential backoff: 500ms, 1000ms, 2000ms
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request, {
    int retries = maxRetries,
  }) async {
    int attempt = 0;
    dynamic lastError;

    while (attempt < retries) {
      try {
        final response = await request();

        // Retry on server errors (5xx)
        if (response.statusCode >= 500 && response.statusCode < 600) {
          if (attempt < retries - 1) {
            final delay = initialRetryDelay * (1 << attempt); // Exponential backoff
            ErrorHandler.logError(
              'Server error ${response.statusCode}, retrying in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/$retries)',
              context: 'ApiService._executeWithRetry',
            );
            await Future.delayed(delay);
            attempt++;
            continue;
          }
        }

        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt < retries - 1) {
          final delay = initialRetryDelay * (1 << attempt);
          ErrorHandler.logError(
            'Request timeout, retrying in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/$retries)',
            context: 'ApiService._executeWithRetry',
          );
          await Future.delayed(delay);
          attempt++;
          continue;
        }
      } on SocketException catch (e) {
        lastError = e;
        if (attempt < retries - 1) {
          final delay = initialRetryDelay * (1 << attempt);
          ErrorHandler.logError(
            'Network error, retrying in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/$retries)',
            context: 'ApiService._executeWithRetry',
          );
          await Future.delayed(delay);
          attempt++;
          continue;
        }
      } catch (e) {
        // Check if it's a retryable network error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('connection') ||
            errorString.contains('network') ||
            errorString.contains('socket')) {
          lastError = e;
          if (attempt < retries - 1) {
            final delay = initialRetryDelay * (1 << attempt);
            ErrorHandler.logError(
              'Connection error, retrying in ${delay.inMilliseconds}ms (attempt ${attempt + 1}/$retries)',
              context: 'ApiService._executeWithRetry',
            );
            await Future.delayed(delay);
            attempt++;
            continue;
          }
        }
        // Non-retryable error, rethrow immediately
        rethrow;
      }

      attempt++;
    }

    // All retries exhausted
    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Request failed after $retries attempts');
  }

  /// Fetches all dance studios from the API.
  ///
  /// Returns a list of [Studio] objects sorted by the server.
  /// Throws an exception on network errors or non-200 responses.
  Future<List<Studio>> fetchStudios() async {
    try {
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/studios?version=v2'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Studio.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load studios: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchStudios');
      throw Exception('Network error while fetching studios: $e');
    }
  }

  /// Fetches all artists from the API.
  ///
  /// [hasWorkshops] - If provided, filters artists by whether they have workshops.
  /// Returns a list of [Artist] objects.
  Future<List<Artist>> fetchArtists({bool? hasWorkshops}) async {
    try {
      String url = '$baseUrl/api/artists?version=v2';
      if (hasWorkshops != null) {
        url += '&has_workshops=$hasWorkshops';
      }

      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse(url),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => Artist.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load artists: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchArtists');
      throw Exception('Network error while fetching artists: $e');
    }
  }

  /// Fetches all workshops categorized by time period.
  ///
  /// Returns a [CategorizedWorkshopResponse] containing workshops
  /// organized into "this week" and "upcoming" categories.
  Future<CategorizedWorkshopResponse> fetchAllWorkshops() async {
    try {
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/workshops?version=v2'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      // Log compression info in debug mode
      HttpClientService.logCompressionInfo(response);

      if (response.statusCode == 200) {
        dynamic body = json.decode(response.body);
        return CategorizedWorkshopResponse.fromJson(body);
      } else {
        throw Exception('Failed to load workshops: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchAllWorkshops');
      throw Exception('Network error while fetching workshops: $e');
    }
  }

  /// Fetches workshops taught by a specific artist.
  ///
  /// [artistId] - The unique identifier of the artist.
  /// Returns a list of [WorkshopSession] objects for the artist.
  Future<List<WorkshopSession>> fetchWorkshopsByArtist(String artistId) async {
    try {
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/workshops_by_artist/$artistId?version=v2'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => WorkshopSession.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load artist workshops: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchWorkshopsByArtist');
      throw Exception('Network error while fetching artist workshops: $e');
    }
  }

  /// Fetches workshops at a specific studio, categorized by time period.
  ///
  /// [studioId] - The unique identifier of the studio.
  /// Returns a [CategorizedWorkshopResponse] with the studio's workshops.
  Future<CategorizedWorkshopResponse> fetchWorkshopsByStudio(String studioId) async {
    try {
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/workshops_by_studio/$studioId?version=v2'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        dynamic body = json.decode(response.body);
        return CategorizedWorkshopResponse.fromJson(body);
      } else {
        throw Exception('Failed to load studio workshops: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchWorkshopsByStudio');
      throw Exception('Network error while fetching studio workshops: $e');
    }
  }

  /// Fetches app configuration from the server.
  ///
  /// Requires authentication. Returns a map containing app settings
  /// like admin status, device token sync status, and feature flags.
  static Future<Map<String, dynamic>> getConfig() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Use instance method for retry logic
      final apiService = ApiService();
      final response = await apiService._executeWithRetry(
        () => HttpClientService.instance.client
            .get(
              Uri.parse('https://nachna.com/api/config'),
              headers: HttpClientService.getHeaders(authToken: token),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load config: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.getConfig');
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
  /// Fetches reels from the API.
  /// 
  /// The API returns reels using the same filtering as "All Workshops":
  /// - Only non-archived workshops
  /// - Only workshops from current week onwards
  /// - Only workshops with choreo_insta_link
  /// 
  /// By default, only returns reels with completed video processing.
  Future<ReelsApiResponse> fetchReels({
    int limit = 50,
    int offset = 0,
    bool videoOnly = true,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'video_only': videoOnly.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/reels/videos').replace(queryParameters: queryParams);

      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              uri,
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return ReelsApiResponse.fromJson(body);
      } else {
        throw Exception('Failed to load reels: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchReels');
      throw Exception('Network error while fetching reels: $e');
    }
  }

  /// Fetches video processing status counts.
  Future<VideoStatusCounts> fetchReelsStatus() async {
    try {
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/reels/status'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return VideoStatusCounts.fromJson(body);
      } else {
        throw Exception('Failed to load reels status: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchReelsStatus');
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
      final response = await _executeWithRetry(
        () => _httpClient
            .get(
              Uri.parse('$baseUrl/api/reels/video/$choreoLinkId/metadata'),
              headers: HttpClientService.getHeaders(),
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return Reel.fromApiResponse(body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load reel metadata: ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ApiService.fetchReelMetadata');
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