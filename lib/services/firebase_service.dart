import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../services/notification_center.dart';
import 'dart:io';
import 'dart:convert';
import '../models/user_profile.dart';


class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();



   /// Helper function to add or update FCM token for a user
  Future<void> _updateFcmToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayUnion([token])
        });
        print(' FCM token updated for $userId');
      }
    } catch (e) {
      print(' Error updating FCM token: $e');
    }
  }

  ///  Helper function to remove current device FCM token
  Future<void> _removeFcmToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token])
        });
        print(' FCM token removed for $userId');
      }
    } catch (e) {
      print(' Error removing FCM token: $e');
    }
  }



  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create Firestore user document
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'name': '',
        'age': 0,
        'gender': '',
        'bloodGroup': '',
        'fcmTokens': [], // initialize token array
        'isVerified': role == 'doctor' ? 'false' : null,
      });

      // Add token right after registration
      await _updateFcmToken(uid);


      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'operation-not-allowed':
          message = 'Email/Password authentication is not enabled. Please enable it in Firebase Console.';
          break;
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        default:
          message = 'Failed to create account: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }

  }



  // Future<UserCredential> signUpWithEmailAndPassword(
  //     String email, String password,String role) async {
  //   try {
  //     UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     // Create user document in Firestore
  //     await _firestore.collection('users').doc(userCredential.user!.uid).set({
  //       'email': email,
  //       'role': role,
  //       'createdAt': FieldValue.serverTimestamp(),
  //       'name': '',
  //       'age': 0,
  //       'gender': '',
  //       'bloodGroup': '',
  //       // Set default verification status for doctors
  //       'isVerified': role == 'doctor' ? 'false' : null,
  //     });

  //     return userCredential;
  //   } on FirebaseAuthException catch (e) {
  //     String message;
  //     switch (e.code) {
  //       case 'operation-not-allowed':
  //         message = 'Email/Password authentication is not enabled. Please enable it in Firebase Console.';
  //         break;
  //       case 'weak-password':
  //         message = 'The password provided is too weak.';
  //         break;
  //       case 'email-already-in-use':
  //         message = 'An account already exists for that email.';
  //         break;
  //       case 'invalid-email':
  //         message = 'The email address is invalid.';
  //         break;
  //       default:
  //         message = 'Failed to create account: ${e.message}';
  //     }
  //     throw Exception(message);
  //   } catch (e) {
  //     throw Exception('Failed to create account: $e');
  //   }

  // }



  // Sign in with email and password
 Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update FCM token after login
      await _updateFcmToken(userCredential.user!.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'operation-not-allowed':
          message = 'Email/Password authentication is not enabled. Please enable it in Firebase Console.';
          break;
        case 'user-not-found':
          message = 'No user found for the email address.';
          break;
        case 'wrong-password':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection and try again.';
          break;
        default:
          message = 'Failed to sign in: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }


  // Future<UserCredential> signInWithEmailAndPassword(
  //     String email, String password) async {
  //   try {
  //     return await _auth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );
  //   } on FirebaseAuthException catch (e) {
  //     String message;
  //     switch (e.code) {
  //       case 'operation-not-allowed':
  //         message = 'Email/Password authentication is not enabled. Please enable it in Firebase Console.';
  //         break;
  //       case 'user-not-found':
  //         message = 'No user found for the email address.';
  //         break;
  //       case 'wrong-password':
  //         message = 'Incorrect email or password.';
  //         break;
  //       case 'invalid-credential':
  //         message = 'Incorrect email or password.';
  //         break;
  //       case 'invalid-email':
  //         message = 'The email address is invalid.';
  //         break;
  //       case 'user-disabled':
  //         message = 'This user account has been disabled.';
  //         break;
  //       case 'too-many-requests':
  //         message = 'Too many failed attempts. Please try again later.';
  //         break;
  //       case 'network-request-failed':
  //         message = 'Network error. Please check your internet connection and try again.';
  //         break;
  //       default:
  //         message = 'Failed to sign in: ${e.message}';
  //     }
  //     throw Exception(message);
  //   } catch (e) {
  //     throw Exception('Failed to sign in: $e');
  //   }
  // }







 // Create user profile for Google sign-in (placed before usage)


  Future<void> _createGoogleUserProfile(User user) async {
    try {
      // Get user role from existing document if it exists
      final doc = await _firestore.collection('users').doc(user.uid).get();
      String? role = 'patient'; // default role

      if (doc.exists) {
        role = doc.data()?['role'] ?? 'patient';
      }

      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'age': 0,
        'gender': '',
        'bloodGroup': '',
        'fcmTokens': [],
        'photoURL': user.photoURL ?? '',
        'provider': 'google',
        // Set default verification status for doctors
        'isVerified': role == 'doctor' ? 'false' : null,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating Google user profile: $e');
      // Don't throw here as the user is already signed in
    }
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Check if this is a new user and create profile if needed
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _createGoogleUserProfile(userCredential.user!);
      }

      // Update FCM token for Google login
      await _updateFcmToken(userCredential.user!.uid);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          message = 'An account already exists with a different sign-in method.';
          break;
        case 'invalid-credential':
          message = 'The credential received is malformed or has expired.';
          break;
        case 'operation-not-allowed':
          message = 'Google sign-in is not enabled. Please enable it in Firebase Console.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'user-not-found':
          message = 'No user found with this credential.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided for this credential.';
          break;
        default:
          message = 'Failed to sign in with Google: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  




  // Sign out
   // Future<void> signOut() async {
    // await _auth.signOut();
    // await _googleSignIn.signOut();
    // Clear local in-app notifications so a fresh session starts empty
    // await NotificationCenter.instance.clearAll();
  //}

 Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _removeFcmToken(user.uid);
    }

    await _auth.signOut();
    await _googleSignIn.signOut();
    await NotificationCenter.instance.clearAll();     // Clear local in-app notifications so a fresh session starts empty

  }




    // ================= Reminders =================
  Future<String?> getFcmToken() async {
    try {
      // iOS specific prompt; Android returns immediately
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> addReminder({
    required String name,
    required String message,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int intervalMinutes,
    required bool enabled,
    required int tzOffsetMinutes,
  }) async {
    if (currentUser == null) return null;
    final token = await getFcmToken();
    return _firestore.collection('reminder').add({
      'userId': currentUser!.uid,
      'name': name,
      'message': message,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'intervalMinutes': intervalMinutes,
      'enabled': enabled,
      'tzOffsetMinutes': tzOffsetMinutes,
      'fcmToken': token,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getReminders() {
    if (currentUser == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _firestore
        .collection('reminder')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateReminderEnabled({
    required String reminderId,
    required bool enabled,
  }) async {
    await _firestore.collection('reminder').doc(reminderId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateReminderFields({
    required String reminderId,
    String? name,
    String? message,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (message != null) 'message': message,
      if (startHour != null) 'startHour': startHour,
      if (startMinute != null) 'startMinute': startMinute,
      if (endHour != null) 'endHour': endHour,
      if (endMinute != null) 'endMinute': endMinute,
      if (intervalMinutes != null) 'intervalMinutes': intervalMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('reminder').doc(reminderId).update(data);
  }

  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection('reminder').doc(reminderId).delete();
  }
  

  // ================= Health Metrics =================
  
  // Add or update health metrics for a specific date
  Future<void> saveHealthMetrics({
    required Map<String, dynamic> metrics,
    DateTime? date,
    String? notes,
  }) async {
    if (currentUser == null) return;

    final recordDate = date ?? DateTime.now();
    final dateKey = '${recordDate.year}-${recordDate.month.toString().padLeft(2, '0')}-${recordDate.day.toString().padLeft(2, '0')}';
    
    await _firestore
        .collection('health_metrics')
        .doc('${currentUser!.uid}_$dateKey')
        .set({
          'userId': currentUser!.uid,
          'date': dateKey,
          'metrics': metrics,
          'notes': notes,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // Get health metrics for a specific date
  Future<Map<String, dynamic>?> getHealthMetrics(DateTime date) async {
    if (currentUser == null) return null;

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final doc = await _firestore
        .collection('health_metrics')
        .doc('${currentUser!.uid}_$dateKey')
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  // Get health metrics for a date range
  Stream<QuerySnapshot> getHealthMetricsRange(DateTime startDate, DateTime endDate) {
    if (currentUser == null) return const Stream.empty();
    
    final startKey = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endKey = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    
    return _firestore
        .collection('health_metrics')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('date', isGreaterThanOrEqualTo: startKey)
        .where('date', isLessThanOrEqualTo: endKey)
        .orderBy('date')
        .snapshots();
  }

  // Get all health metrics for the current user
  Stream<QuerySnapshot> getAllHealthMetrics() {
    if (currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('health_metrics')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Delete health metrics for a specific date
  Future<void> deleteHealthMetrics(DateTime date) async {
    if (currentUser == null) return;
    
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('health_metrics')
        .doc('${currentUser!.uid}_$dateKey')
        .delete();
  }

  // Get metrics history for a specific metric type
  Stream<QuerySnapshot> getMetricHistory(String metricName, {int limit = 30}) {
    if (currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('health_metrics')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('metrics.$metricName', isNotEqualTo: null)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots();
  }


  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

 

  // Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    if (currentUser != null) {
      final allowedGenders = ['Male', 'Female', 'Other'];

      // Start from profile.toMap but remove nulls and protect immutable fields
      final raw = profile.toMap();

      // Do not allow role to be overwritten here unless explicitly provided non-empty
      raw.remove('role');

      // Sanitize gender: only include if allowed and not null
      final g = profile.gender;
      if (g == null || !allowedGenders.contains(g)) {
        raw.remove('gender');
      } else {
        raw['gender'] = g;
      }

      // Remove any null values so we don't overwrite existing fields with null
      final updateData = <String, dynamic>{
        for (final entry in raw.entries)
          if (entry.value != null) entry.key: entry.value,
      };

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      if (updateData.isEmpty) return;
      await _firestore.collection('users').doc(currentUser!.uid).update(updateData);
    }
  }

  // Get user data
  Future<UserProfile?> getUserData() async {
    if (currentUser != null) {
      DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      return UserProfile.fromMap(doc.data());
    }
    return null;
  }

  // Get current user profile (alias for getUserData)
  Future<UserProfile?> getCurrentUserProfile() async {
    return await getUserData();
  }

  // Add health record
  Future<void> addHealthRecord({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    if (currentUser != null) {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('health_records')
          .add({
        'type': type,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get health records
  Stream<QuerySnapshot<Map<String, dynamic>>> getHealthRecords() {
    if (currentUser != null) {
      return _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('health_records')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }

  Future<void> addAppointment({
    required String doctorName,
    required DateTime dateTime,
    required String reason,
    required String fees,
    required String doctorId,
  }) async {
    if (currentUser != null) {
      await _firestore.collection('appointments').add({
        'userId': currentUser!.uid,
        'doctorName': doctorName,
        'doctorId': doctorId,
        'dateTime': dateTime,
        'reason': reason,
        'fees': fees,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get appointments (for current user)
  Stream<QuerySnapshot<Map<String, dynamic>>> getAppointments() {
    if (currentUser != null) {
      return _firestore
          .collection('appointments')
          .where('userId', isEqualTo: currentUser!.uid) // 👈 filter by owner
          .orderBy('dateTime', descending: true)
          .snapshots();
    }
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }

// Reschedule appointment
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDateTime,
  }) async {
    if (currentUser != null) {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'dateTime': newDateTime,
        'status': 'rescheduled',
        'rescheduledAt': FieldValue.serverTimestamp(),
      });
    }
  }

// Cancel appointment
  Future<void> cancelAppointment(String appointmentId) async {
    if (currentUser != null) {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    }
  }

// Update appointment status
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    if (currentUser != null) {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Save payment method for future use
  Future<void> savePaymentMethod({
    required String cardNumber,
    required String expiryDate,
    required String cardHolderName,
    required String paymentType,
  }) async {
    if (currentUser != null) {
      await _firestore.collection('payment_methods').add({
        'userId': currentUser!.uid,
        'cardNumber': cardNumber,
        'expiryDate': expiryDate,
        'cardHolderName': cardHolderName,
        'paymentType': paymentType, // 'debit' or 'credit'
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }




  // Check if Firebase Storage is available
  Future<bool> isStorageAvailable() async {
    try {
      // Try to get the root reference instead of a specific file
      final rootRef = _storage.ref();
      await rootRef.listAll();
      return true;
    } catch (e) {
      print('Storage not available: $e');
      // Storage might be available but empty, so let's try a different approach
      return true; // Assume it's available and let the upload handle any errors
    }
  }

  // Upload profile image using Supabase Storage
  Future<String?> uploadProfileImage(File imageFile) async {
     try {
    print('Starting image upload...');
    
    // Generate a unique file name
    final fileName = 'public/${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    print('Upload filename: $fileName');
    
    final supabaseClient = supabase.Supabase.instance.client;

    print('Uploading to Supabase Storage...');
    
    // Upload the file to Supabase Storage
    await supabaseClient.storage
        .from('profile_images')
        .upload(
          fileName, 
          imageFile,
          fileOptions: const supabase.FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
    

    
    // Get the public URL
    final response = supabaseClient.storage
        .from('profile_images')
        .getPublicUrl(fileName);
    
    print('Public URL obtained: $response');
    
    return response;
    } catch (e) {
      print('Upload error details: $e');
      print('Error type: ${e.runtimeType}');
      
      // Handle specific Supabase Storage errors
      if (e.toString().contains('permission denied')) {
        throw Exception('Storage access denied. Please check Supabase Storage policies.');
      } else if (e.toString().contains('bucket not found')) {
        throw Exception('Storage bucket not found. Please create a bucket named "profile_images" in your Supabase project.');
      } else if (e.toString().contains('JWT expired')) {
        throw Exception('Authentication expired. Please sign in again.');
      }
      
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

 



  // Delete profile image
  Future<void> deleteProfileImage() async {
    if (currentUser == null) return;

    try {
      final storageRef = _storage
          .ref()
          .child('profile_images')
          .child('${currentUser!.uid}.jpg');

      await storageRef.delete();
    } catch (e) {
      // Image might not exist, which is fine
      print('Error deleting profile image: $e');
    }
  }
}
