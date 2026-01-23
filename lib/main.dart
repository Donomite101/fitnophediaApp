// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core Services & UI
import 'core/services/auth_service.dart';
import 'core/app_theme.dart';
import 'core/services/notifications/notification_service.dart';
import 'features/member/diet/services/hydration_alarm_service.dart';
import 'core/theme_provider.dart';

// Screens
import 'features/auth/splash_screen.dart';

// Routes
import 'features/member/chat/ChatScreen.dart';
import 'features/workout/data/providers/workout_provider.dart';
import 'features/workout/data/services/workout_api_service.dart';
import 'features/workout/data/services/workout_cache_service.dart';
import 'features/workout/data/services/workout_repository.dart';
import 'routes/app_routes.dart';

// Global navigation key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler for FCM — must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  print('FCM background message received: ${message.messageId}');
}

/// Initialize Firebase Cloud Messaging (minimal logs)
Future<void> initializeFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // small delay to avoid SERVICE_NOT_AVAILABLE race
      await Future.delayed(const Duration(seconds: 1));
      final token = await messaging.getToken();
      if (token != null) {
        print('FCM token: ${token.substring(0, token.length > 8 ? 8 : token.length)}...');
      } else {
        print('FCM token: null');
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('FCM foreground message: ${message.notification?.title ?? ''}');
      });
    } else {
      print('FCM permissions not granted.');
    }
  } catch (e) {
    print('FCM init error: $e');
  }
}

/// Initialize Supabase from .env (minimal logs)
Future<void> initializeSupabase() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env optional — skip if missing
    print('.env not loaded: $e');
    return;
  }

  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
  final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print('Supabase credentials missing in .env');
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
    );
    print('Supabase initialized');
  } catch (e) {
    print('Supabase init error: $e');
  }
}

/// Handle alarm notification taps - navigate to diet screen
Future<void> setupAlarmNotificationHandler() async {
  Alarm.ringStream.stream.listen((alarmSettings) async {
    debugPrint('Alarm ringing: ${alarmSettings.id}');
    
    // Check if this is a hydration alarm (IDs 100-149)
    if (alarmSettings.id >= 100 && alarmSettings.id < 150) {
      debugPrint('Hydration alarm detected, stopping alarm and preparing navigation...');
      
      // Stop the alarm immediately to dismiss the notification
      await Alarm.stop(alarmSettings.id);
      debugPrint('Alarm ${alarmSettings.id} stopped');
      
      // Wait a moment for the app to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get gym and member IDs from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final gymId = prefs.getString('gymId') ?? '';
        final memberId = prefs.getString('memberId') ?? '';
        
        if (gymId.isNotEmpty && memberId.isNotEmpty) {
          debugPrint('Navigating to diet screen: gymId=$gymId, memberId=$memberId');
          
          // Navigate to diet screen using the global navigator key
          navigatorKey.currentState?.pushNamed(
            AppRoutes.dietPlanner,
            arguments: {
              'gymId': gymId,
              'memberId': memberId,
            },
          );
        } else {
          debugPrint('Cannot navigate: gymId or memberId is empty');
        }
      } catch (e) {
        debugPrint('Error navigating to diet screen: $e');
      }
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file FIRST
  try {
    await dotenv.load(fileName: '.env');
    print('.env file loaded successfully');
  } catch (e) {
    print('Warning: .env file not found or failed to load: $e');
  }
  
  // Initialize Firebase (will use env vars from .env)
  await Firebase.initializeApp();

  // Initialize local notification service
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  // Initialize Diet Notification Service (Hydration - Alarm)
  try {
    await HydrationAlarmService().initialize();
    debugPrint('Hydration Alarm Service initialized in main');
    
    // Set up alarm notification tap handler
    await setupAlarmNotificationHandler();
    debugPrint('Alarm notification handler set up');
  } catch (e) {
    debugPrint('Hydration Alarm init failed: $e');
  }

  // Firestore persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  } catch (_) {}

  // Initialize Supabase (Must be done before WorkoutProvider loads)
  await initializeSupabase();

  final workoutProvider = WorkoutProvider(
    repository: WorkoutRepository(
      api: WorkoutApiService(),
      cache: WorkoutCache(),
    ),
  );

  // Load before runApp()
  await workoutProvider.loadExercises();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: workoutProvider),
      ],
      child: MyApp(),
    ),
  );

  // Background initializations
  Future.microtask(() => initializeFCM());
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _message = details.exceptionAsString();
        });
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Something went wrong', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(_message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _message = '';
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                    ),
                    child: const Text('Go to Splash Screen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const String routeSplash = AppRoutes.splash;
  static const String routeChat = '/chat';

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    try {
      if (settings.name == routeChat) {
        return MaterialPageRoute(
          builder: (_) => const ChatScreen(gymId: '', memberId: ''),
          settings: settings,
        );
      }

      final generated = AppRoutes.generateRoute(settings);
      if (generated != null) return generated;
    } catch (e) {
      print('Route generation error for ${settings.name}: $e');
    }

    return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    // Read the ThemeProvider safely and fall back to system if shape differs.
    final themeProvider = context.watch<ThemeProvider?>();
    ThemeMode themeMode = ThemeMode.system;

    if (themeProvider != null) {
      try {
        // try common property name 'themeMode'
        final dynamic tm = (themeProvider as dynamic).themeMode;
        if (tm is ThemeMode) themeMode = tm;
      } catch (_) {}
      try {
        // try alternative property name 'mode'
        final dynamic tm2 = (themeProvider as dynamic).mode;
        if (tm2 is ThemeMode) themeMode = tm2;
      } catch (_) {}
      try {
        // try boolean flag isDark
        final dynamic isDark = (themeProvider as dynamic).isDark;
        if (isDark is bool) themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      } catch (_) {}
    }

    return ErrorBoundary(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Fitnophedia Gym Management',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: routeSplash,
        onGenerateRoute: _generateRoute,
        onUnknownRoute: (settings) {
          print('Unknown route requested: ${settings.name}');
          return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
