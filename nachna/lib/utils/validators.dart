/// Validates and sanitizes URLs for deep link handling.
///
/// This module provides validators for URLs, deep links, and general input
/// sanitization to prevent security vulnerabilities like injection attacks.
class UrlValidator {
  /// Allowed schemes for deep links
  static const List<String> allowedSchemes = ['https', 'http', 'nachna'];

  /// Allowed hosts for universal links
  static const List<String> allowedHosts = ['nachna.com', 'www.nachna.com'];

  /// Valid deep link path patterns (regex patterns)
  static const List<String> validPathPatterns = [
    r'^/artist/[a-zA-Z0-9_-]+$',
    r'^/studio/[a-zA-Z0-9_-]+$',
    r'^/order/status$',
    r'^/web/[a-zA-Z0-9_-]+$',
  ];

  /// Maximum URL length to prevent DoS attacks
  static const int maxUrlLength = 2048;

  /// Maximum path segment length
  static const int maxPathSegmentLength = 128;

  /// Validates a URL for deep link handling.
  /// Returns true if the URL is valid and safe to process.
  static bool isValidDeepLinkUrl(String url) {
    if (url.isEmpty || url.length > maxUrlLength) {
      return false;
    }

    try {
      final uri = Uri.parse(url);

      // Validate scheme
      if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return false;
      }

      // For custom scheme (nachna://), validate host is a valid deep link type
      if (uri.scheme.toLowerCase() == 'nachna') {
        return _isValidCustomSchemeUrl(uri);
      }

      // For http/https, validate against allowed hosts
      if (uri.scheme.toLowerCase() == 'http' || uri.scheme.toLowerCase() == 'https') {
        return _isValidUniversalLink(uri);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validates custom scheme URLs (nachna://)
  static bool _isValidCustomSchemeUrl(Uri uri) {
    final validHosts = ['artist', 'studio', 'order-status'];
    return validHosts.contains(uri.host.toLowerCase());
  }

  /// Validates universal links (https://nachna.com/...)
  static bool _isValidUniversalLink(Uri uri) {
    // Check host is in allowed list
    if (!allowedHosts.contains(uri.host.toLowerCase())) {
      return false;
    }

    // Check path matches one of the valid patterns
    final path = uri.path;
    for (final pattern in validPathPatterns) {
      if (RegExp(pattern).hasMatch(path)) {
        return true;
      }
    }

    // Also allow query-based order status
    if (path == '/order/status' && uri.queryParameters.containsKey('order_id')) {
      return true;
    }

    return false;
  }

  /// Safely parses a URL, returning null if invalid.
  static Uri? safeParseUrl(String url) {
    if (!isValidDeepLinkUrl(url)) {
      return null;
    }

    try {
      return Uri.parse(url);
    } catch (e) {
      return null;
    }
  }
}

/// Validates and sanitizes path parameters for deep links.
class PathValidator {
  /// Pattern for valid ID strings (MongoDB ObjectId, alphanumeric with hyphens/underscores)
  static final RegExp validIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Minimum ID length
  static const int minIdLength = 1;

  /// Maximum ID length
  static const int maxIdLength = 128;

  /// Pattern for valid order IDs (e.g., ord_123, pay_456)
  static final RegExp validOrderIdPattern = RegExp(r'^[a-zA-Z]+_[a-zA-Z0-9]+$');

  /// Validates an ID parameter from a deep link path.
  /// Returns true if the ID is safe to use.
  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) {
      return false;
    }

    if (id.length < minIdLength || id.length > maxIdLength) {
      return false;
    }

    return validIdPattern.hasMatch(id);
  }

  /// Validates an order ID parameter.
  static bool isValidOrderId(String? orderId) {
    if (orderId == null || orderId.isEmpty) {
      return false;
    }

    if (orderId.length > maxIdLength) {
      return false;
    }

    // Order IDs can be either format: ord_xxx or just alphanumeric
    return validOrderIdPattern.hasMatch(orderId) || validIdPattern.hasMatch(orderId);
  }

  /// Sanitizes an ID by removing any potentially dangerous characters.
  /// Returns null if the ID cannot be safely sanitized.
  static String? sanitizeId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    // Remove any characters that aren't alphanumeric, underscore, or hyphen
    final sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

    if (sanitized.isEmpty || sanitized.length > maxIdLength) {
      return null;
    }

    return sanitized;
  }

  /// Extracts and validates an artist ID from path segments.
  static String? extractArtistId(List<String> pathSegments) {
    if (pathSegments.length < 2) {
      return null;
    }

    if (pathSegments[0].toLowerCase() != 'artist') {
      return null;
    }

    final id = pathSegments[1];
    return isValidId(id) ? id : null;
  }

  /// Extracts and validates a studio ID from path segments.
  static String? extractStudioId(List<String> pathSegments) {
    if (pathSegments.length < 2) {
      return null;
    }

    if (pathSegments[0].toLowerCase() != 'studio') {
      return null;
    }

    final id = pathSegments[1];
    return isValidId(id) ? id : null;
  }
}

/// General input sanitization utilities.
class InputSanitizer {
  /// Sanitizes a string by removing control characters and limiting length.
  static String sanitizeString(String input, {int maxLength = 1000}) {
    if (input.isEmpty) {
      return input;
    }

    // Remove control characters except newlines and tabs
    var sanitized = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Sanitizes a mobile number by removing non-digit characters.
  static String sanitizeMobileNumber(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Checks if a string contains potentially malicious content.
  static bool containsSuspiciousContent(String input) {
    // Check for common injection patterns
    final suspiciousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+\s*=', caseSensitive: false),  // Event handlers
      RegExp(r'\$\{'),  // Template injection
      RegExp(r'\{\{'),  // Template injection
    ];

    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }

    return false;
  }
}

/// Logging utilities that sanitize sensitive data.
class SecureLogger {
  /// Truncates sensitive tokens for safe logging.
  /// Shows only the first few characters to aid debugging without exposing full token.
  static String truncateToken(String? token, {int visibleChars = 8}) {
    if (token == null || token.isEmpty) {
      return '[empty]';
    }

    if (token.length <= visibleChars) {
      return '[redacted]';
    }

    return '${token.substring(0, visibleChars)}...[${token.length} chars]';
  }

  /// Masks a token completely for production logging.
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) {
      return '[empty]';
    }
    return '[present, ${token.length} chars]';
  }

  /// Determines if detailed logging should be enabled.
  /// In production, sensitive data should not be logged.
  static bool get isDebugLoggingEnabled {
    // You can change this based on build mode or environment
    // For now, always use safe logging
    return false;
  }

  /// Safely logs token information without exposing the full token.
  static String safeTokenLog(String? token) {
    if (isDebugLoggingEnabled) {
      return truncateToken(token);
    }
    return maskToken(token);
  }
}
