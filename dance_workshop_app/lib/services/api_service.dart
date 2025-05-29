import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/artist.dart';
import '../models/studio.dart';
import '../models/workshop.dart';

class ApiService {
  // Set the base URL for the API - using production server
  final String baseUrl = 'https://nachna.com';
  
  // Add timeout duration for network requests
  static const Duration requestTimeout = Duration(seconds: 10);

  // Fetches all studios
  Future<List<Studio>> fetchStudios() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/studios?version=v2'))
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
  Future<List<Artist>> fetchArtists() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/artists?version=v2'))
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
  Future<List<WorkshopListItem>> fetchAllWorkshops() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/workshops?version=v2'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((dynamic item) => WorkshopListItem.fromJson(item)).toList();
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
      final response = await http
          .get(Uri.parse('$baseUrl/api/workshops_by_artist/$artistId?version=v2'))
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
      final response = await http
          .get(Uri.parse('$baseUrl/api/workshops_by_studio/$studioId?version=v2'))
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
} 