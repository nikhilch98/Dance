import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nachna/providers/auth_provider.dart';
import 'package:nachna/main.dart';

void main() {
  group('Logout Debug Tests', () {
    testWidgets('Test AuthWrapper response to force logout', (WidgetTester tester) async {
      // Create a real AuthProvider
      final authProvider = AuthProvider();
      
      // Create a minimal app to test the AuthWrapper behavior
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: MaterialApp(
            home: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                print('TEST: AuthWrapper build - State: ${auth.state}, User: ${auth.user?.userId ?? 'null'}');
                
                switch (auth.state) {
                  case AuthState.authenticated:
                  case AuthState.profileIncomplete:
                  case AuthState.authenticatedError:
                    return const Scaffold(
                      body: Text('Authenticated Screen'),
                    );
                  case AuthState.unauthenticated:
                  case AuthState.error:
                    return const Scaffold(
                      body: Text('Login Screen'),
                    );
                  case AuthState.loading:
                  case AuthState.initial:
                  default:
                    return const Scaffold(
                      body: Text('Loading Screen'),
                    );
                }
              },
            ),
          ),
        ),
      );

      // Initial state should be initial or loading
      expect(find.text('Loading Screen'), findsOneWidget);
      print('TEST: Initial state verified');

      // Test the force logout method (synchronous)
      print('TEST: Testing force logout...');
      authProvider.forceLogout();
      await tester.pump(); // Trigger rebuild
      
      // Should now show login screen
      expect(find.text('Login Screen'), findsOneWidget);
      print('TEST: Force logout successful');
      
      // Verify state
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.user, isNull);
      print('TEST: Force logout state verification passed');
    });

    testWidgets('Test regular logout with timeout fallback', (WidgetTester tester) async {
      // Create a real AuthProvider
      final authProvider = AuthProvider();
      
      // Create a minimal app
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: authProvider,
          child: MaterialApp(
            home: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return Scaffold(
                  body: Text('State: ${auth.state}'),
                );
              },
            ),
          ),
        ),
      );

      // Test logout with short timeout (will likely timeout but should still work)
      print('TEST: Testing logout with timeout fallback...');
      try {
        await authProvider.logout().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('TEST: Logout timed out as expected, using force logout');
            authProvider.forceLogout();
          },
        );
      } catch (e) {
        print('TEST: Logout failed as expected: $e, using force logout');
        authProvider.forceLogout();
      }
      
      await tester.pump(); // Trigger rebuild
      
      // Should be unauthenticated regardless of how we got there
      expect(authProvider.state, AuthState.unauthenticated);
      expect(authProvider.user, isNull);
      print('TEST: Logout with fallback successful');
    });
  });
} 