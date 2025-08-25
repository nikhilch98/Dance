# Gzip Compression Implementation Guide

## Overview

This guide explains the gzip compression implementation for the Nachna app, which reduces network bandwidth usage and improves app performance by compressing HTTP responses.

## Server Side Implementation

### FastAPI Gzip Middleware

The server uses FastAPI's built-in `GZipMiddleware` to automatically compress responses:

```python
from fastapi.middleware.gzip import GZipMiddleware

# Add GZip middleware for response compression
app.add_middleware(GZipMiddleware, minimum_size=1000)
```

**Configuration:**
- `minimum_size=1000`: Only compress responses larger than 1000 bytes
- Automatically handles `Accept-Encoding` headers from clients
- Compresses JSON, HTML, and other text-based responses

### How It Works

1. Client sends request with `Accept-Encoding: gzip, deflate` header
2. Server processes the request
3. If response is > 1000 bytes and client accepts gzip, server compresses the response
4. Server adds `Content-Encoding: gzip` header to response
5. Client automatically decompresses the response

## Client Side Implementation (Flutter)

### Custom HTTP Client Service

Created a centralized HTTP client service with gzip support:

```dart
// nachna/lib/services/http_client_service.dart
class HttpClientService {
  HttpClientService._() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 10
      ..autoUncompress = true // Automatically decompress gzip responses
      ..userAgent = 'Nachna/1.0 (Flutter)';
    
    _client = IOClient(httpClient);
  }
}
```

**Key Features:**
- `autoUncompress = true`: Automatically handles gzip decompression
- Connection pooling with `maxConnectionsPerHost = 10`
- Optimized timeouts for mobile networks
- Custom user agent for server analytics

### Request Headers

All requests now include gzip support headers:

```dart
static Map<String, String> getHeaders({String? authToken}) {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Encoding': 'gzip, deflate', // Request compressed responses
  };
  
  if (authToken != null) {
    headers['Authorization'] = 'Bearer $authToken';
  }
  
  return headers;
}
```

### Updated Services

All API services have been updated to use the optimized HTTP client:

1. **ApiService** - Workshop, artist, and studio endpoints
2. **AuthService** - Authentication and profile endpoints
3. **ReactionService** - User reactions and notifications

Example usage:
```dart
final response = await _httpClient.get(
  Uri.parse('$baseUrl/api/workshops?version=v2'),
  headers: HttpClientService.getHeaders(),
);
```

## Compression Statistics

### Debug Logging

In debug mode, the app logs compression statistics:

```dart
static void logCompressionInfo(http.Response response) {
  if (kDebugMode) {
    final contentEncoding = response.headers['content-encoding'];
    final contentLength = response.headers['content-length'];
    final bodyLength = response.bodyBytes.length;
    
    if (contentEncoding != null) {
      debugPrint('🗜️ Response compression: $contentEncoding');
      // Logs compression ratio and size reduction
    }
  }
}
```

### Expected Compression Ratios

- **JSON API responses**: 60-80% compression
- **Large workshop lists**: Up to 85% compression
- **Small responses (<1KB)**: Not compressed (overhead not worth it)

## Performance Benefits

### Network Benefits
- **Reduced bandwidth**: 60-80% less data transfer
- **Faster downloads**: Especially on slow mobile networks
- **Lower data costs**: Important for users with limited data plans

### App Performance
- **Faster screen loads**: Less data to download
- **Better offline caching**: More data fits in cache
- **Improved battery life**: Less radio usage

## Testing Compression

### Server Testing
```bash
# Test with curl
curl -H "Accept-Encoding: gzip" -v https://nachna.com/api/workshops?version=v2

# Check response headers
< Content-Encoding: gzip
< Content-Length: 12345  # Compressed size
```

### Flutter Testing
1. Run app in debug mode
2. Check console for compression logs:
   ```
   🗜️ Response compression: gzip
   📊 Compression ratio: 75.3% (45.2 KB → 11.1 KB)
   ```

### Network Monitoring
Use tools like:
- Charles Proxy
- Wireshark
- Chrome DevTools (for web version)

## Best Practices

1. **Always include Accept-Encoding header** in requests
2. **Set appropriate minimum_size** on server (1000 bytes is good default)
3. **Monitor compression ratios** to ensure effectiveness
4. **Test on slow networks** to verify performance improvements
5. **Handle both compressed and uncompressed** responses gracefully

## Troubleshooting

### Response Not Compressed
- Check if response size > minimum_size (1000 bytes)
- Verify Accept-Encoding header is sent
- Check server logs for middleware issues

### Decompression Errors
- Ensure `autoUncompress = true` in HttpClient
- Check for proxy interference
- Verify Content-Encoding header matches actual encoding

### Performance Issues
- Monitor compression CPU usage on server
- Check if very small responses are being compressed (overhead)
- Verify connection pooling is working

## Future Enhancements

1. **Brotli compression**: Even better compression ratios
2. **Request compression**: Compress large POST/PUT requests
3. **Selective compression**: Different settings per endpoint
4. **Cache integration**: Store compressed responses in cache
5. **Compression analytics**: Track bandwidth savings

## Conclusion

Gzip compression provides significant performance benefits with minimal implementation complexity. The 60-80% reduction in data transfer translates directly to faster app performance and better user experience, especially on mobile networks. 