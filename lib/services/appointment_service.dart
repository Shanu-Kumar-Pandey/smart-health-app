import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class AppointmentService {
  final FirebaseService _firebaseService = FirebaseService();

  /// Get count of scheduled appointments for current user
  Future<int> getScheduledAppointmentsCount() async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return 0;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          // .where('status', isEqualTo: 'scheduled')
          .where('status', whereIn: ['scheduled', 'rescheduled'])
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error fetching scheduled appointments count: $e');
      return 0;
    }
  }

  /// Get all appointments for current user
  Future<List<Map<String, dynamic>>> getUserAppointments() async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('dateTime', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching user appointments: $e');
      return [];
    }
  }

  /// Get appointments by status for current user
  Future<List<Map<String, dynamic>>> getAppointmentsByStatus(String status) async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error fetching appointments by status: $e');
      return [];
    }
  }

  /// Get upcoming appointments (scheduled and within next 30 days)
  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return [];

      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'scheduled')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysFromNow))
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error fetching upcoming appointments: $e');
      return [];
    }
  }

  /// Create new appointment
  Future<String?> createAppointment({
    required String doctorName,
    required String specialty,
    required DateTime date,
    required String time,
    required String notes,
    String status = 'scheduled',
  }) async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return null;

      final appointmentData = {
        'userId': userId,
        'doctorName': doctorName,
        'specialty': specialty,
        'dateTime': Timestamp.fromDate(date),
        'time': time,
        'notes': notes,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      return docRef.id;
    } catch (e) {
      print('Error creating appointment: $e');
      return null;
    }
  }

  /// Update appointment status
  Future<bool> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }

  /// Get all appointments for a specific user (admin function)
  Future<List<Map<String, dynamic>>> getUserAppointmentsById(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('dateTime', descending: true)
          .get();

      final appointments = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      return appointments;
    } catch (e) {
      return [];
    }
  }









}
