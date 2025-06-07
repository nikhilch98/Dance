import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reaction.dart';
import './http_client_service.dart';
import './auth_service.dart';

class ReactionService {
  static const String baseUrl = 'https://nachna.com/api';
  
  String? _authToken;
  
  // Get the HTTP client instance
  http.Client get _httpClient => HttpClientService.instance.client;
  
  void setAuthToken(String token) {
    _authToken = token;
  }
  
  Map<String, String> get _headers => HttpClientService.getHeaders(authToken: _authToken);
  
  /// Get fresh auth token for requests
  Future<Map<String, String>> get _freshHeaders async {
    // Always get the latest token from secure storage
    final token = await AuthService.getToken();
    return HttpClientService.getHeaders(authToken: token);
  }

  /// Create or update a reaction (like/follow) for artists only
  Future<ReactionResponse> createReaction(ReactionRequest request) async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/reactions'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ReactionResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create reaction: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create reaction: $e');
    }
  }

  /// Soft delete a reaction by ID
  Future<bool> deleteReaction(ReactionDeleteRequest request) async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/reactions'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete reaction: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete reaction: $e');
    }
  }

  /// Soft delete a reaction by entity and reaction type
  Future<bool> deleteReactionByEntity(String entityId, EntityType entityType, ReactionType reactionType) async {
    try {
      final headers = await _freshHeaders;
      final uri = Uri.parse('$baseUrl/reactions/by-entity').replace(queryParameters: {
        'entity_id': entityId,
        'entity_type': entityType.name,
        'reaction_type': reactionType.name,
      });
      
      final response = await _httpClient.delete(uri, headers: headers);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete reaction by entity: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete reaction by entity: $e');
    }
  }

  /// Get user's reactions
  Future<UserReactionsResponse> getUserReactions() async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/user/reactions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return UserReactionsResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get user reactions: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get user reactions: $e');
    }
  }

  /// Get reaction statistics for an artist
  Future<ReactionStatsResponse> getReactionStats(String entityId, EntityType entityType) async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/reactions/stats/${entityType.name}/$entityId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return ReactionStatsResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get reaction stats: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get reaction stats: $e');
    }
  }

  /// Register device token for push notifications
  Future<void> registerDeviceToken(DeviceTokenRequest request) async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/notifications/register-token'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to register device token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error registering device token: $e');
    }
  }

  /// Get current device token from server
  Future<String?> getCurrentDeviceToken() async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/notifications/device-token'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['device_token'] as String?;
      } else if (response.statusCode == 404) {
        // No device token registered for this user
        return null;
      } else {
        throw Exception('Failed to get device token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting device token: $e');
    }
  }

  /// Unregister device token from push notifications
  Future<void> unregisterDeviceToken(String deviceToken) async {
    try {
      final headers = await _freshHeaders;
      final response = await _httpClient.delete(
        Uri.parse('$baseUrl/notifications/unregister-token'),
        headers: headers,
        body: json.encode({
          'device_token': deviceToken,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unregister device token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error unregistering device token: $e');
    }
  }
} 