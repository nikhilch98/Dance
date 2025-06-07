import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:ui' as ui;
import './providers/auth_provider.dart';
import './providers/config_provider.dart';
import './providers/reaction_provider.dart';
import './providers/global_config_provider.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './services/global_config.dart';
import './services/first_launch_service.dart';
import './widgets/notification_permission_dialog.dart';
import './screens/home_screen.dart';
import './screens/login_screen.dart';
import './screens/register_screen.dart';
import './screens/profile_setup_screen.dart';
import './screens/profile_screen.dart';
import './screens/admin_screen.dart';
import './screens/artist_detail_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    print('Global error caught: $error');
    return true;
  };

  // Firebase removed - using native iOS push notifications

  // Initialize Global Config
  print('🌐 Initializing Global Config...');
  await GlobalConfig().initialize();
  print('🌐 Global Config initialized');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasRegisteredDeviceToken = false;
  bool _hasLoadedReactions = false;
  bool _hasRefreshedConfigThisSession = false;
  bool _hasShownNotificationDialog = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize notifications first (without requesting permission yet)
      await _initializeNotifications();
      
      // Perform initial sync of global config
      await _initialGlobalConfigSync();
      
      // Mark first launch as completed if needed
      await _handleFirstLaunch();
      
      // Then initialize auth
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).initializeAuth();
      }
    });
  }

  Future<void> _initializeNotifications() async {
    print('[AuthWrapper] Starting notification initialization...');
    final deviceToken = await NotificationService().initialize(
      onNotificationTap: _handleNotificationTap,
    );
    
    if (deviceToken != null) {
      print('[AuthWrapper] Notifications initialized successfully with token: ${deviceToken.substring(0, 20)}...');
    } else {
      print('[AuthWrapper] Failed to initialize notifications');
    }
  }

  Future<void> _initialGlobalConfigSync() async {
    print('[AuthWrapper] Starting initial global config sync...');
    try {
      await GlobalConfig().fullSync();
      print('[AuthWrapper] Initial global config sync completed');
    } catch (e) {
      print('[AuthWrapper] Error during initial global config sync: $e');
    }
  }

  Future<void> _handleFirstLaunch() async {
    print('[AuthWrapper] Checking first launch status...');
    try {
      final isFirstLaunch = await FirstLaunchService().isFirstLaunch();
      if (isFirstLaunch) {
        print('[AuthWrapper] First launch detected - marking as completed');
        await FirstLaunchService().markFirstLaunchCompleted();
      }
    } catch (e) {
      print('[AuthWrapper] Error handling first launch: $e');
    }
  }

  Future<void> _showNotificationPermissionIfNeeded() async {
    if (_hasShownNotificationDialog) return;
    
    try {
      // Get the current user ID from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.userId;
      
      if (userId == null) {
        print('[AuthWrapper] No user ID available for notification permission check');
        return;
      }
      
      final shouldShow = await FirstLaunchService().shouldRequestNotificationPermission(userId: userId);
      
      if (shouldShow && mounted) {
        print('[AuthWrapper] Showing notification permission dialog for user: $userId');
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
                print('[AuthWrapper] Notification permission granted for user: $userId');
              },
              onPermissionDenied: () {
                print('[AuthWrapper] Notification permission denied for user: $userId');
              },
              onDismissed: () {
                print('[AuthWrapper] Notification permission dialog dismissed for user: $userId');
              },
            ),
          );
        }
      } else {
        print('[AuthWrapper] Not showing notification dialog for user: $userId (shouldShow: $shouldShow)');
      }
    } catch (e) {
      print('[AuthWrapper] Error showing notification permission dialog: $e');
    }
  }

  void _handleNotificationTap(String artistId) {
    _navigateToArtist(artistId);
  }

  void _navigateToArtist(String artistId) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
      (route) => false,
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(
            artistId: artistId,
            fromNotification: true,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, ConfigProvider, ReactionProvider>(
      builder: (context, authProvider, configProvider, reactionProvider, child) {
        print('[AuthWrapper] Build triggered. AuthState: ${authProvider.state}, User: ${authProvider.user?.userId ?? 'none'}');

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
            // Refresh config once per session on app startup to sync device token
            if (!_hasRefreshedConfigThisSession && configProvider.state != ConfigState.loading) {
              _hasRefreshedConfigThisSession = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                print('[AuthWrapper] Refreshing config once per session to sync device token');
                configProvider.refreshConfig();
              });
            }
            
            // Initialize reaction provider
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final token = await AuthService.getToken();
              if (token != null) {
                reactionProvider.setAuthToken(token);
                
                if (!_hasLoadedReactions) {
                  _hasLoadedReactions = true;
                  reactionProvider.loadUserReactions();
                }
                
                // Device token sync now happens during ConfigProvider.loadConfig()
                // so we don't need to do it here anymore
                _hasRegisteredDeviceToken = true; // Mark as handled
              }
              
              // Show notification permission dialog if appropriate
              await _showNotificationPermissionIfNeeded();
            });
            
            return const HomeScreen();
            
          case AuthState.profileIncomplete:
            return const ProfileSetupScreen();
            
          case AuthState.unauthenticated:
          case AuthState.error:
            print('[AuthWrapper] Handling unauthenticated state - should show LoginScreen');
            // Reset session flags when user becomes unauthenticated
            _hasRegisteredDeviceToken = false;
            _hasLoadedReactions = false;
            _hasRefreshedConfigThisSession = false;
            _hasShownNotificationDialog = false; // Reset notification dialog flag
            
            // Clear other providers when user becomes unauthenticated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print('[AuthWrapper] Clearing config provider after logout');
              configProvider.clearConfig();
              // Note: ReactionProvider doesn't need explicit clearing as it relies on auth token
            });
            
            return const LoginScreen();

          case AuthState.authenticatedError:
            // Ensure config is loaded
            if (!configProvider.isLoaded && configProvider.state != ConfigState.loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.loadConfig();
              });
            }
            
            // Try to reload reactions if not loaded
            if (authProvider.user != null && !_hasLoadedReactions && !reactionProvider.isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final token = await AuthService.getToken();
                if (token != null) {
                  reactionProvider.setAuthToken(token);
                  await reactionProvider.loadUserReactions();
                }
              });
            }
            
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
