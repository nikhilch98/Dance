import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import './auth_service.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  final String baseUrl = 'https://nachna.com';

  /// Get current app version
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error getting current version: $e');
      return '1.0.0'; // fallback
    }
  }

  /// Get minimum required version from server
  Future<Map<String, dynamic>> getMinimumVersion() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/version/minimum'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch minimum version: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching minimum version: $e');
      // Return default values on error
      return {
        'minimum_version': '1.0.0',
        'force_update': false,
        'update_message': 'A new version is available. Please update to continue.',
        'ios_app_store_url': 'https://apps.apple.com/app/idYOUR_APP_ID'
      };
    }
  }

  /// Check if app needs force update
  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final versionData = await getMinimumVersion();

      final minimumVersion = versionData['minimum_version'] as String;
      final forceUpdate = versionData['force_update'] as bool;

      // Compare versions
      final needsUpdate = _compareVersions(currentVersion, minimumVersion);

      return {
        'needs_update': needsUpdate,
        'force_update': forceUpdate,
        'current_version': currentVersion,
        'minimum_version': minimumVersion,
        'update_message': versionData['update_message'],
        'ios_app_store_url': versionData['ios_app_store_url'],
      };
    } catch (e) {
      print('Error checking for update: $e');
      return {
        'needs_update': false,
        'force_update': false,
        'current_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_message': 'Unable to check for updates',
        'ios_app_store_url': 'https://apps.apple.com',
      };
    }
  }

  /// Compare version strings (simple comparison)
  bool _compareVersions(String current, String minimum) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minimumParts = minimum.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (currentParts.length < minimumParts.length) {
        currentParts.add(0);
      }
      while (minimumParts.length < currentParts.length) {
        minimumParts.add(0);
      }

      for (int i = 0; i < currentParts.length; i++) {
        if (currentParts[i] < minimumParts[i]) {
          return true; // needs update
        } else if (currentParts[i] > minimumParts[i]) {
          return false; // current is newer
        }
      }
      return false; // versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false; // default to no update needed
    }
  }
}
