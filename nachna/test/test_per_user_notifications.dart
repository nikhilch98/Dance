import 'package:flutter_test/flutter_test.dart';
import 'package:nachna/services/first_launch_service.dart';

void main() {
  group('Per-User Notification Permission Tests', () {
    late FirstLaunchService firstLaunchService;

    setUp(() {
      firstLaunchService = FirstLaunchService();
    });

    test('should track notification permissions per user', () async {
      print('🧪 Testing per-user notification permission tracking...');
      
      const user1Id = 'user123';
      const user2Id = 'user456';
      
      // Reset all permissions first
      await firstLaunchService.resetFirstLaunchStatus();
      
      // Check initial state - both users should need permission request
      final user1ShouldShow = await firstLaunchService.shouldRequestNotificationPermission(userId: user1Id);
      final user2ShouldShow = await firstLaunchService.shouldRequestNotificationPermission(userId: user2Id);
      
      print('🔍 User1 should show dialog: $user1ShouldShow');
      print('🔍 User2 should show dialog: $user2ShouldShow');
      
      expect(user1ShouldShow, isTrue);
      expect(user2ShouldShow, isTrue);
      
      // Mark permission as requested for user1 only
      await firstLaunchService.markNotificationPermissionRequested(userId: user1Id);
      
      // Check state after user1 permission request
      final user1ShouldShowAfter = await firstLaunchService.shouldRequestNotificationPermission(userId: user1Id);
      final user2ShouldShowAfter = await firstLaunchService.shouldRequestNotificationPermission(userId: user2Id);
      
      print('🔍 After user1 request - User1 should show: $user1ShouldShowAfter');
      print('🔍 After user1 request - User2 should show: $user2ShouldShowAfter');
      
      // User1 should not show dialog anymore, but user2 still should
      expect(user1ShouldShowAfter, isFalse);
      expect(user2ShouldShowAfter, isTrue);
      
      // Mark permission as requested for user2
      await firstLaunchService.markNotificationPermissionRequested(userId: user2Id);
      
      // Check final state
      final user1Final = await firstLaunchService.shouldRequestNotificationPermission(userId: user1Id);
      final user2Final = await firstLaunchService.shouldRequestNotificationPermission(userId: user2Id);
      
      print('🔍 Final state - User1 should show: $user1Final');
      print('🔍 Final state - User2 should show: $user2Final');
      
      // Both users should not show dialog anymore
      expect(user1Final, isFalse);
      expect(user2Final, isFalse);
      
      print('✅ Per-user notification permission tracking works correctly!');
    });

    test('should reset permission for specific user only', () async {
      print('🧪 Testing per-user permission reset...');
      
      const user1Id = 'user789';
      const user2Id = 'user101';
      
      // Mark both users as having requested permission
      await firstLaunchService.markNotificationPermissionRequested(userId: user1Id);
      await firstLaunchService.markNotificationPermissionRequested(userId: user2Id);
      
      // Verify both don't need to show dialog
      final user1Before = await firstLaunchService.shouldRequestNotificationPermission(userId: user1Id);
      final user2Before = await firstLaunchService.shouldRequestNotificationPermission(userId: user2Id);
      
      expect(user1Before, isFalse);
      expect(user2Before, isFalse);
      
      // Reset permission for user1 only
      await firstLaunchService.resetNotificationPermissionForUser(user1Id);
      
      // Check state after reset
      final user1After = await firstLaunchService.shouldRequestNotificationPermission(userId: user1Id);
      final user2After = await firstLaunchService.shouldRequestNotificationPermission(userId: user2Id);
      
      print('🔍 After reset - User1 should show: $user1After');
      print('🔍 After reset - User2 should show: $user2After');
      
      // User1 should show dialog again, user2 should not
      expect(user1After, isTrue);
      expect(user2After, isFalse);
      
      print('✅ Per-user permission reset works correctly!');
    });
  });
} 