import 'package:flutter/foundation.dart';

/// Centralized logging utility for the Nachna app.
///
/// Provides structured logging with different severity levels and automatic
/// sensitive data truncation. Logging is automatically disabled in release builds.
///
/// Usage:
/// ```dart
/// AppLogger.debug('Processing data');
/// AppLogger.info('User logged in', tag: 'Auth');
/// AppLogger.warning('Rate limit approaching');
/// AppLogger.error('Failed to fetch data', error: e, stackTrace: stack);
/// ```
class AppLogger {
  /// Whether logging is enabled. Automatically disabled in release mode.
  static bool _isEnabled = kDebugMode;

  /// Maximum length for sensitive data before truncation.
  static const int _maxSensitiveLength = 20;

  /// Tags that indicate potentially sensitive data.
  static const List<String> _sensitivePatterns = [
    'token',
    'password',
    'secret',
    'auth',
    'key',
    'credential',
    'device_token',
  ];

  /// Enable or disable logging programmatically.
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if logging is currently enabled.
  static bool get isEnabled => _isEnabled;

  /// Log a debug message. Used for detailed development information.
  static void debug(String message, {String? tag}) {
    _log('DEBUG', message, tag: tag);
  }

  /// Log an info message. Used for general operational information.
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Log a warning message. Used for potentially problematic situations.
  static void warning(String message, {String? tag}) {
    _log('WARN', message, tag: tag);
  }

  /// Log an error message. Used for error conditions.
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag: tag);
    if (error != null) {
      _log('ERROR', 'Error: ${_sanitizeMessage(error.toString())}', tag: tag);
    }
    if (stackTrace != null && kDebugMode) {
      _log('ERROR', 'Stack trace: $stackTrace', tag: tag);
    }
  }

  /// Log a network-related message with automatic sensitive data handling.
  static void network(String message, {String? tag}) {
    _log('NET', message, tag: tag ?? 'Network');
  }

  /// Log a lifecycle event (init, dispose, state changes).
  static void lifecycle(String message, {String? tag}) {
    _log('LIFECYCLE', message, tag: tag);
  }

  /// Internal logging method.
  static void _log(String level, String message, {String? tag}) {
    if (!_isEnabled) return;

    final sanitizedMessage = _sanitizeMessage(message);
    final prefix = tag != null ? '[$tag]' : '';
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);

    // Use debugPrint for better handling of long messages in Flutter
    debugPrint('$timestamp $level $prefix $sanitizedMessage');
  }

  /// Sanitize a message by truncating potential sensitive data.
  static String _sanitizeMessage(String message) {
    String result = message;

    // Truncate long strings that might be tokens or secrets
    // Pattern: Look for strings that follow common patterns like "token: abc123..."
    for (final pattern in _sensitivePatterns) {
      // Match patterns like "token: value" or "token=value"
      final regex = RegExp(
        '($pattern[:\\s=]+)([a-zA-Z0-9_-]{${_maxSensitiveLength + 1},})',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(regex, (match) {
        final prefix = match.group(1) ?? '';
        final value = match.group(2) ?? '';
        if (value.length > _maxSensitiveLength) {
          return '$prefix${value.substring(0, _maxSensitiveLength)}...[TRUNCATED]';
        }
        return match.group(0) ?? '';
      });
    }

    // Truncate any standalone long alphanumeric strings (likely tokens)
    // This catches cases where the pattern doesn't have a prefix
    final longStringRegex = RegExp(r'\b[a-zA-Z0-9_-]{64,}\b');
    result = result.replaceAllMapped(longStringRegex, (match) {
      final value = match.group(0) ?? '';
      return '${value.substring(0, _maxSensitiveLength)}...[TRUNCATED]';
    });

    return result;
  }

  /// Safely truncate a token or sensitive string for logging.
  /// Returns the first [length] characters followed by "...".
  static String truncateToken(String? token, {int length = 20}) {
    if (token == null) return 'null';
    if (token.length <= length) return token;
    return '${token.substring(0, length)}...';
  }

  /// Create a log group for related operations.
  static void group(String groupName, void Function() operations) {
    if (!_isEnabled) return;

    debugPrint('===== START: $groupName =====');
    operations();
    debugPrint('===== END: $groupName =====');
  }

  /// Log the start of an async operation.
  static void startOperation(String operationName, {String? tag}) {
    _log('START', operationName, tag: tag);
  }

  /// Log the end of an async operation.
  static void endOperation(String operationName, {String? tag, bool success = true}) {
    final status = success ? 'completed' : 'failed';
    _log('END', '$operationName $status', tag: tag);
  }
}
