import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../app_theme.dart';
import '../services/doctor_service.dart';

class DoctorReviewTab extends StatefulWidget {
  const DoctorReviewTab({Key? key}) : super(key: key);

  @override
  State<DoctorReviewTab> createState() => _DoctorReviewTabState();
}

class _DoctorReviewTabState extends State<DoctorReviewTab> {
  final FirebaseService _firebaseService = FirebaseService();
  final DoctorService _doctorService = DoctorService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _reviewsStream;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  void _loadReviews() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Get reviews for this doctor using FirebaseService
      _reviewsStream = _doctorService.getDoctorReviews(currentUser.uid);

      // Calculate average rating
      _calculateAverageRating();
    }
  }

  Future<void> _calculateAverageRating() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final reviewsSnapshot = await _doctorService.getDoctorReviews(currentUser.uid).first;

      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0.0;
        for (var doc in reviewsSnapshot.docs) {
          totalRating += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        }
        setState(() {
          _averageRating = totalRating / reviewsSnapshot.docs.length;
          _totalReviews = reviewsSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error calculating average rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header with average rating
          Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_totalReviews reviews',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Overall Rating',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Reviews list
          Expanded(
            child: _reviewsStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _reviewsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading reviews',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState(theme);
                      }

                      final reviews = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final reviewData = reviews[index].data() as Map<String, dynamic>;
                          return _buildReviewCard(reviewData, theme);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.reviews_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reviews from your patients will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> reviewData, ThemeData theme) {
    final rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = reviewData['comment'] as String?;
    final patientId = reviewData['userId'] as String?;
    final createdAt = reviewData['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: patientId == null
          ? _buildReviewCardContent(rating, 'Anonymous Patient', comment, createdAt, theme)
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildReviewCardContent(rating, 'Loading...', comment, createdAt, theme);
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return _buildReviewCardContent(rating, 'Anonymous Patient', comment, createdAt, theme);
                }
                final userData = snapshot.data!.data();
                final patientName = userData?['name'] as String? ?? 'Anonymous Patient';
                return _buildReviewCardContent(rating, patientName, comment, createdAt, theme);
              },
            ),
    );
  }

  Widget _buildReviewCardContent(double rating, String patientName, String? comment, Timestamp? createdAt, ThemeData theme) {
    return Container(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating and patient info
              Row(
                children: [
                  // Rating stars
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      );
                    }),
                  ),
                  const Spacer(),
                  // Patient name
                  Text(
                    patientName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Comment
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  comment,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),

          // Date in bottom right
          if (createdAt != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Text(
                _formatDate(createdAt.toDate()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }




  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
