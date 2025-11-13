import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;


  // Check and set default isVerified field for doctors
  Future<void> checkAndSetDoctorVerification() async {
    if (currentUser != null) {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = data['role'];
        final isVerified = data['isVerified'];

        // If user is doctor and doesn't have isVerified field, set it to 'false'
        if (role == 'doctor' && isVerified == null) {
          await _firestore.collection('users').doc(currentUser!.uid).update({
            'isVerified': 'false',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  // Submit doctor verification documents
  Future<void> submitDoctorVerification({
    required String licenseNumber,
    required String specialization,
    required String experience,
    required String clinicName,
    required String clinicAddress,
    required String phoneNumber,
    String? additionalInfo,
    required String fees,
    required String qualification,
    required String consultation,
    required String about,
  }) async {
    if (currentUser != null) {
      final userId = currentUser!.uid;
      
      // Check if there's an existing verification document
      final querySnapshot = await _firestore
          .collection('document_verification')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final verificationData = {
        'userId': userId,
        'licenseNumber': licenseNumber,
        'specialization': specialization,
        'experience': experience,
        'clinicName': clinicName,
        'clinicAddress': clinicAddress,
        'phoneNumber': phoneNumber,
        'additionalInfo': additionalInfo,
        'fees': fees,
        'qualification': qualification,
        'consultation': consultation,
        'about': about,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing document
        await _firestore
            .collection('document_verification')
            .doc(querySnapshot.docs.first.id)
            .update(verificationData);
      } else {
        // Create new document if none exists
        await _firestore.collection('document_verification').add(verificationData);
      }

      // Update user's verification status to pending
      await _firestore.collection('users').doc(userId).update({
        'isVerified': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get doctor verification status
  Future<String?> getDoctorVerificationStatus() async {
    if (currentUser != null) {
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isVerified'] as String?;
      }
    }
    return null;
  }

  // Update doctor verification status (for admin use)
  Future<void> updateDoctorVerificationStatus(String userId, String status) async {
    await _firestore.collection('users').doc(userId).update({
      'isVerified': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }







  // Get pending doctor verifications with user data (for admin)
  Stream<List<Map<String, dynamic>>> getPendingDoctorVerificationsWithUserData() {
    return _firestore
        .collection('document_verification')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc['userId']).get();
        if (userDoc.exists) {
          result.add({
            ...doc.data(),
            'id': doc.id,
            'userData': userDoc.data(),
          });
        }
      }
      return result;
    });
  }

  // Get doctor verifications by status with user data
  Stream<List<Map<String, dynamic>>> getDoctorsByVerificationStatusWithUserData(String status) {
    return _firestore
        .collection('document_verification')
        .where('status', isEqualTo: status)
        .orderBy('reviewedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc['userId']).get();
        if (userDoc.exists) {
          result.add({
            ...doc.data(),
            'id': doc.id,
            'userData': userDoc.data(),
          });
        }
      }
      return result;
    });
  }

  // Keep the old method for backward compatibility
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingDoctorVerifications() {
    return _firestore
        .collection('document_verification')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }






  // Add doctor review
  Future<void> addDoctorReview({
    required String doctorId,
    required String patientName,
    required double rating,
    String? comment,
    String? appointmentId,
  }) async {
    if (currentUser != null) {
      await _firestore.collection('reviews').add({
        'doctorId': doctorId,
        'patientId': currentUser!.uid,
        'patientName': patientName,
        'rating': rating,
        'comment': comment,
        'appointmentId': appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get doctor reviews
  Stream<QuerySnapshot<Map<String, dynamic>>> getDoctorReviews(String doctorId) {
    return _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }




 

  Stream<QuerySnapshot<Map<String, dynamic>>> getDoctorsByStatus(String status) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('isVerified', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get doctors by verification status from document_verification collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getDoctorsByVerificationStatus(String status) {
    return _firestore
        .collection('document_verification')
        .where('status', isEqualTo: status)
        .orderBy('reviewedAt', descending: true)
        .snapshots();
  }


  // Get unique patient count for a doctor
  Future<int> getUniquePatientCount(String doctorId) async {
    try {
      print('Fetching patient count for doctor: $doctorId');
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      print('Number of appointments found: ${querySnapshot.docs.length}');
      final patientIds = querySnapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .toSet();
      patientIds.removeWhere((id) => id == null);

      print('Unique patient IDs: $patientIds');
      print('Total unique patients: ${patientIds.length}');
      return patientIds.length;
    } catch (e) {
      print('Error loading patient count: $e');
      return 0;
    }
  }

  // Get completed appointments count for a doctor
  Future<int> getCompletedAppointmentsCount(String doctorId) async {
    try {
      print('Fetching completed appointments for doctor: $doctorId');
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'completed')
          .get();

      print('Number of completed appointments found: ${querySnapshot.docs.length}');
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error loading appointments count: $e');
      return 0;
    }
  }

  // Get total earnings from completed appointments for a doctor
  Future<double> getTotalEarnings(String doctorId) async {
    try {
      print('Fetching total earnings for doctor: $doctorId');
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: 'completed')
          .get();

      print('Number of completed appointments for earnings: ${querySnapshot.docs.length}');
      double totalEarnings = 0.0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final feesString = data['fees'] as String?;
        if (feesString != null && feesString.isNotEmpty) {
          // Remove ₹ symbol and any other non-numeric characters
          final cleanFees = feesString.replaceAll('₹', '').replaceAll(',', '').trim();
          try {
            final fees = double.parse(cleanFees);
            totalEarnings += fees;
            print('Added fees: $fees from appointment: ${doc.id}');
          } catch (e) {
            print('Error parsing fees: $feesString');
          }
        }
      }

      print('Total earnings calculated: ₹${totalEarnings.toStringAsFixed(2)}');
      return totalEarnings;
    } catch (e) {
      print('Error loading total earnings: $e');
      return 0.0;
    }
  }

  // Get reviews count for a doctor
  Future<int> getReviewsCount(String doctorId) async {
    try {
      print('Fetching reviews count for doctor: $doctorId');
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      print('Number of reviews found: ${querySnapshot.docs.length}');
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error loading reviews count: $e');
      return 0;
    }
  }



 // Check if consultation timings are set for the current doctor
  Future<bool> checkConsultationTimingsSet() async {
    if (currentUser == null) return false;
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) return false;
      
      // Check if set_time field exists and is true
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['set_time'] == true;
    } catch (e) {
      throw Exception('Error checking consultation timings: $e');
    }
  }

  // Save consultation timings for the doctor
  /// Returns a tuple of (success: bool, message: String)
  Future<Map<String, dynamic>> saveConsultationTimings({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required int consultationDuration,
    required int gapDuration,
  }) async {
    if (currentUser == null) {
      return {
        'success': false,
        'message': 'User not logged in. Please log in again.',
      };
    }

    try {
      
      // Format times to 24-hour format strings with leading zeros
      final startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      

      // First, try to find the existing document for this user
      final querySnapshot = await _firestore
          .collection('document_verification')
          .where('userId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      
      final timingData = {
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'consultationDuration': consultationDuration,
        'gapDuration': gapDuration,
        'updatedAt': FieldValue.serverTimestamp(),
        // 'type': 'consultation_timings', // Add type for easier querying
      };

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing document
        final docRef = querySnapshot.docs.first.reference;
        await docRef.update(timingData);
      } else {
        // Create new document if none exists
        await _firestore.collection('document_verification').add({
          'userId': currentUser!.uid,
          ...timingData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update user document to mark timings as set
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'set_time': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'success': true,
        'message': 'Consultation timings saved successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save consultation timings: ${e.toString()}',
      };
    }
  }

  // Helper method to parse timing data from document
  Map<String, dynamic> _parseTimingData(Map<String, dynamic> data) {
    try {
     
      
      // Check if required fields exist
      if (data['startTime'] == null || data['endTime'] == null) {
   
        throw Exception('Missing required timing fields');
      }
      
      // Parse time strings
      final startTimeStr = data['startTime'].toString().trim();
      final endTimeStr = data['endTime'].toString().trim();
      
    
      
      final startTimeParts = startTimeStr.split(':');
      final endTimeParts = endTimeStr.split(':');
      
      if (startTimeParts.length < 2 || endTimeParts.length < 2) {
        throw FormatException('Invalid time format');
      }
      
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endHour = int.parse(endTimeParts[0]);
      final endMinute = int.parse(endTimeParts[1]);
      
      // Parse durations with defaults
      final consultationDuration = data['consultationDuration'] != null
          ? (data['consultationDuration'] is int 
              ? data['consultationDuration'] as int
              : int.tryParse(data['consultationDuration'].toString()) ?? 30)
          : 30;
          
      final gapDuration = data['gapDuration'] != null
          ? (data['gapDuration'] is int 
              ? data['gapDuration'] as int
              : int.tryParse(data['gapDuration'].toString()) ?? 15)
          : 15;
      
      final result = {
        'startTime': TimeOfDay(hour: startHour, minute: startMinute),
        'endTime': TimeOfDay(hour: endHour, minute: endMinute),
        'consultationDuration': consultationDuration,
        'gapDuration': gapDuration,
      };
      
     
      return result;
      
    } catch (e) {
      debugPrint('Error parsing timing data: $e');
      // Fallback to default values
      return {
        'startTime': const TimeOfDay(hour: 9, minute: 0),
        'endTime': const TimeOfDay(hour: 17, minute: 0),
        'consultationDuration': 30,
        'gapDuration': 15,
      };
    }
  }

  // Get consultation timings for a doctor
  Future<Map<String, dynamic>?> getConsultationTimings() async {
    if (currentUser == null) return null;
    
    try {
      final userId = currentUser!.uid;
     
      
      // First try to get the most recently updated approved document

      try {
        final fallbackQuery = await _firestore
            .collection('document_verification')
            .where('userId', isEqualTo: userId)
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();
            
       
        
        if (fallbackQuery.docs.isNotEmpty) {
          final doc = fallbackQuery.docs.first;
          
          return _parseTimingData(doc.data());
        }
      } catch (e) {
        debugPrint('Error in fallback query: $e');
      }
      
      debugPrint('No consultation timings found for user $userId');
      return null;
      
    } catch (e) {
      debugPrint('Error getting consultation timings: $e');
      return null;
    }
  }








  Stream<QuerySnapshot<Map<String, dynamic>>> getDoctorAppointments() {
    if (currentUser != null) {
      return _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: currentUser!.uid) 
          .orderBy('dateTime', descending: true)
          .snapshots();
    }
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }














}
