import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/search.dart';
import '../models/workshop.dart';
import './auth_service.dart';
import './http_client_service.dart';

class SearchService {
  // Set the base URL for the API - using production server
  final String baseUrl = 'https://nachna.com';
  
  // Add timeout duration for network requests
  static const Duration requestTimeout = Duration(seconds: 10);
  
  // Get the HTTP client instance
  http.Client get _httpClient => HttpClientService.instance.client;

  // Search users by name
  Future<List<SearchUserResult>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/search/users?q=${Uri.encodeComponent(query)}&limit=$limit&version=v2'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => SearchUserResult.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while searching users: $e');
    }
  }

  // Search artists by name or username
  Future<List<SearchArtistResult>> searchArtists(String query, {int limit = 20}) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/search/artists?q=${Uri.encodeComponent(query)}&limit=$limit&version=v2'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => SearchArtistResult.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search artists: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while searching artists: $e');
    }
  }

  // Search workshops by song name or artist name
  Future<List<WorkshopListItem>> searchWorkshops(String query, {int limit = 20}) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/api/search/workshops?q=${Uri.encodeComponent(query)}&version=v2'),
            headers: HttpClientService.getHeaders(authToken: token),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => WorkshopListItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search workshops: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while searching workshops: $e');
    }
  }
} 