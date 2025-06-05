/// ======================================================================
/// NACHNA APP - API INTEGRATION TEST SUITE
/// ======================================================================
/// 
/// This file contains integration tests for ALL APIs used in the Nachna Flutter app.
/// 
/// 🚨 CURSOR RULE: When adding new API calls to the Flutter app, you MUST:
/// 1. Add corresponding test cases to this file
/// 2. Follow the existing test structure and naming conventions
/// 3. Include both success and error scenarios
/// 4. Update the API endpoint documentation section
/// 
/// Test Coverage:
/// - Authentication APIs (register, login, profile, etc.)
/// - Data Fetching APIs (artists, studios, workshops)
/// - Notification APIs (device token management)
/// - Admin APIs (workshop management, test notifications)
/// - File Upload APIs (profile pictures)
/// 
/// ======================================================================

/// ======================================================================
/// NACHNA APP - API INTEGRATION TEST SUITE
/// ======================================================================
/// 
/// This file contains integration tests for ALL APIs used in the Nachna Flutter app.
/// 
/// 🚨 CURSOR RULE: When adding new API calls to the Flutter app, you MUST:
/// 1. Add corresponding test cases to this file
/// 2. Follow the existing test structure and naming conventions
/// 3. Include both success and error scenarios
/// 4. Update the API endpoint documentation section
/// 
/// Test Coverage:
/// - Authentication APIs (register, login, profile, etc.)
/// - Data Fetching APIs (artists, studios, workshops)
/// - Notification APIs (device token management)
/// - Admin APIs (workshop management, test notifications)
/// - File Upload APIs (profile pictures)
/// 
/// ======================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// ======================================================================
/// API ENDPOINTS DOCUMENTATION
/// ======================================================================
/// 
/// Auth Endpoints:
/// - POST /api/auth/register
/// - POST /api/auth/login
/// - GET /api/auth/profile
/// - POST /api/auth/config
/// - PUT /api/auth/profile
/// - PUT /api/auth/password
/// - POST /api/auth/profile-picture
/// - DELETE /api/auth/profile-picture
/// - DELETE /api/auth/account
/// 
/// Data Endpoints:
/// - GET /api/artists?version=v2[&has_workshops=true]
/// - GET /api/studios?version=v2
/// - GET /api/workshops?version=v2
/// - GET /api/workshops_by_artist/{artistId}?version=v2
/// - GET /api/workshops_by_studio/{studioId}?version=v2
/// - GET /api/config
/// 
/// Reaction Endpoints:
/// - POST /api/reactions
/// - DELETE /api/reactions
/// - GET /api/user/reactions
/// - GET /api/reactions/stats/{entityType}/{entityId}
/// 
/// Notification Endpoints:
/// - POST /api/notifications/register-token
/// - GET /api/notifications/device-token
/// - DELETE /api/notifications/unregister-token
/// 
/// Admin Endpoints:
/// - GET /admin/api/missing_artist_sessions
/// - GET /admin/api/missing_song_sessions
/// - PUT /admin/api/workshops/{uuid}/assign_artist
/// - PUT /admin/api/workshops/{uuid}/assign_song
/// - POST /admin/api/send-test-notification
/// - POST /admin/api/test-apns
/// 
/// ======================================================================

class ApiTestConfig {
  static const String baseUrl = 'https://nachna.com';
  static const String testMobileNumber = '9999999999';
  static const String testPassword = 'test123';
  static const String testUserId = '683cdbb39caf05c68764cde4';
  static const Duration timeout = Duration(seconds: 30);
  
  // Test data IDs (update these with real IDs from your database)
  static const String testArtistId = 'test_artist_id';
  static const String testStudioId = 'test_studio_id';
  static const String testWorkshopUuid = 'test_workshop_uuid';
  static const String testDeviceToken = 'test_device_token_for_integration_testing';
}

void main() {
  group('Nachna API Integration Tests', () {
    late String? authToken;
    late String? adminAuthToken;
    
    setUpAll(() async {
      print('🚀 Starting API Integration Tests for Nachna App');
      print('📍 Base URL: ${ApiTestConfig.baseUrl}');
    });

    tearDownAll(() async {
      print('✅ API Integration Tests completed');
    });

    /// ================================================================
    /// AUTHENTICATION API TESTS
    /// ================================================================

    group('Authentication APIs', () {
      test('POST /api/auth/register - Register new user', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': '9876543210', // Different number for registration test
              'password': 'testpass123',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (201) or fail with user exists (400)
          expect([200, 201, 400], contains(response.statusCode));
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('access_token', isA<String>()));
            expect(data, containsPair('user', isA<Map>()));
            print('✅ Registration test passed');
          } else {
            print('ℹ️ Registration failed (expected if user exists): ${response.body}');
          }
        } catch (e) {
          print('❌ Registration test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /api/auth/login - Login with test credentials', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': ApiTestConfig.testMobileNumber,
              'password': ApiTestConfig.testPassword,
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('access_token', isA<String>()));
          expect(data, containsPair('user', isA<Map>()));
          
          authToken = data['access_token'];
          print('✅ Login test passed - Token obtained');
        } catch (e) {
          print('❌ Login test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/auth/profile - Get current user profile', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for profile test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('user_id', isA<String>()));
          expect(data, containsPair('mobile_number', ApiTestConfig.testMobileNumber));
          
          print('✅ Profile fetch test passed');
        } catch (e) {
          print('❌ Profile fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /api/auth/config - Get app config with device token sync', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for config test');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/config'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'device_token': ApiTestConfig.testDeviceToken,
              'platform': 'ios',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('is_admin', isA<bool>()));
          
          print('✅ Config API test passed');
        } catch (e) {
          print('❌ Config API test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('PUT /api/auth/profile - Update user profile', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for profile update test');
        
        final client = http.Client();
        
        try {
          final response = await client.put(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'name': 'Integration Test User',
              'gender': 'Other',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('name', 'Integration Test User'));
          
          print('✅ Profile update test passed');
        } catch (e) {
          print('❌ Profile update test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// DATA FETCHING API TESTS
    /// ================================================================

    group('Data Fetching APIs', () {
      test('GET /api/artists?version=v2 - Fetch all artists', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/artists?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final artist = data.first;
            expect(artist, containsPair('artist_id', isA<String>()));
            expect(artist, containsPair('artist_name', isA<String>()));
          }
          
          print('✅ Artists fetch test passed - Found ${data.length} artists');
        } catch (e) {
          print('❌ Artists fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/artists?version=v2&has_workshops=true - Fetch artists with workshops', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/artists?version=v2&has_workshops=true'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          print('✅ Artists with workshops fetch test passed - Found ${data.length} artists');
        } catch (e) {
          print('❌ Artists with workshops fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/studios?version=v2 - Fetch all studios', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/studios?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final studio = data.first;
            expect(studio, containsPair('studio_id', isA<String>()));
            expect(studio, containsPair('studio_name', isA<String>()));
          }
          
          print('✅ Studios fetch test passed - Found ${data.length} studios');
        } catch (e) {
          print('❌ Studios fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/workshops?version=v2 - Fetch all workshops', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/workshops?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final workshop = data.first;
            expect(workshop, containsPair('uuid', isA<String>()));
            expect(workshop, containsPair('studio_name', isA<String>()));
          }
          
          print('✅ Workshops fetch test passed - Found ${data.length} workshops');
        } catch (e) {
          print('❌ Workshops fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/config - Fetch app configuration', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for config test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/config'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, isA<Map>());
          
          print('✅ Config fetch test passed');
        } catch (e) {
          print('❌ Config fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// REACTION API TESTS
    /// ================================================================

    group('Reaction APIs', () {
      test('POST /api/reactions - Create artist reaction', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for reaction test');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/reactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'entity_id': ApiTestConfig.testArtistId,
              'entity_type': 'ARTIST',
              'reaction': 'LIKE',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (200/201) or fail if reaction already exists
          expect([200, 201, 400], contains(response.statusCode));
          
          print('✅ Reaction creation test passed');
        } catch (e) {
          print('❌ Reaction creation test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/user/reactions - Get user reactions', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for user reactions test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/user/reactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('reactions', isA<List>()));
          
          print('✅ User reactions fetch test passed');
        } catch (e) {
          print('❌ User reactions fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// NOTIFICATION API TESTS
    /// ================================================================

    group('Notification APIs', () {
      test('POST /api/notifications/register-token - Register device token', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for device token registration');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/notifications/register-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'device_token': ApiTestConfig.testDeviceToken,
              'platform': 'ios',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('message', isA<String>()));
          
          print('✅ Device token registration test passed');
        } catch (e) {
          print('❌ Device token registration test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/notifications/device-token - Get current device token', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for device token fetch');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/notifications/device-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (200) or not found (404)
          expect([200, 404], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('device_token', isA<String>()));
          }
          
          print('✅ Device token fetch test passed');
        } catch (e) {
          print('❌ Device token fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// ADMIN API TESTS
    /// ================================================================

    group('Admin APIs', () {
      setUpAll(() async {
        // For admin tests, we'll use the same token but check if user is admin
        adminAuthToken = authToken;
      });

      test('GET /admin/api/missing_artist_sessions - Get workshops missing artists', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/missing_artist_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as List;
            expect(data, isA<List>());
            print('✅ Missing artist sessions test passed - Found ${data.length} sessions');
          } else {
            print('ℹ️ Missing artist sessions test - Access denied (non-admin user)');
          }
        } catch (e) {
          print('❌ Missing artist sessions test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /admin/api/missing_song_sessions - Get workshops missing songs', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/missing_song_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as List;
            expect(data, isA<List>());
            print('✅ Missing song sessions test passed - Found ${data.length} sessions');
          } else {
            print('ℹ️ Missing song sessions test - Access denied (non-admin user)');
          }
        } catch (e) {
          print('❌ Missing song sessions test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /admin/api/send-test-notification - Send test notification', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/send-test-notification'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
            body: jsonEncode({
              'title': 'Integration Test Notification',
              'body': 'This is a test notification from API integration tests',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403, 500], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('success', true));
            print('✅ Test notification API test passed');
          } else {
            print('ℹ️ Test notification API - Access denied or error: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Test notification API test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// ERROR HANDLING TESTS
    /// ================================================================

    group('Error Handling Tests', () {
      test('Authentication - Invalid credentials', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': '0000000000',
              'password': 'wrongpassword',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(401));
          print('✅ Invalid credentials error handling test passed');
        } catch (e) {
          print('❌ Invalid credentials error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('Unauthorized access - No token', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(401));
          print('✅ Unauthorized access error handling test passed');
        } catch (e) {
          print('❌ Unauthorized access error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('Invalid endpoint - 404 error', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/nonexistent-endpoint'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(404));
          print('✅ 404 error handling test passed');
        } catch (e) {
          print('❌ 404 error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// PERFORMANCE TESTS
    /// ================================================================

    group('Performance Tests', () {
      test('API Response Times - All endpoints under 5 seconds', () async {
        final endpoints = [
          'GET /api/artists?version=v2',
          'GET /api/studios?version=v2',
          'GET /api/workshops?version=v2',
        ];

        for (final endpoint in endpoints) {
          final client = http.Client();
          
          try {
            final stopwatch = Stopwatch()..start();
            
            final response = await client.get(
              Uri.parse('${ApiTestConfig.baseUrl}${endpoint.split(' ')[1]}'),
              headers: {'Content-Type': 'application/json'},
            ).timeout(ApiTestConfig.timeout);
            
            stopwatch.stop();
            final responseTime = stopwatch.elapsedMilliseconds;
            
            expect(response.statusCode, equals(200));
            expect(responseTime, lessThan(5000), reason: '$endpoint took ${responseTime}ms');
            
            print('✅ $endpoint: ${responseTime}ms');
          } catch (e) {
            print('❌ Performance test failed for $endpoint: $e');
            rethrow;
          } finally {
            client.close();
          }
        }
      });
    });
  });
}

/// ======================================================================
/// HELPER FUNCTIONS FOR TESTS
/// ======================================================================

/// Helper function to create test user data
Map<String, dynamic> createTestUserData() {
  return {
    'mobile_number': '9999999998', // Different from main test user
    'password': 'testpass123',
    'name': 'Test User ${DateTime.now().millisecondsSinceEpoch}',
  };
}

/// Helper function to create test device token request
Map<String, dynamic> createTestDeviceTokenRequest() {
  return {
    'device_token': 'test_device_token_${DateTime.now().millisecondsSinceEpoch}',
    'platform': 'ios',
  };
}

/// Helper function to create test reaction request
Map<String, dynamic> createTestReactionRequest(String artistId) {
  return {
    'entity_id': artistId,
    'entity_type': 'ARTIST',
    'reaction': 'LIKE',
  };
}

/// Helper function to validate API response structure
void validateApiResponse(Map<String, dynamic> response, List<String> requiredFields) {
  for (final field in requiredFields) {
    expect(response, containsPair(field, isNotNull), 
           reason: 'Response missing required field: $field');
  }
}

/// Helper function to check if response contains error information
bool isErrorResponse(Map<String, dynamic> response) {
  return response.containsKey('detail') || response.containsKey('error');
}

/// ======================================================================
/// CURSOR RULE IMPLEMENTATION
/// ======================================================================
/// 
/// 🚨 IMPORTANT: When adding new API endpoints to the Flutter app:
/// 
/// 1. **Search for existing API calls** in the codebase to ensure no duplicates
/// 2. **Add test case to this file** following the existing pattern:
///    - Add to appropriate group (Auth, Data, Reactions, Notifications, Admin)
///    - Include both success and error scenarios
///    - Use proper test naming: 'HTTP_METHOD /endpoint/path - Description'
///    - Add timeout handling and proper assertions
/// 
/// 3. **Update API documentation** in the header comment section
/// 4. **Add any new test data constants** to ApiTestConfig class
/// 5. **Create helper functions** if the new API requires complex setup
/// 
/// Example template for new API test:
/// ```dart
/// test('POST /api/new/endpoint - Description of what it does', () async {
///   expect(authToken, isNotNull, reason: 'Auth token required if needed');
///   
///   final client = http.Client();
///   
///   try {
///     final response = await client.post(
///       Uri.parse('${ApiTestConfig.baseUrl}/api/new/endpoint'),
///       headers: {
///         'Content-Type': 'application/json',
///         'Authorization': 'Bearer $authToken', // if auth required
///       },
///       body: jsonEncode({
///         'param1': 'value1',
///         'param2': 'value2',
///       }),
///     ).timeout(ApiTestConfig.timeout);
/// 
///     expect(response.statusCode, equals(200));
///     
///     final data = jsonDecode(response.body);
///     expect(data, containsPair('expected_field', isA<String>()));
///     
///     print('✅ New endpoint test passed');
///   } catch (e) {
///     print('❌ New endpoint test failed: $e');
///     rethrow;
///   } finally {
///     client.close();
///   }
/// });
/// ```
/// 
/// ======================================================================
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// ======================================================================
/// API ENDPOINTS DOCUMENTATION
/// ======================================================================
/// 
/// Auth Endpoints:
/// - POST /api/auth/register
/// - POST /api/auth/login
/// - GET /api/auth/profile
/// - POST /api/auth/config
/// - PUT /api/auth/profile
/// - PUT /api/auth/password
/// - POST /api/auth/profile-picture
/// - DELETE /api/auth/profile-picture
/// - DELETE /api/auth/account
/// 
/// Data Endpoints:
/// - GET /api/artists?version=v2[&has_workshops=true]
/// - GET /api/studios?version=v2
/// - GET /api/workshops?version=v2
/// - GET /api/workshops_by_artist/{artistId}?version=v2
/// - GET /api/workshops_by_studio/{studioId}?version=v2
/// - GET /api/config
/// 
/// Reaction Endpoints:
/// - POST /api/reactions
/// - DELETE /api/reactions
/// - GET /api/user/reactions
/// - GET /api/reactions/stats/{entityType}/{entityId}
/// 
/// Notification Endpoints:
/// - POST /api/notifications/register-token
/// - GET /api/notifications/device-token
/// - DELETE /api/notifications/unregister-token
/// 
/// Admin Endpoints:
/// - GET /admin/api/missing_artist_sessions
/// - GET /admin/api/missing_song_sessions
/// - PUT /admin/api/workshops/{uuid}/assign_artist
/// - PUT /admin/api/workshops/{uuid}/assign_song
/// - POST /admin/api/send-test-notification
/// - POST /admin/api/test-apns
/// 
/// ======================================================================

class ApiTestConfig {
  static const String baseUrl = 'https://nachna.com';
  static const String testMobileNumber = '9999999999';
  static const String testPassword = 'test123';
  static const String testUserId = '683cdbb39caf05c68764cde4';
  static const Duration timeout = Duration(seconds: 30);
  
  // Test data IDs (update these with real IDs from your database)
  static const String testArtistId = 'test_artist_id';
  static const String testStudioId = 'test_studio_id';
  static const String testWorkshopUuid = 'test_workshop_uuid';
  static const String testDeviceToken = 'test_device_token_for_integration_testing';
}

void main() {
  group('Nachna API Integration Tests', () {
    late String? authToken;
    late String? adminAuthToken;
    
    setUpAll(() async {
      print('🚀 Starting API Integration Tests for Nachna App');
      print('📍 Base URL: ${ApiTestConfig.baseUrl}');
    });

    tearDownAll(() async {
      print('✅ API Integration Tests completed');
    });

    /// ================================================================
    /// AUTHENTICATION API TESTS
    /// ================================================================

    group('Authentication APIs', () {
      test('POST /api/auth/register - Register new user', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': '9876543210', // Different number for registration test
              'password': 'testpass123',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (201) or fail with user exists (400)
          expect([200, 201, 400], contains(response.statusCode));
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('access_token', isA<String>()));
            expect(data, containsPair('user', isA<Map>()));
            print('✅ Registration test passed');
          } else {
            print('ℹ️ Registration failed (expected if user exists): ${response.body}');
          }
        } catch (e) {
          print('❌ Registration test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /api/auth/login - Login with test credentials', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': ApiTestConfig.testMobileNumber,
              'password': ApiTestConfig.testPassword,
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('access_token', isA<String>()));
          expect(data, containsPair('user', isA<Map>()));
          
          authToken = data['access_token'];
          print('✅ Login test passed - Token obtained');
        } catch (e) {
          print('❌ Login test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/auth/profile - Get current user profile', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for profile test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('user_id', isA<String>()));
          expect(data, containsPair('mobile_number', ApiTestConfig.testMobileNumber));
          
          print('✅ Profile fetch test passed');
        } catch (e) {
          print('❌ Profile fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /api/auth/config - Get app config with device token sync', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for config test');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/config'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'device_token': ApiTestConfig.testDeviceToken,
              'platform': 'ios',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('is_admin', isA<bool>()));
          
          print('✅ Config API test passed');
        } catch (e) {
          print('❌ Config API test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('PUT /api/auth/profile - Update user profile', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for profile update test');
        
        final client = http.Client();
        
        try {
          final response = await client.put(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'name': 'Integration Test User',
              'gender': 'Other',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('name', 'Integration Test User'));
          
          print('✅ Profile update test passed');
        } catch (e) {
          print('❌ Profile update test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// DATA FETCHING API TESTS
    /// ================================================================

    group('Data Fetching APIs', () {
      test('GET /api/artists?version=v2 - Fetch all artists', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/artists?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final artist = data.first;
            expect(artist, containsPair('artist_id', isA<String>()));
            expect(artist, containsPair('artist_name', isA<String>()));
          }
          
          print('✅ Artists fetch test passed - Found ${data.length} artists');
        } catch (e) {
          print('❌ Artists fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/artists?version=v2&has_workshops=true - Fetch artists with workshops', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/artists?version=v2&has_workshops=true'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          print('✅ Artists with workshops fetch test passed - Found ${data.length} artists');
        } catch (e) {
          print('❌ Artists with workshops fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/studios?version=v2 - Fetch all studios', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/studios?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final studio = data.first;
            expect(studio, containsPair('studio_id', isA<String>()));
            expect(studio, containsPair('studio_name', isA<String>()));
          }
          
          print('✅ Studios fetch test passed - Found ${data.length} studios');
        } catch (e) {
          print('❌ Studios fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/workshops?version=v2 - Fetch all workshops', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/workshops?version=v2'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body) as List;
          expect(data, isA<List>());
          
          if (data.isNotEmpty) {
            final workshop = data.first;
            expect(workshop, containsPair('uuid', isA<String>()));
            expect(workshop, containsPair('studio_name', isA<String>()));
          }
          
          print('✅ Workshops fetch test passed - Found ${data.length} workshops');
        } catch (e) {
          print('❌ Workshops fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/config - Fetch app configuration', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for config test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/config'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, isA<Map>());
          
          print('✅ Config fetch test passed');
        } catch (e) {
          print('❌ Config fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// REACTION API TESTS
    /// ================================================================

    group('Reaction APIs', () {
      test('POST /api/reactions - Create artist reaction', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for reaction test');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/reactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'entity_id': ApiTestConfig.testArtistId,
              'entity_type': 'ARTIST',
              'reaction': 'LIKE',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (200/201) or fail if reaction already exists
          expect([200, 201, 400], contains(response.statusCode));
          
          print('✅ Reaction creation test passed');
        } catch (e) {
          print('❌ Reaction creation test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/user/reactions - Get user reactions', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for user reactions test');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/user/reactions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('reactions', isA<List>()));
          
          print('✅ User reactions fetch test passed');
        } catch (e) {
          print('❌ User reactions fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// NOTIFICATION API TESTS
    /// ================================================================

    group('Notification APIs', () {
      test('POST /api/notifications/register-token - Register device token', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for device token registration');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/notifications/register-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'device_token': ApiTestConfig.testDeviceToken,
              'platform': 'ios',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(200));
          
          final data = jsonDecode(response.body);
          expect(data, containsPair('message', isA<String>()));
          
          print('✅ Device token registration test passed');
        } catch (e) {
          print('❌ Device token registration test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /api/notifications/device-token - Get current device token', () async {
        expect(authToken, isNotNull, reason: 'Auth token required for device token fetch');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/notifications/device-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed (200) or not found (404)
          expect([200, 404], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('device_token', isA<String>()));
          }
          
          print('✅ Device token fetch test passed');
        } catch (e) {
          print('❌ Device token fetch test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// ADMIN API TESTS
    /// ================================================================

    group('Admin APIs', () {
      setUpAll(() async {
        // For admin tests, we'll use the same token but check if user is admin
        adminAuthToken = authToken;
      });

      test('GET /admin/api/missing_artist_sessions - Get workshops missing artists', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/missing_artist_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as List;
            expect(data, isA<List>());
            print('✅ Missing artist sessions test passed - Found ${data.length} sessions');
          } else {
            print('ℹ️ Missing artist sessions test - Access denied (non-admin user)');
          }
        } catch (e) {
          print('❌ Missing artist sessions test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('GET /admin/api/missing_song_sessions - Get workshops missing songs', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/missing_song_sessions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as List;
            expect(data, isA<List>());
            print('✅ Missing song sessions test passed - Found ${data.length} sessions');
          } else {
            print('ℹ️ Missing song sessions test - Access denied (non-admin user)');
          }
        } catch (e) {
          print('❌ Missing song sessions test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('POST /admin/api/send-test-notification - Send test notification', () async {
        expect(adminAuthToken, isNotNull, reason: 'Admin auth token required');
        
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/admin/api/send-test-notification'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $adminAuthToken',
            },
            body: jsonEncode({
              'title': 'Integration Test Notification',
              'body': 'This is a test notification from API integration tests',
            }),
          ).timeout(ApiTestConfig.timeout);

          // Should succeed for admin (200) or fail for non-admin (403)
          expect([200, 403, 500], contains(response.statusCode));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data, containsPair('success', true));
            print('✅ Test notification API test passed');
          } else {
            print('ℹ️ Test notification API - Access denied or error: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Test notification API test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// ERROR HANDLING TESTS
    /// ================================================================

    group('Error Handling Tests', () {
      test('Authentication - Invalid credentials', () async {
        final client = http.Client();
        
        try {
          final response = await client.post(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mobile_number': '0000000000',
              'password': 'wrongpassword',
            }),
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(401));
          print('✅ Invalid credentials error handling test passed');
        } catch (e) {
          print('❌ Invalid credentials error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('Unauthorized access - No token', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/auth/profile'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(401));
          print('✅ Unauthorized access error handling test passed');
        } catch (e) {
          print('❌ Unauthorized access error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });

      test('Invalid endpoint - 404 error', () async {
        final client = http.Client();
        
        try {
          final response = await client.get(
            Uri.parse('${ApiTestConfig.baseUrl}/api/nonexistent-endpoint'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(ApiTestConfig.timeout);

          expect(response.statusCode, equals(404));
          print('✅ 404 error handling test passed');
        } catch (e) {
          print('❌ 404 error handling test failed: $e');
          rethrow;
        } finally {
          client.close();
        }
      });
    });

    /// ================================================================
    /// PERFORMANCE TESTS
    /// ================================================================

    group('Performance Tests', () {
      test('API Response Times - All endpoints under 5 seconds', () async {
        final endpoints = [
          'GET /api/artists?version=v2',
          'GET /api/studios?version=v2',
          'GET /api/workshops?version=v2',
        ];

        for (final endpoint in endpoints) {
          final client = http.Client();
          
          try {
            final stopwatch = Stopwatch()..start();
            
            final response = await client.get(
              Uri.parse('${ApiTestConfig.baseUrl}${endpoint.split(' ')[1]}'),
              headers: {'Content-Type': 'application/json'},
            ).timeout(ApiTestConfig.timeout);
            
            stopwatch.stop();
            final responseTime = stopwatch.elapsedMilliseconds;
            
            expect(response.statusCode, equals(200));
            expect(responseTime, lessThan(5000), reason: '$endpoint took ${responseTime}ms');
            
            print('✅ $endpoint: ${responseTime}ms');
          } catch (e) {
            print('❌ Performance test failed for $endpoint: $e');
            rethrow;
          } finally {
            client.close();
          }
        }
      });
    });
  });
}

/// ======================================================================
/// HELPER FUNCTIONS FOR TESTS
/// ======================================================================

/// Helper function to create test user data
Map<String, dynamic> createTestUserData() {
  return {
    'mobile_number': '9999999998', // Different from main test user
    'password': 'testpass123',
    'name': 'Test User ${DateTime.now().millisecondsSinceEpoch}',
  };
}

/// Helper function to create test device token request
Map<String, dynamic> createTestDeviceTokenRequest() {
  return {
    'device_token': 'test_device_token_${DateTime.now().millisecondsSinceEpoch}',
    'platform': 'ios',
  };
}

/// Helper function to create test reaction request
Map<String, dynamic> createTestReactionRequest(String artistId) {
  return {
    'entity_id': artistId,
    'entity_type': 'ARTIST',
    'reaction': 'LIKE',
  };
}

/// Helper function to validate API response structure
void validateApiResponse(Map<String, dynamic> response, List<String> requiredFields) {
  for (final field in requiredFields) {
    expect(response, containsPair(field, isNotNull), 
           reason: 'Response missing required field: $field');
  }
}

/// Helper function to check if response contains error information
bool isErrorResponse(Map<String, dynamic> response) {
  return response.containsKey('detail') || response.containsKey('error');
}

/// ======================================================================
/// CURSOR RULE IMPLEMENTATION
/// ======================================================================
/// 
/// 🚨 IMPORTANT: When adding new API endpoints to the Flutter app:
/// 
/// 1. **Search for existing API calls** in the codebase to ensure no duplicates
/// 2. **Add test case to this file** following the existing pattern:
///    - Add to appropriate group (Auth, Data, Reactions, Notifications, Admin)
///    - Include both success and error scenarios
///    - Use proper test naming: 'HTTP_METHOD /endpoint/path - Description'
///    - Add timeout handling and proper assertions
/// 
/// 3. **Update API documentation** in the header comment section
/// 4. **Add any new test data constants** to ApiTestConfig class
/// 5. **Create helper functions** if the new API requires complex setup
/// 
/// Example template for new API test:
/// ```dart
/// test('POST /api/new/endpoint - Description of what it does', () async {
///   expect(authToken, isNotNull, reason: 'Auth token required if needed');
///   
///   final client = http.Client();
///   
///   try {
///     final response = await client.post(
///       Uri.parse('${ApiTestConfig.baseUrl}/api/new/endpoint'),
///       headers: {
///         'Content-Type': 'application/json',
///         'Authorization': 'Bearer $authToken', // if auth required
///       },
///       body: jsonEncode({
///         'param1': 'value1',
///         'param2': 'value2',
///       }),
///     ).timeout(ApiTestConfig.timeout);
/// 
///     expect(response.statusCode, equals(200));
///     
///     final data = jsonDecode(response.body);
///     expect(data, containsPair('expected_field', isA<String>()));
///     
///     print('✅ New endpoint test passed');
///   } catch (e) {
///     print('❌ New endpoint test failed: $e');
///     rethrow;
///   } finally {
///     client.close();
///   }
/// });
/// ```
/// 
/// ====================================================================== 