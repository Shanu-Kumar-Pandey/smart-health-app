import 'dart:developer' show log;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _fcmTokenKey = 'fcm_token';
  static NotificationService? _instance;
  String? _currentToken;

  // Private constructor
  NotificationService._internal();

  // Singleton instance
  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  // Initialize FCM
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('User granted permission');
      await _handleInitialToken();
      _setupForegroundMessageHandler();
    } else {
      log('User declined or has not accepted permission');
    }
  }

  // Handle initial token retrieval and storage
  Future<void> _handleInitialToken() async {
    try {
      // Get the token from the device
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenLocally(token);
        
        // If user is logged in, update token in Firestore
        if (FirebaseAuth.instance.currentUser != null) {
          await _updateTokenInFirestore(token);
        }
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _saveTokenLocally(newToken);
        
        if (FirebaseAuth.instance.currentUser != null) {
          await _updateTokenInFirestore(newToken);
        }
      });
    } catch (e) {
      log('Error handling FCM token: $e');
    }
  }

  // Save token to shared preferences
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      log('FCM Token saved locally: $token');
    } catch (e) {
      log('Error saving FCM token locally: $e');
    }
  }

  // Update token in Firestore
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        log('FCM Token updated in Firestore for user: ${user.uid}');
      }
    } catch (e) {
      log('Error updating FCM token in Firestore: $e');
    }
  }

  // Remove token from Firestore when user logs out
  Future<void> removeTokenFromFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_fcmTokenKey);
      final user = FirebaseAuth.instance.currentUser;
      
      if (token != null && user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Clear local token
        await prefs.remove(_fcmTokenKey);
        _currentToken = null;
        
        log('FCM Token removed from Firestore for user: ${user.uid}');
      }
    } catch (e) {
      log('Error removing FCM token from Firestore: $e');
    }
  }

  // Setup foreground message handler
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Got a message whilst in the foreground!');
      log('Message data: ${message.data}');

      if (message.notification != null) {
        log('Message also contained a notification: ${message.notification}');
        // You can show a local notification here if needed
      }
    });
  }

  // Get current FCM token
  Future<String?> getFcmToken() async {
    if (_currentToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_fcmTokenKey);
    }
    return _currentToken;
  }

  // Handle background messages
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.
    // await Firebase.initializeApp();
    
    log("Handling a background message: ${message.messageId}");
    log('Message data: ${message.data}');
    
    if (message.notification != null) {
      log('Notification: ${message.notification}');
    }
  }
}
