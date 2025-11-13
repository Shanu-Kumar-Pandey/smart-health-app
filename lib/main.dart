import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'pages/home_page.dart';
import 'screen/onboarding1_screen.dart';
import 'services/firebase_service.dart';
import 'services/notification_center.dart';
import 'notification/notification_service.dart';
import 'notification/notification_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolates
  await Firebase.initializeApp();
}



void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['url']!,
    anonKey: dotenv.env['anonKey']!,
  );
  
  // Initialize notification services
  final notificationService = NotificationService.instance;
  await notificationService.initialize();
  
  final notificationHelper = NotificationHelper();
  await notificationHelper.requestNotificationPermissions();
  
  // Initialize client-side notification center if needed
  // await NotificationCenter.instance.initialize();
  
  // Background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final title = message.notification?.title ?? 'New Message';
    final body = message.notification?.body ?? 'You have a new notification';
    
    // Show local notification
    await notificationHelper.showSimpleNotification(
      title: title,
      body: body,
    );
    
    // Store in app notification center as unread if needed
    await NotificationCenter.instance.add(title: title, body: body, markUnread: true);
  });

  // App opened from a notification (foreground -> background -> foreground)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    // Open in-app notifications panel instead of Reminders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomePage.openNotificationsPanel();
    });
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const RootRouter(),
        );
      },
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Avoid showing a loading spinner on theme changes by deciding using currentUser when waiting
    final firebaseService = FirebaseService();
    return StreamBuilder(
      stream: firebaseService.authStateChanges,
      builder: (context, snapshot) {
        final user = firebaseService.currentUser;
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Use last known auth state instead of showing a loader
          return user != null ? const MainPage() : const Onboarding1Screen();
        }
        return (snapshot.hasData || user != null) ? const MainPage() : const Onboarding1Screen();
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    // Handle app opened from a terminated state via FCM
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HomePage.openNotificationsPanel();
        });
      }
    });

    // Handle native deeplink from AlarmReceiver
    const MethodChannel channel = MethodChannel('com.example.healthhub/native_alarm');
    channel.invokeMethod<String>('getLaunchDeeplink').then((deeplink) {
      if (deeplink == 'notifications') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HomePage.openNotificationsPanel();
        });
      }
    }).catchError((_) {});
  }
  @override
  Widget build(BuildContext context) {
    // Wire the global key to enable programmatic tab navigation
    return HomePage(key: HomePage.homeKey);
  }
}
