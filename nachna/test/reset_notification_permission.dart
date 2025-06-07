import 'package:flutter_test/flutter_test.dart';
import 'package:nachna/services/first_launch_service.dart';

void main() {
  test('Reset notification permission status', () async {
    print('🔄 Resetting notification permission status...');
    
    final firstLaunchService = FirstLaunchService();
    
    // Reset the notification permission status
    await firstLaunchService.resetFirstLaunchStatus();
    
    print('✅ Notification permission status reset');
    print('📱 The app should now show the notification permission dialog on next launch');
    
    // Verify the reset worked
    final shouldShow = await firstLaunchService.shouldRequestNotificationPermission();
    print('🔍 Should show notification dialog: $shouldShow');
    
    expect(shouldShow, isTrue);
  });
} 