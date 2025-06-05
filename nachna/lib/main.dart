import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:ui' as ui;
import './providers/auth_provider.dart';
import './providers/config_provider.dart';
import './providers/reaction_provider.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './screens/home_screen.dart';
import './screens/login_screen.dart';
import './screens/register_screen.dart';
import './screens/profile_setup_screen.dart';
import './screens/profile_screen.dart';
import './screens/admin_screen.dart';
import './screens/artist_detail_screen.dart';
import 'firebase_options.dart';

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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      ],
      child: MaterialApp(
        title: 'Nachna',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
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
  bool _hasLoadedReactions = false;
  bool _hasRegisteredDeviceToken = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize notifications first
      await _initializeNotifications();
      
      // Then initialize auth (which will sync device token if authenticated)
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
            // Load config when authenticated
            if (!configProvider.isLoaded && configProvider.state != ConfigState.loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.loadConfig();
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
                
                // Device token sync now happens during AuthProvider.initializeAuth()
                // so we don't need to do it here anymore
                _hasRegisteredDeviceToken = true; // Mark as handled
              }
            });
            
            return const HomeScreen();
            
          case AuthState.profileIncomplete:
            return const ProfileSetupScreen();
            
          case AuthState.unauthenticated:
          case AuthState.error:
            // Reset device token registration flag when user becomes unauthenticated
            _hasRegisteredDeviceToken = false;
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
