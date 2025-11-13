import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Submit rating for an appointment
  Future<void> submitRating({
    required String appointmentId,
    required String doctorId,
    required int rating,
    required String comment,
  }) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if rating already exists for this appointment
      final existingRating = await _getExistingRating(appointmentId);
      if (existingRating != null) {
        throw Exception('You have already rated this appointment');
      }

      // Add rating to ratings collection
      await _firestore.collection('ratings').add({
        'userId': currentUser!.uid,
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Rating submitted successfully');
    } catch (e) {
      print('Error submitting rating: $e');
      throw Exception('Failed to submit rating: $e');
    }
  }

  // Get rating for a specific appointment
  Future<DocumentSnapshot<Map<String, dynamic>>?> getRatingForAppointment(String appointmentId) async {
    if (currentUser == null) return null;

    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('userId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
    } catch (e) {
      print('Error getting rating: $e');
      return null;
    }
  }

  // Check if appointment already has a rating
  Future<bool> hasRating(String appointmentId) async {
    final rating = await getRatingForAppointment(appointmentId);
    return rating != null;
  }

  // Get existing rating document (internal method)
  Future<DocumentSnapshot<Map<String, dynamic>>?> _getExistingRating(String appointmentId) async {
    if (currentUser == null) return null;

    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('userId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
    } catch (e) {
      print('Error checking existing rating: $e');
      return null;
    }
  }

  // Get all ratings for a specific doctor
  Stream<QuerySnapshot<Map<String, dynamic>>> getDoctorRatings(String doctorId) {
    return _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get average rating for a doctor
  Future<double> getDoctorAverageRating(String doctorId) async {
    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 0.0;
      }

      double totalRating = 0.0;
      for (final doc in querySnapshot.docs) {
        totalRating += (doc.data()['rating'] ?? 0).toDouble();
      }

      return totalRating / querySnapshot.docs.length;
    } catch (e) {
      print('Error getting average rating: $e');
      return 0.0;
    }
  }

  // Update existing rating
  Future<void> updateRating({
    required String appointmentId,
    required int rating,
    required String comment,
  }) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final existingRating = await _getExistingRating(appointmentId);
      if (existingRating == null) {
        throw Exception('No existing rating found for this appointment');
      }

      await existingRating.reference.update({
        'rating': rating,
        'comment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Rating updated successfully');
    } catch (e) {
      print('Error updating rating: $e');
      throw Exception('Failed to update rating: $e');
    }
  }

  // Delete rating
  Future<void> deleteRating(String appointmentId) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final existingRating = await _getExistingRating(appointmentId);
      if (existingRating == null) {
        throw Exception('No rating found for this appointment');
      }

      await existingRating.reference.delete();
      print('Rating deleted successfully');
    } catch (e) {
      print('Error deleting rating: $e');
      throw Exception('Failed to delete rating: $e');
    }
  }
}
