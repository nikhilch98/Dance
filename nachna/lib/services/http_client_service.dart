import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

class HttpClientService {
  static HttpClientService? _instance;
  late final http.Client _client;
  
  HttpClientService._() {
    // Create a custom HttpClient with optimized settings
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 10
      ..autoUncompress = true // Automatically decompress gzip responses
      ..userAgent = 'Nachna/1.0 (Flutter)';
    
    // Wrap the HttpClient in an IOClient for use with the http package
    _client = IOClient(httpClient);
  }
  
  static HttpClientService get instance {
    _instance ??= HttpClientService._();
    return _instance!;
  }
  
  http.Client get client => _client;
  
  // Helper method to create headers with gzip support
  static Map<String, String> getHeaders({String? authToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate', // Explicitly request compressed responses
    };
    
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    return headers;
  }
  
  // Helper method to log response compression info (for debugging)
  static void logCompressionInfo(http.Response response) {
    if (kDebugMode) {
      final contentEncoding = response.headers['content-encoding'];
      final contentLength = response.headers['content-length'];
      final bodyLength = response.bodyBytes.length;
      
      if (contentEncoding != null) {
        debugPrint('🗜️ Response compression: $contentEncoding');
        if (contentLength != null) {
          final originalSize = int.tryParse(contentLength) ?? 0;
          final compressionRatio = originalSize > 0 
              ? ((1 - (bodyLength / originalSize)) * 100).toStringAsFixed(1)
              : 'N/A';
          debugPrint('📊 Compression ratio: $compressionRatio% (${_formatBytes(originalSize)} → ${_formatBytes(bodyLength)})');
        }
      }
    }
  }
  
  // Helper method to format bytes for display
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  // Dispose method to clean up resources
  void dispose() {
    _client.close();
    _instance = null;
  }
} 