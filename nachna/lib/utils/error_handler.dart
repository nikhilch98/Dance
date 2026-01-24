import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Error categories for classification
enum ErrorCategory {
  network,
  auth,
  validation,
  notFound,
  server,
  timeout,
  general,
}

/// Custom exception with category support
class AppException implements Exception {
  final String message;
  final ErrorCategory category;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    required this.category,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

/// Centralized error handling utility
class ErrorHandler {
  /// Private constructor for singleton
  ErrorHandler._();

  /// Singleton instance
  static final ErrorHandler instance = ErrorHandler._();

  /// Categorize an error based on its type and message
  static ErrorCategory categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Check for timeout errors
    if (error is TimeoutException || errorString.contains('timeout')) {
      return ErrorCategory.timeout;
    }

    // Check for network/socket errors
    if (error is SocketException ||
        errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet')) {
      return ErrorCategory.network;
    }

    // Check for authentication errors
    if (errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('token') ||
        errorString.contains('login')) {
      return ErrorCategory.auth;
    }

    // Check for not found errors
    if (errorString.contains('404') ||
        errorString.contains('not found')) {
      return ErrorCategory.notFound;
    }

    // Check for validation errors
    if (errorString.contains('400') ||
        errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return ErrorCategory.validation;
    }

    // Check for server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server')) {
      return ErrorCategory.server;
    }

    return ErrorCategory.general;
  }

  /// Get user-friendly message based on error category
  static String getUserFriendlyMessage(ErrorCategory category, [String? context]) {
    switch (category) {
      case ErrorCategory.network:
        return 'No internet connection. Please check your network and try again.';
      case ErrorCategory.timeout:
        return 'Request timed out. Please try again.';
      case ErrorCategory.auth:
        return 'Session expired. Please log in again.';
      case ErrorCategory.notFound:
        return context != null
            ? '$context was not found.'
            : 'The requested item was not found.';
      case ErrorCategory.validation:
        return 'Invalid input. Please check your data and try again.';
      case ErrorCategory.server:
        return 'Server error. Please try again later.';
      case ErrorCategory.general:
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Get icon for error category
  static IconData getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off_rounded;
      case ErrorCategory.timeout:
        return Icons.timer_off_rounded;
      case ErrorCategory.auth:
        return Icons.lock_outline_rounded;
      case ErrorCategory.notFound:
        return Icons.search_off_rounded;
      case ErrorCategory.validation:
        return Icons.warning_amber_rounded;
      case ErrorCategory.server:
        return Icons.cloud_off_rounded;
      case ErrorCategory.general:
      default:
        return Icons.error_outline_rounded;
    }
  }

  /// Get color for error category
  static Color getErrorColor(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
      case ErrorCategory.timeout:
        return const Color(0xFFFF9800); // Orange
      case ErrorCategory.auth:
        return const Color(0xFFE91E63); // Pink
      case ErrorCategory.notFound:
        return const Color(0xFF9C27B0); // Purple
      case ErrorCategory.validation:
        return const Color(0xFFFFC107); // Amber
      case ErrorCategory.server:
      case ErrorCategory.general:
      default:
        return const Color(0xFFF44336); // Red
    }
  }

  /// Log error with appropriate level
  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorCategory? category,
  }) {
    final errorCategory = category ?? categorizeError(error);
    final timestamp = DateTime.now().toIso8601String();

    print('[$timestamp] [ERROR] [$errorCategory]');
    if (context != null) {
      print('  Context: $context');
    }
    print('  Message: $error');
    if (stackTrace != null) {
      print('  StackTrace: $stackTrace');
    }
  }

  /// Show error snackbar with appropriate styling
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    String? errorContext,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    final category = categorizeError(error);
    final message = customMessage ?? getUserFriendlyMessage(category, errorContext);
    final color = getErrorColor(category);
    final icon = getErrorIcon(category);

    // Log the error
    logError(error, context: errorContext, category: category);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackbar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Check if error is retryable (network, timeout, server errors)
  static bool isRetryable(dynamic error) {
    final category = categorizeError(error);
    return category == ErrorCategory.network ||
           category == ErrorCategory.timeout ||
           category == ErrorCategory.server;
  }

  /// Wrap an async operation with error handling
  static Future<T?> handleAsync<T>(
    Future<T> Function() operation, {
    required BuildContext context,
    String? errorContext,
    bool showSnackbar = true,
    VoidCallback? onRetry,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      logError(e, stackTrace: stackTrace, context: errorContext);

      if (showSnackbar && context.mounted) {
        showErrorSnackbar(
          context,
          e,
          errorContext: errorContext,
          onRetry: isRetryable(e) ? onRetry : null,
        );
      }

      return null;
    }
  }
}

/// Extension on BuildContext for convenient error handling
extension ErrorHandlerExtension on BuildContext {
  /// Show error snackbar
  void showError(
    dynamic error, {
    String? customMessage,
    String? errorContext,
    VoidCallback? onRetry,
  }) {
    if (mounted) {
      ErrorHandler.showErrorSnackbar(
        this,
        error,
        customMessage: customMessage,
        errorContext: errorContext,
        onRetry: onRetry,
      );
    }
  }

  /// Show success snackbar
  void showSuccess(String message) {
    if (mounted) {
      ErrorHandler.showSuccessSnackbar(this, message);
    }
  }
}
