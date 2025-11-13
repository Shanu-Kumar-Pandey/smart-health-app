import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';

class AdminReviewTab extends StatefulWidget {
  const AdminReviewTab({super.key});

  @override
  State<AdminReviewTab> createState() => _AdminReviewTabState();
}

class _AdminReviewTabState extends State<AdminReviewTab> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', '5 Stars', '4 Stars', '3 Stars', '2 Stars', '1 Star'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryBlue,
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
        tabs: const [
          Tab(
            text: 'All Reviews',
            icon: Icon(Icons.reviews_rounded),
          ),
          Tab(
            text: 'Analytics',
            icon: Icon(Icons.analytics_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReviewsTab(theme),
          _buildAnalyticsTab(theme),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme) {
    return Column(
      children: [
        // Filter header
        Container(
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
              // Filter dropdown
              Row(
                children: [
                  Text(
                    'Filter:',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFilter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _filterOptions.map((filter) {
                        return DropdownMenuItem(
                          value: filter,
                          child: Text(filter),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCardWithStream(
                      theme,
                      'Total Reviews',
                      _getTotalReviewsStream(),
                      Icons.reviews_rounded,
                      AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCardWithStream(
                      theme,
                      'Avg Rating',
                      _getAverageRatingStream(),
                      Icons.star_rounded,
                      AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Reviews list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getFilteredReviewsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorState(theme, 'Error loading reviews');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reviewDocs = snapshot.data!.docs;

              if (reviewDocs.isEmpty) {
                return _buildEmptyState(
                  theme,
                  'No reviews found',
                  'No reviews match the current filter',
                  Icons.reviews_outlined,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Added 80px bottom padding
                itemCount: reviewDocs.length,
                itemBuilder: (context, index) {
                  final reviewDoc = reviewDocs[index];
                  final reviewData = reviewDoc.data() as Map<String, dynamic>;
                  return _buildReviewCard(reviewDoc, reviewData, theme);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Analytics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Rating distribution
          _buildRatingDistribution(theme),

          const SizedBox(height: 24),

          // Top rated doctors
          _buildTopRatedDoctors(theme),

          const SizedBox(height: 24),

          // Recent activity
          // _buildRecentActivity(theme),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getFilteredReviewsStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('ratings');

    if (_selectedFilter != 'All') {
      final rating = int.parse(_selectedFilter.split(' ')[0]);
      query = query.where('rating', isEqualTo: rating.toDouble());
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  Future<List<dynamic>> _fetchUserData(String userId, String doctorId) async {
    final futures = <Future<DocumentSnapshot?>>[];

    if (userId.isNotEmpty) {
      futures.add(FirebaseFirestore.instance.collection('users').doc(userId).get());
    } else {
      futures.add(Future.value(null));
    }

    if (doctorId.isNotEmpty) {
      futures.add(FirebaseFirestore.instance.collection('users').doc(doctorId).get());
    } else {
      futures.add(Future.value(null));
    }

    final results = await Future.wait(futures);
    return results.map((doc) => doc?.data()).toList();
  }

  String _getDisplayName(Map<String, dynamic>? userData, String defaultName) {
    if (userData == null) return defaultName;

    final name = userData['name'] as String?;
    final role = userData['role'] as String?;

    if (name != null && name.isNotEmpty) {
      return name;
    }

    // Fallback to role-based name if no name is available
    if (role == 'patient') {
      return 'Patient User';
    } else if (role == 'doctor') {
      return 'Doctor User';
    }

    return defaultName;
  }


  Widget _buildStatCardWithStream(ThemeData theme, String title, Stream<String> valueStream, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          StreamBuilder<String>(
            stream: valueStream,
            builder: (context, snapshot) {
              final value = snapshot.data ?? 'Loading...';
              return Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Stream<String> _getTotalReviewsStream() {
    return FirebaseFirestore.instance
        .collection('ratings')
        .snapshots()
        .map((snapshot) => snapshot.docs.length.toString());
  }

  Stream<String> _getAverageRatingStream() {
    return FirebaseFirestore.instance
        .collection('ratings')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return '0.0';

          double totalRating = 0.0;
          for (var doc in snapshot.docs) {
            final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
            totalRating += rating;
          }

          final average = totalRating / snapshot.docs.length;
          return average.toStringAsFixed(1);
        });
  }

  Widget _buildReviewCard(QueryDocumentSnapshot reviewDoc, Map<String, dynamic> reviewData, ThemeData theme) {
    final rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = reviewData['comment'] as String?;
    final userId = reviewData['userId'] as String? ?? '';
    final doctorId = reviewData['doctorId'] as String? ?? '';
    final createdAt = reviewData['createdAt'] as Timestamp?;

    return FutureBuilder<List<dynamic>>(
      future: _fetchUserData(userId, doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Added 80px bottom padding
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Added 80px bottom padding
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                'Error loading user data',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          );
        }

        final userData = snapshot.data?[0] as Map<String, dynamic>?;
        final doctorData = snapshot.data?[1] as Map<String, dynamic>?;

        final patientName = _getDisplayName(userData, 'Anonymous Patient');
        final doctorName = _getDisplayName(doctorData, 'Unknown Doctor');

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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with rating and doctor info
              Row(
                children: [
                  // Rating stars
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: AppTheme.warningOrange,
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rating.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                  const Spacer(),
                  // Doctor name
                  Text(
                    doctorName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Patient name and date
              Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    patientName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt.toDate()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showReviewDetails(reviewDoc, reviewData, patientName, doctorName),
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removeReview(reviewDoc),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(color: AppTheme.errorRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        
      },
    );
  }

  Widget _buildRatingDistribution(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getRatingDistributionStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading rating data',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              }

              final ratingData = snapshot.data ?? [];

              if (ratingData.isEmpty) {
                return Center(
                  child: Text(
                    'No ratings yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }

              return Column(
                children: ratingData.map((data) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${data['rating']} Stars',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (data['percentage'] as double) / 100,
                          backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningOrange),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${data['count']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getRatingDistributionStream() {
    return FirebaseFirestore.instance
        .collection('ratings')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];

          // Count ratings by star value
          final ratingCounts = <int, int>{};
          int totalReviews = snapshot.docs.length;

          for (var doc in snapshot.docs) {
            final rating = (doc.data()['rating'] as num?)?.toInt() ?? 0;
            if (rating >= 1 && rating <= 5) {
              ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
            }
          }

          // Convert to display format
          final ratingData = <Map<String, dynamic>>[];
          for (int rating = 5; rating >= 1; rating--) {
            final count = ratingCounts[rating] ?? 0;
            final percentage = totalReviews > 0 ? (count / totalReviews * 100).round() : 0;

            ratingData.add({
              'rating': rating,
              'count': count,
              'percentage': percentage.toDouble(),
            });
          }

          return ratingData;
        });
  }

  Widget _buildTopRatedDoctors(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Rated Doctors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getTopRatedDoctors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading top doctors',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              }

              final doctors = snapshot.data ?? [];

              if (doctors.isEmpty) {
                return Center(
                  child: Text(
                    'No reviews yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                );
              }

              return Column(
                children: doctors.take(3).map((doctorData) {
                  final averageRating = doctorData['averageRating'] as double? ?? 0.0;
                  final reviewCount = doctorData['reviewCount'] as int? ?? 0;
                  final doctorId = doctorData['doctorId'] as String? ?? '';

                  return FutureBuilder<DocumentSnapshot>(
                    future: doctorId.isNotEmpty
                        ? FirebaseFirestore.instance.collection('users').doc(doctorId).get()
                        : null,
                    builder: (context, doctorSnapshot) {
                      final doctorData = doctorSnapshot.data?.data() as Map<String, dynamic>?;
                      final doctorName = doctorData?['name'] as String? ?? 'Unknown Doctor';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildTopDoctorItem(theme, doctorName, averageRating, reviewCount),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getTopRatedDoctors() async {
    final reviewsSnapshot = await FirebaseFirestore.instance.collection('ratings').get();
    final doctorStats = <String, Map<String, dynamic>>{};

    // Calculate statistics for each doctor
    for (var reviewDoc in reviewsSnapshot.docs) {
      final reviewData = reviewDoc.data() as Map<String, dynamic>;
      final doctorId = reviewData['doctorId'] as String?;

      if (doctorId != null && doctorId.isNotEmpty) {
        final rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;

        if (doctorStats.containsKey(doctorId)) {
          final stats = doctorStats[doctorId]!;
          stats['totalRating'] = (stats['totalRating'] as double) + rating;
          stats['count'] = (stats['count'] as int) + 1;
        } else {
          doctorStats[doctorId] = {
            'doctorId': doctorId,
            'totalRating': rating,
            'count': 1,
          };
        }
      }
    }

    // Convert to list and sort by average rating
    final doctorList = doctorStats.values.map((stats) {
      final averageRating = (stats['totalRating'] as double) / (stats['count'] as int);
      return {
        ...stats,
        'averageRating': averageRating,
        'reviewCount': stats['count'],
      };
    }).toList();

    doctorList.sort((a, b) => (b['averageRating'] as double).compareTo(a['averageRating'] as double));

    return doctorList;
  }

  Widget _buildTopDoctorItem(ThemeData theme, String name, double rating, int reviews) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.person_rounded,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$rating ($reviews reviews)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Added 80px bottom padding
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80), // Added 80px bottom padding
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDetails(QueryDocumentSnapshot reviewDoc, Map<String, dynamic> reviewData, String patientName, String doctorName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Rating', reviewData['rating']?.toString() ?? 'N/A'),
              _buildDetailItem('Patient', patientName),
              _buildDetailItem('Doctor', doctorName),

              _buildDetailItem('Comment', reviewData['comment'] ?? 'No comment'),
              _buildDetailItem('Created', _formatDate(reviewData['createdAt']?.toDate())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _removeReview(QueryDocumentSnapshot reviewDoc) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Review'),
          content: const Text('Are you sure you want to remove this review? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete the review from Firestore using the document ID
      await FirebaseFirestore.instance
          .collection('ratings')
          .doc(reviewDoc.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing review: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';

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
