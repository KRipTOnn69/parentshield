import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentshield/config/constants.dart';
import 'package:parentshield/config/theme.dart';
import 'package:parentshield/config/routes.dart';
import 'package:parentshield/providers/auth_provider.dart';
import 'package:parentshield/providers/child_provider.dart';
import 'package:parentshield/screens/mode_selection_screen.dart';

// Firebase initialization function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyA-oK_ZmAMuG8fvQ6TrzDkpK9pafTiq0Kc',
          authDomain: 'parentshield-1490a.firebaseapp.com',
          appId: '1:178125436872:web:53defd605435487f7172fd',
          messagingSenderId: '178125436872',
          projectId: 'parentshield-1490a',
          storageBucket: 'parentshield-1490a.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Set up Firebase Messaging (only on mobile)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Lock app to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive for local data persistence
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Hive initialization failed: $e');
  }

  // Check if this device is in child mode (paired)
  final prefs = await SharedPreferences.getInstance();
  final isPaired = prefs.getBool('is_paired') ?? false;
  final initialRoute = isPaired ? AppRoutes.childStatus : AppRoutes.modeSelection;
  debugPrint('[ParentShield] Startup: isPaired=$isPaired, initialRoute=$initialRoute');

  runApp(ParentShieldApp(initialRoute: initialRoute));
}

class ParentShieldApp extends StatefulWidget {
  final String initialRoute;

  const ParentShieldApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  State<ParentShieldApp> createState() => _ParentShieldAppState();
}

class _ParentShieldAppState extends State<ParentShieldApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeFirebaseMessaging();
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;

      await firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final token = await firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification!.title}',
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        if (message.data.isNotEmpty) {
          _handleNotificationTap(message.data);
        }
      });

      firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
      });
    } catch (e) {
      debugPrint('Firebase Messaging init failed: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null) {
      navigatorKey.currentState?.pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChildProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        onGenerateRoute: AppRoutes.generateRoute,
        initialRoute: widget.initialRoute,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

/// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
