import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class PaymentService {
  final FirebaseService _firebaseService = FirebaseService();

  /// Get all payment methods for current user
  Future<List<Map<String, dynamic>>> getUserPaymentMethods() async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      print('=== PaymentService: getUserPaymentMethods ===');
      print('Current user ID: $userId');

      if (userId == null) {
        print('ERROR: No current user found');
        return [];
      }

      print('Querying payment_methods collection for userId: $userId');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('payment_methods')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Query completed. Found ${querySnapshot.docs.length} documents');
      print('Document IDs: ${querySnapshot.docs.map((doc) => doc.id).toList()}');

      final paymentMethods = querySnapshot.docs.map((doc) {
        final data = doc.data();
        print('Document ${doc.id}: $data');
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      print('Returning ${paymentMethods.length} payment methods');
      return paymentMethods;
    } catch (e) {
      print('ERROR in getUserPaymentMethods: $e');
      return [];
    }
  }

  /// Add a new payment method for current user
  Future<bool> addPaymentMethod(Map<String, dynamic> paymentData) async {
    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) return false;

      await FirebaseFirestore.instance.collection('payment_methods').add({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        ...paymentData,
      });

      return true;
    } catch (e) {
      print('Error adding payment method: $e');
      return false;
    }
  }

  /// Update an existing payment method
  Future<bool> updatePaymentMethod(String paymentMethodId, Map<String, dynamic> paymentData) async {
    try {
      await FirebaseFirestore.instance.collection('payment_methods').doc(paymentMethodId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        ...paymentData,
      });

      return true;
    } catch (e) {
      print('Error updating payment method: $e');
      return false;
    }
  }

  /// Delete a payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    try {
      await FirebaseFirestore.instance.collection('payment_methods').doc(paymentMethodId).delete();
      return true;
    } catch (e) {
      print('Error deleting payment method: $e');
      return false;
    }
  }

  /// Get payment method by ID
  Future<Map<String, dynamic>?> getPaymentMethodById(String paymentMethodId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('payment_methods').doc(paymentMethodId).get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }

      return null;
    } catch (e) {
      print('Error fetching payment method by ID: $e');
      return null;
    }
  }
}
