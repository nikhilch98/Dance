import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import './providers/auth_provider.dart';
import './providers/config_provider.dart';
import './providers/reaction_provider.dart';
import './providers/global_config_provider.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './services/global_config.dart';
import './services/first_launch_service.dart';
import './services/deep_link_service.dart';
import './services/pending_order_service.dart';
import './services/app_update_service.dart';
import './utils/logger.dart';
import './widgets/notification_permission_dialog.dart';
import './screens/home_screen.dart';
import './screens/login_screen.dart';
import './screens/register_screen.dart';
import './screens/profile_setup_screen.dart';
import './screens/profile_screen.dart';
import './screens/admin_screen.dart';
import './screens/bundle_screen.dart';


/// Application entry point.
///
/// Initializes critical services before running the app:
/// 1. Flutter binding - required for async operations before runApp
/// 2. Global error handlers - catches and logs unhandled Flutter and platform errors
/// 3. GlobalConfig - loads cached configuration data for offline-first startup
void main() async {
  // Ensure Flutter binding is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Configure global error handling to catch and log unhandled exceptions
  // This helps with debugging crashes in production
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Catch platform-level errors that bypass Flutter's error handling
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Global error caught', error: error, stackTrace: stack);
    return true; // Prevent app crash by marking error as handled
  };

  // Initialize GlobalConfig to load cached data for faster startup
  // This provides offline-first capability and reduces API calls
  AppLogger.info('Initializing Global Config', tag: 'App');
  await GlobalConfig().initialize();
  AppLogger.info('Global Config initialized', tag: 'App');

  runApp(const MyApp());
}

/// Root application widget.
///
/// Sets up the Provider architecture with all state management providers
/// and configures the MaterialApp with the app's theme and routing.
class MyApp extends StatelessWidget {
  /// Global navigator key for navigation from outside widget tree (e.g., notifications).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider wraps the app with all state management providers
    // This makes auth, config, reactions, and global config available throughout the app
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => ReactionProvider()),
        ChangeNotifierProvider(create: (_) => GlobalConfigProvider()),
      ],
      child: MaterialApp(
        title: 'Nachna',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/profile-setup': (context) => const ProfileSetupScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/admin': (context) => const AdminScreen(),
          '/bundles': (context) => const BundleScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Wrapper widget that handles authentication state and app initialization.
///
/// This widget:
/// 1. Initializes services on first load (notifications, deep links, global config)
/// 2. Listens to AuthProvider state changes
/// 3. Routes to appropriate screen based on auth state
/// 4. Performs authenticated setup tasks (config refresh, reactions, pending orders)
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Flags to prevent duplicate initialization of services
  bool _hasRegisteredDeviceToken = false;
  bool _hasLoadedReactions = false;
  bool _hasRefreshedConfigThisSession = false;
  bool _hasShownNotificationDialog = false;
  bool _hasCheckedForUpdates = false;
  bool _hasInitializedAuth = false;
  bool _hasPendingAuthenticatedSetup = false;

  @override
  void initState() {
    super.initState();
    // Schedule initialization after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _performInitialSetup());
  }

  /// Performs initial app setup in correct order.
  ///
  /// Order matters:
  /// 1. Notifications - sets up push notification handling
  /// 2. Deep links - handles app links from external sources
  /// 3. Global config - syncs cached data with server
  /// 4. First launch - tracks onboarding completion
  /// 5. Auth - initializes authentication state (triggers UI update)
  Future<void> _performInitialSetup() async {
    if (!mounted) return;

    // Step 1: Initialize notifications (without requesting permission yet)
    // This sets up the method channel for receiving push notifications
    await _initializeNotifications();

    if (!mounted) return;

    // Step 2: Initialize deep link service for handling nachna:// URLs
    await _initializeDeepLinks();

    if (!mounted) return;

    // Step 3: Sync global config to ensure cached data is fresh
    await _initialGlobalConfigSync();

    if (!mounted) return;

    // Step 4: Handle first launch tracking for onboarding flows
    await _handleFirstLaunch();

    if (!mounted) return;

    // Step 5: Initialize auth - this will trigger the UI to show
    // the appropriate screen based on authentication state
    _hasInitializedAuth = true;
    Provider.of<AuthProvider>(context, listen: false).initializeAuth();
  }

  /// Performs setup tasks after user is authenticated.
  ///
  /// These tasks require an authenticated user:
  /// 1. Config refresh - gets latest feature flags and settings
  /// 2. Reaction provider setup - enables like/follow functionality
  /// 3. Pending orders check - resumes incomplete payments
  /// 4. Notification permission - prompts user if appropriate
  /// 5. App update check - shows update dialog if new version available
  Future<void> _performAuthenticatedSetup(
    ConfigProvider configProvider,
    ReactionProvider reactionProvider,
  ) async {
    if (!mounted || _hasPendingAuthenticatedSetup) return;
    _hasPendingAuthenticatedSetup = true;

    try {
      // Refresh config once per session to get latest feature flags
      if (!_hasRefreshedConfigThisSession && configProvider.state != ConfigState.loading) {
        _hasRefreshedConfigThisSession = true;
        AppLogger.debug('Refreshing config once per session', tag: 'AuthWrapper');
        configProvider.refreshConfig();
      }

      // Get auth token to set up authenticated services
      final token = await AuthService.getToken();
      if (!mounted) return;

      if (token != null) {
        // Enable reaction provider for likes/follows
        reactionProvider.setAuthToken(token);

        // Load user's existing reactions (likes, follows)
        if (!_hasLoadedReactions) {
          _hasLoadedReactions = true;
          reactionProvider.loadUserReactions();
        }

        // Device token sync now happens during ConfigProvider.loadConfig()
        _hasRegisteredDeviceToken = true;

        // Check for incomplete payment flows that need to be resumed
        await _checkPendingOrders();
      }

      if (!mounted) return;

      // Show notification permission dialog if user hasn't been asked
      await _showNotificationPermissionIfNeeded();

      if (!mounted) return;

      // Check if a new app version is available
      await _checkForAppUpdates();
    } finally {
      _hasPendingAuthenticatedSetup = false;
    }
  }

  /// Consolidated cleanup for unauthenticated state
  void _performUnauthenticatedCleanup(ConfigProvider configProvider) {
    AppLogger.debug('Clearing config provider after logout', tag: 'AuthWrapper');
    configProvider.clearConfig();
    PendingOrderService.instance.resetCheckFlag();
  }

  /// Consolidated error state setup
  Future<void> _performAuthenticatedErrorSetup(
    AuthProvider authProvider,
    ConfigProvider configProvider,
    ReactionProvider reactionProvider,
  ) async {
    if (!mounted) return;

    // Ensure config is loaded
    if (!configProvider.isLoaded && configProvider.state != ConfigState.loading) {
      configProvider.loadConfig();
    }

    // Try to reload reactions if not loaded
    if (authProvider.user != null && !_hasLoadedReactions && !reactionProvider.isLoading) {
      final token = await AuthService.getToken();
      if (token != null && mounted) {
        reactionProvider.setAuthToken(token);
        await reactionProvider.loadUserReactions();
      }
    }
  }

  Future<void> _initializeNotifications() async {
    AppLogger.debug('Starting notification initialization', tag: 'AuthWrapper');
    final deviceToken = await NotificationService().initialize(
      onNotificationTap: _handleNotificationTap,
    );

    if (deviceToken != null) {
      AppLogger.info('Notifications initialized successfully', tag: 'AuthWrapper');
    } else {
      AppLogger.warning('Failed to initialize notifications', tag: 'AuthWrapper');
    }
  }

  Future<void> _initializeDeepLinks() async {
    AppLogger.debug('Starting deep link initialization', tag: 'AuthWrapper');
    try {
      await DeepLinkService.instance.initialize();
      AppLogger.info('Deep links initialized successfully', tag: 'AuthWrapper');
    } catch (e) {
      AppLogger.error('Failed to initialize deep links', tag: 'AuthWrapper', error: e);
    }
  }

  Future<void> _initialGlobalConfigSync() async {
    AppLogger.debug('Starting initial global config sync', tag: 'AuthWrapper');
    try {
      await GlobalConfig().fullSync();
      AppLogger.info('Initial global config sync completed', tag: 'AuthWrapper');
    } catch (e) {
      AppLogger.error('Error during initial global config sync', tag: 'AuthWrapper', error: e);
    }
  }

  Future<void> _handleFirstLaunch() async {
    AppLogger.debug('Checking first launch status', tag: 'AuthWrapper');
    try {
      final isFirstLaunch = await FirstLaunchService().isFirstLaunch();
      if (isFirstLaunch) {
        AppLogger.info('First launch detected - marking as completed', tag: 'AuthWrapper');
        await FirstLaunchService().markFirstLaunchCompleted();
      }
    } catch (e) {
      AppLogger.error('Error handling first launch', tag: 'AuthWrapper', error: e);
    }
  }

  Future<void> _showNotificationPermissionIfNeeded() async {
    if (_hasShownNotificationDialog) return;

    try {
      // Get the current user ID from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.userId;

      if (userId == null) {
        AppLogger.debug('No user ID available for notification permission check', tag: 'AuthWrapper');
        return;
      }

      final shouldShow = await FirstLaunchService().shouldRequestNotificationPermission(userId: userId);

      if (shouldShow && mounted) {
        AppLogger.info('Showing notification permission dialog', tag: 'AuthWrapper');
        _hasShownNotificationDialog = true;

        // Wait a bit for the home screen to fully load
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => NotificationPermissionDialog(
              userId: userId,
              onPermissionGranted: () {
                AppLogger.info('Notification permission granted', tag: 'AuthWrapper');
              },
              onPermissionDenied: () {
                AppLogger.info('Notification permission denied', tag: 'AuthWrapper');
              },
              onDismissed: () {
                AppLogger.debug('Notification permission dialog dismissed', tag: 'AuthWrapper');
              },
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error showing notification permission dialog', tag: 'AuthWrapper', error: e);
    }
  }

  void _handleNotificationTap(String artistId) {
    _navigateToArtist(artistId, fromNotification: true);
  }

  void _navigateToArtist(String artistId, {bool fromNotification = false}) {
    // Use global navigator to avoid context issues
    DeepLinkService.navigateToArtist(context, artistId, fromNotification: fromNotification).catchError((error) {
      AppLogger.error('Error in artist navigation', tag: 'AuthWrapper', error: error);
    });
  }

  Future<void> _checkPendingOrders() async {
    try {
      AppLogger.debug('Checking for pending orders', tag: 'AuthWrapper');
      await PendingOrderService.instance.checkAndNavigateToPendingOrder();
    } catch (e) {
      AppLogger.error('Error checking pending orders', tag: 'AuthWrapper', error: e);
    }
  }

  Future<void> _checkForAppUpdates() async {
    if (_hasCheckedForUpdates) return;

    try {
      AppLogger.debug('Checking for app updates', tag: 'AuthWrapper');
      _hasCheckedForUpdates = true;

      // Add a small delay to ensure the home screen is fully loaded
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        await AppUpdateService().checkForUpdatesIfAuthenticated(context);
      }
    } catch (e) {
      AppLogger.error('Error checking for app updates', tag: 'AuthWrapper', error: e);
      _hasCheckedForUpdates = false; // Reset flag on error to allow retry
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, ConfigProvider, ReactionProvider>(
      builder: (context, authProvider, configProvider, reactionProvider, child) {
        AppLogger.debug('Build triggered. AuthState: ${authProvider.state}', tag: 'AuthWrapper');

        switch (authProvider.state) {
          case AuthState.initial:
          case AuthState.loading:
            return const Scaffold(
              backgroundColor: Color(0xFF0A0A0F),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
            
          case AuthState.authenticated:
            // Use single consolidated callback for all authenticated setup
            if (!_hasPendingAuthenticatedSetup) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _performAuthenticatedSetup(configProvider, reactionProvider);
              });
            }

            return const HomeScreen();
            
          case AuthState.profileIncomplete:
            return const ProfileSetupScreen();
            
          case AuthState.unauthenticated:
          case AuthState.error:
            AppLogger.debug('Handling unauthenticated state', tag: 'AuthWrapper');
            // Reset session flags when user becomes unauthenticated
            _hasRegisteredDeviceToken = false;
            _hasLoadedReactions = false;
            _hasRefreshedConfigThisSession = false;
            _hasShownNotificationDialog = false;
            _hasCheckedForUpdates = false;
            _hasPendingAuthenticatedSetup = false;

            // Use single callback for cleanup
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _performUnauthenticatedCleanup(configProvider);
            });

            return const LoginScreen();

          case AuthState.authenticatedError:
            // Use single callback for error state setup
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _performAuthenticatedErrorSetup(authProvider, configProvider, reactionProvider);
            });

            return const HomeScreen();
            
          default:
            return const Scaffold(
              backgroundColor: Color(0xFF0A0A0F),
              body: Center(
                child: Text('Unknown State', style: TextStyle(color: Colors.white)),
              ),
            );
        }
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF1A1A2E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 80,
                color: Color(0xFF00D4FF),
              ),
              SizedBox(height: 24),
              
              Text(
                'Dance Workshop',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              
              SizedBox(height: 32),
              
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
