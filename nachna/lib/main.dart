import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
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
      print('✅ Notifications initialized with token: ${deviceToken.substring(0, 10)}...');
    } else {
      print('❌ Failed to initialize notifications');
    }
  }

  void _handleNotificationTap(String artistId) {
    print('🎭 Deep link: Navigating to artist $artistId');
    
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
                reactionProvider.loadUserReactions();
                
                // Register device token with server after authentication
                await NotificationService().registerDeviceToken();
              }
            });
            
            return const HomeScreen();
            
          case AuthState.profileIncomplete:
            return const ProfileSetupScreen();
            
          case AuthState.unauthenticated:
          case AuthState.error:
            // Clear config on logout
            if (configProvider.isLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                configProvider.clearConfig();
              });
            }
            return const LoginScreen();
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
