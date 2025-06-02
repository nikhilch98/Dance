import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reaction.dart';

class ReactionService {
  static const String baseUrl = 'https://nachna.com/api';
  
  String? _authToken;
  
  void setAuthToken(String token) {
    _authToken = token;
  }
  
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  /// Create or update a reaction (like/follow) for artists only
  Future<ReactionResponse> createReaction(ReactionRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reactions'),
        headers: _headers,
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
      final response = await http.delete(
        Uri.parse('$baseUrl/reactions'),
        headers: _headers,
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

  /// Get user's reactions
  Future<UserReactionsResponse> getUserReactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/reactions'),
        headers: _headers,
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
      final response = await http.get(
        Uri.parse('$baseUrl/reactions/stats/${entityType.name}/$entityId'),
        headers: _headers,
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
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/register-token'),
        headers: _headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to register device token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error registering device token: $e');
    }
  }
} 