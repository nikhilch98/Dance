import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
  // Performance optimizations
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (still needed for other Firebase services if you use them)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
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
        title: 'Dance Workshop App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D4FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          // Performance optimizations
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
        // Performance optimizations
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0), // Prevent text scaling issues
            child: child!,
          );
        },
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _hasRegisteredDeviceToken = false;
  bool _hasLoadedReactions = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize authentication state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).initializeAuth();
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    // Initialize notification service with deep link handler
    final deviceToken = await NotificationService().initialize(
      onNotificationTap: _handleNotificationTap,
    );
    
    if (deviceToken != null) {
      // Notifications initialized successfully
    } else {
      // Failed to initialize notifications
    }
  }

  void _handleNotificationTap(String artistId) {
    // Deep link: Navigating to artist
    
    // Navigate to artists tab and then to specific artist
    _navigateToArtist(artistId);
  }

  void _navigateToArtist(String artistId) {
    // First ensure we're on the home screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)), // Artists tab
      (route) => false,
    );
    
    // Then navigate to specific artist after a short delay
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
        switch (authProvider.state) {
          case AuthState.initial:
          case AuthState.loading:
            return const LoadingScreen();
            
          case AuthState.authenticated:
            // Load config when authenticated
            if (!configProvider.isLoaded && configProvider.state != ConfigState.loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.loadConfig();
              });
            }
            
            // Initialize reaction provider with auth token
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final token = await AuthService.getToken();
              if (token != null) {
                reactionProvider.setAuthToken(token);
                
                // Load user reactions only once per authentication
                if (!_hasLoadedReactions) {
                  _hasLoadedReactions = true;
                  reactionProvider.loadUserReactions();
                }
                
                // Register device token with server now that we're authenticated (only once)
                if (!_hasRegisteredDeviceToken) {
                  _hasRegisteredDeviceToken = true;
                  await NotificationService().registerCurrentDeviceToken();
                }
              }
            });
            
            return const HomeScreen();
            
          case AuthState.profileIncomplete:
            return const ProfileSetupScreen();
            
          case AuthState.unauthenticated:
            // Clear config and reset flags when unauthenticated (e.g., after logout)
            if (configProvider.isLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.clearConfig();
              });
            }
            _hasRegisteredDeviceToken = false;
            _hasLoadedReactions = false;
            return const LoginScreen();

          case AuthState.error: // For errors during initial auth, login, register
            // Clear config and reset flags as we are navigating to login
            if (configProvider.isLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.clearConfig();
              });
            }
            _hasRegisteredDeviceToken = false;
            _hasLoadedReactions = false;
            return const LoginScreen();

          case AuthState.authenticatedError: // For errors AFTER user is already authenticated
            // User remains authenticated, so we stay on HomeScreen.
            // The specific screen (e.g., ProfileScreen) should handle showing the error message.
            
            // Ensure essential data (like config) is loaded if it wasn't due to an early error.
            if (!configProvider.isLoaded && configProvider.state != ConfigState.loading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.loadConfig();
              });
            }
            
            // If an error occurred before reactions were loaded in this session, try to load them.
            // We check _hasLoadedReactions (from AuthWrapperState) which is set to true
            // in the AuthState.authenticated block after the first attempt to load reactions.
            if (authProvider.user != null && !_hasLoadedReactions && !reactionProvider.isLoading) {
                 WidgetsBinding.instance.addPostFrameCallback((_) async {
                    // Ensure ReactionService has the token (it should, but as a safeguard)
                    final token = await AuthService.getToken();
                    if (token != null) {
                       reactionProvider.setAuthToken(token);
                       // Attempt to load reactions. If this also fails, an error will be set in ReactionProvider.
                       await reactionProvider.loadUserReactions();
                       // We don't set _hasLoadedReactions = true here; that's done in the main AuthState.authenticated flow
                       // to ensure it's only set after a successful initiation of loading.
                    }
                 });
            }
            return const HomeScreen(); // Stay on HomeScreen
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
              // Logo
              Icon(
                Icons.music_note,
                size: 80,
                color: Color(0xFF00D4FF),
              ),
              SizedBox(height: 24),
              
              // App Title
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
              
              // Loading Indicator
              CircularProgressIndicator(
                color: Color(0xFF00D4FF),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
