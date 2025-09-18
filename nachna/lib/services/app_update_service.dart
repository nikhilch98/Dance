import 'package:flutter/material.dart';
import './version_service.dart';
import '../widgets/force_update_dialog.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Check for app updates and show force update dialog if needed
  Future<bool> checkForUpdates(BuildContext context) async {
    try {
      print('[AppUpdateService] Checking for app updates...');

      final updateInfo = await VersionService().checkForUpdate();

      final needsUpdate = updateInfo['needs_update'] as bool;
      final forceUpdate = updateInfo['force_update'] as bool;

      if (needsUpdate && forceUpdate) {
        print('[AppUpdateService] Force update required - showing dialog');
        await _showForceUpdateDialog(
          context,
          updateInfo['update_message'] as String,
          updateInfo['ios_app_store_url'] as String,
          updateInfo['current_version'] as String,
          updateInfo['minimum_version'] as String,
        );
        return true; // Update dialog was shown
      } else if (needsUpdate) {
        print('[AppUpdateService] Update available but not forced');
        // You could show a non-blocking update dialog here if needed
        return false;
      } else {
        print('[AppUpdateService] App is up to date');
        return false;
      }
    } catch (e) {
      print('[AppUpdateService] Error checking for updates: $e');
      // Don't block the app if update check fails
      return false;
    }
  }

  /// Show force update dialog
  Future<void> _showForceUpdateDialog(
    BuildContext context,
    String message,
    String appStoreUrl,
    String currentVersion,
    String minimumVersion,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal
      builder: (BuildContext context) {
        return ForceUpdateDialog(
          message: message,
          appStoreUrl: appStoreUrl,
          currentVersion: currentVersion,
          minimumVersion: minimumVersion,
        );
      },
    );
  }

  /// Check if user is authenticated before checking for updates
  Future<bool> checkForUpdatesIfAuthenticated(BuildContext context) async {
    // Only check for updates if user is authenticated
    // This prevents showing update dialog to unauthenticated users
    try {
      // You can add authentication check here if needed
      // For now, we'll always check since the API requires authentication
      return await checkForUpdates(context);
    } catch (e) {
      print('[AppUpdateService] Error in authenticated update check: $e');
      return false;
    }
  }
}
