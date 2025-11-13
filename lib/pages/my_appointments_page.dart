import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/rating_service.dart';
import '../services/firebase_service.dart';

// Time slot data class to track availability
class TimeSlot {
  final String time;
  final bool isAvailable;
  final bool isBooked;

  TimeSlot({
    required this.time,
    required this.isAvailable,
    required this.isBooked,
  });
}

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedFilter = 'all';
  final RatingService _ratingService = RatingService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final FirebaseService firebaseService = FirebaseService();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'My Appointments',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showFilterDialog(context),
            icon: Icon(
              Icons.filter_list_rounded,
              color: theme.colorScheme.primary,
            ),
            tooltip: 'Filter appointments',
          ),
          // PopupMenuButton<String>(
          //   icon: Icon(
          //     Icons.more_vert_rounded,
          //     color: theme.colorScheme.primary,
          //   ),
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   onSelected: (value) async {
          //     HapticFeedback.lightImpact();
          //     if (value == 'add_sample') {
          //       await _addSampleAppointments(firebaseService);
          //     } else if (value == 'clear_all') {
          //       await _clearAllAppointments(firebaseService);
          //     }
          //   },
          //   itemBuilder: (context) => [
          //     PopupMenuItem(
          //       value: 'add_sample',
          //       child: Row(
          //         children: [
          //           Icon(Icons.add_circle_rounded, color: AppTheme.successGreen),
          //           const SizedBox(width: 12),
          //           const Text('Add Sample Data'),
          //         ],
          //       ),
          //     ),
          //     PopupMenuItem(
          //       value: 'clear_all',
          //       child: Row(
          //         children: [
          //           Icon(Icons.clear_all_rounded, color: AppTheme.errorRed),
          //           const SizedBox(width: 12),
          //           const Text('Clear All'),
          //         ],
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(context),
            
            // Appointments list
            Expanded(
              child: StreamBuilder(
                stream: firebaseService.getAppointments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }
                  
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  
                  final allAppointments = snapshot.data?.docs ?? [];
                  final filteredAppointments = _filterAppointments(allAppointments);
                  
                  if (filteredAppointments.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return _buildAppointmentsList(filteredAppointments);
                },
              ),
            ),
          ],
      ),
    ),
    );
    
  }
    

  // Check if appointment is completed and can be rated
  bool _canRateAppointment(Map<String, dynamic> appointment) {
    final appointmentStatus = appointment['status'];

    print('Rating Check - Appointment Status: $appointmentStatus');

    if (appointmentStatus != 'completed') {
      print('Rating blocked: Appointment status is not completed');
      return false;
    }

    print('Rating allowed: Appointment is completed');
    return true;
  }

  // Show rating modal
  void _showRatingModal(BuildContext context, String appointmentId, Map<String, dynamic> appointment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RatingPage(
          appointmentId: appointmentId,
          appointment: appointment,
          ratingService: RatingService(),
          onRatingSubmitted: () {
            setState(() {
              // Refresh the UI to show updated rating status
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list_rounded},
      {'key': 'scheduled', 'label': 'Upcoming', 'icon': Icons.schedule_rounded},
      {'key': 'completed', 'label': 'Completed', 'icon': Icons.check_circle_rounded},
      {'key': 'cancelled', 'label': 'Cancelled', 'icon': Icons.cancel_rounded},
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 18,
                    color: isSelected 
                        ? Colors.white 
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label'] as String),
                ],
              ),
              onSelected: (selected) {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.outline,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading appointments...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_rounded,
            size: 64,
            color: AppTheme.errorRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedFilter == 'all' 
                ? 'No appointments yet'
                : 'No $_selectedFilter appointments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Book your first appointment from the Home tab'
                : 'Try selecting a different filter',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(List appointments) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointmentDoc = appointments[index];
        final appointment = appointmentDoc.data() as Map<String, dynamic>;
        final appointmentId = appointmentDoc.id;
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          child: _buildModernAppointmentCard(
            context, 
            appointment, 
            appointmentId,
            index,
          ),
        );
      },
    );
  }

  List _filterAppointments(List appointments) {
    if (_selectedFilter == 'all') return appointments;

    return appointments.where((doc) {
      final appointment = doc.data() as Map<String, dynamic>;
      final status = (appointment['status'] ?? 'scheduled').toString().toLowerCase();

      // Upcoming: include both scheduled and rescheduled (regardless of date)
      if (_selectedFilter == 'scheduled') {
        return status == 'scheduled' || status == 'rescheduled';
      }

      // Other filters remain exact match by status
      return status == _selectedFilter.toLowerCase();
    }).toList();
  }

  Widget _buildModernAppointmentCard(
    BuildContext context, 
    Map<String, dynamic> appointment, 
    String appointmentId,
    int index,
  ) {
    final theme = Theme.of(context);
    final status = appointment['status'] ?? 'scheduled';
    final statusInfo = _getStatusInfo(status);
    final canModify = status == 'scheduled' || status == 'rescheduled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: statusInfo['color'] as Color,
                width: 4,
              ),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardHeader(context, appointment, statusInfo, appointmentId),
                    const SizedBox(height: 16),
                    _buildCardDetails(appointment),
                    if (canModify) ...[
                      const SizedBox(height: 20),
                      _buildCardActions(context, appointmentId, appointment),
                    ] else if (_canRateAppointment(appointment)) ...[
                      // Rating handled via 3-dot menu in header
                    ],
                  ],
                ),
              ),

              // Status badge in bottom-right corner
              Positioned(
                bottom: 75,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo['color'] as Color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo['label'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    BuildContext context,
    Map<String, dynamic> appointment,
    Map<String, dynamic> statusInfo,
    String appointmentId,
  ) {
    final theme = Theme.of(context);
    final canRate = _canRateAppointment(appointment);

    return Stack(
      children: [
        // Main content row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (statusInfo['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                statusInfo['icon'] as IconData,
                color: statusInfo['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment['doctorName'] ?? 'Unknown Doctor',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment['reason'] ?? 'General consultation',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        // 3-dot menu overlay in top-right corner
        if (canRate)
          FutureBuilder<Map<String, dynamic>?>(
            future: _getExistingRating(appointmentId),
            builder: (context, snapshot) {
              final hasRating = snapshot.data?['exists'] == true;

              return Positioned(
                top: -10,
                right: -20,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.primary,
                    size: 30,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    HapticFeedback.lightImpact();
                    if (value == 'rate') {
                      _showRatingModal(context, appointmentId, appointment);
                    } else if (value == 'update_rating') {
                      _showUpdateRatingModal(context, appointmentId, appointment, snapshot.data!);
                    } else if (value == 'remove_rating') {
                      _showRemoveRatingDialog(context, appointmentId);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!hasRating) ...[
                      PopupMenuItem(
                        value: 'rate',
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppTheme.warningOrange),
                            const SizedBox(width: 12),
                            const Text('Rate Appointment'),
                          ],
                        ),
                      ),
                    ] else ...[
                      PopupMenuItem(
                        value: 'update_rating',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, color: AppTheme.primaryBlue),
                            const SizedBox(width: 12),
                            const Text('Update Rating'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove_rating',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, color: AppTheme.errorRed),
                            const SizedBox(width: 12),
                            const Text('Remove Rating'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCardDetails(Map<String, dynamic> appointment) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildDetailRow(
          icon: Icons.calendar_today_rounded,
          label: 'Appointment Date',
          value: _formatDateTime(appointment['dateTime']),
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          icon: Icons.access_time_rounded,
          label: 'Booked On',
          value: _formatDate(appointment['createdAt']),
          color: AppTheme.secondaryTeal,
        ),
      ],
    );
  }
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardActions(BuildContext context, String appointmentId, Map<String, dynamic> appointment) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showRescheduleDialog(context, appointmentId, appointment);
            },
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: const Text('Reschedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: BorderSide(color: AppTheme.primaryBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showCancelDialog(context, appointmentId, appointment);
            },
            icon: const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              side: BorderSide(color: AppTheme.errorRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }


  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return {
          'color': AppTheme.primaryBlue,
          'label': 'Scheduled',
          'icon': Icons.schedule_rounded,
        };
      case 'completed':
        return {
          'color': AppTheme.successGreen,
          'label': 'Completed',
          'icon': Icons.check_circle_rounded,
        };
      case 'cancelled':
        return {
          'color': AppTheme.errorRed,
          'label': 'Cancelled',
          'icon': Icons.cancel_rounded,
        };
      case 'rescheduled':
        return {
          'color': AppTheme.warningOrange,
          'label': 'Rescheduled',
          'icon': Icons.update_rounded,
        };
      default:
        return {
          'color': AppTheme.neutralGray,
          'label': 'Unknown',
          'icon': Icons.help_rounded,
        };
    }
  }

  // Future<void> _addSampleAppointments(FirebaseService firebaseService) async {
  //   try {
  //     await firebaseService.addSampleAppointments();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('Sample appointments added successfully'),
  //           backgroundColor: AppTheme.successGreen,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error adding appointments: $e'),
  //           backgroundColor: AppTheme.errorRed,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }

  // Future<void> _clearAllAppointments(FirebaseService firebaseService) async {
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(16),
  //       ),
  //       title: Row(
  //         children: [
  //           Icon(Icons.warning_rounded, color: AppTheme.warningOrange),
  //           const SizedBox(width: 12),
  //           const Text('Clear All Appointments'),
  //         ],
  //       ),
  //       content: const Text(
  //         'Are you sure you want to delete all appointments? This action cannot be undone.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(false),
  //           child: const Text('Cancel'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.of(context).pop(true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: AppTheme.errorRed,
  //             foregroundColor: Colors.white,
  //           ),
  //           child: const Text('Clear All'),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (confirmed == true) {
  //     try {
  //       await firebaseService.clearAllAppointments();
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: const Text('All appointments cleared'),
  //             backgroundColor: AppTheme.warningOrange,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),
  //         );
  //       }
  //     } catch (e) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Error clearing appointments: $e'),
  //             backgroundColor: AppTheme.errorRed,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Appointments',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildFilterChips(context),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getExistingRating(String appointmentId) async {
    try {
      final ratingService = RatingService();
      final ratingDoc = await ratingService.getRatingForAppointment(appointmentId);
      if (ratingDoc != null) {
        return {
          'exists': true,
          'rating': ratingDoc.data()!['rating'],
          'comment': ratingDoc.data()!['comment'],
          'documentId': ratingDoc.id,
        };
      }
      return {'exists': false};
    } catch (e) {
      print('Error checking rating status: $e');
      return {'exists': false};
    }
  }

  void _showUpdateRatingModal(BuildContext context, String appointmentId, Map<String, dynamic> appointment, Map<String, dynamic> existingRating) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UpdateRatingPage(
          appointmentId: appointmentId,
          appointment: appointment,
          existingRating: existingRating,
          onRatingUpdated: () {
            setState(() {
              // Refresh the UI to show updated rating status
            });
          },
        ),
      ),
    );
  }

  void _showRemoveRatingDialog(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Rating'),
        content: const Text('Are you sure you want to remove your rating for this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final ratingService = RatingService();
                await ratingService.deleteRating(appointmentId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rating removed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {
                    // Refresh UI
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error removing rating: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    
    try {
      if (date is DateTime) {
        return '${date.day}/${date.month}/${date.year}';
      }
      // Handle Firestore Timestamp
      return '${date.toDate().day}/${date.toDate().month}/${date.toDate().year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'Not specified';

    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else {
        // Handle Firestore Timestamp
        dateTime = date.toDate();
      }

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showRescheduleDialog(BuildContext context, String appointmentId, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => RescheduleDialog(
        appointmentId: appointmentId,
        currentAppointment: appointment,
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String appointmentId, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this appointment?'),
            const SizedBox(height: 12),
            Text(
              'Doctor: ${appointment['doctorName']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Date: ${_formatDateTime(appointment['dateTime'])}'),
            Text('Reason: ${appointment['reason']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final firebaseService = FirebaseService();
                await firebaseService.cancelAppointment(appointmentId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment cancelled successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error cancelling appointment: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );
  }
}

class RatingPage extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointment;
  final RatingService ratingService;
  final VoidCallback onRatingSubmitted;

  const RatingPage({
    super.key,
    required this.appointmentId,
    required this.appointment,
    required this.ratingService,
    required this.onRatingSubmitted,
  });

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Appointment'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Doctor: ${widget.appointment['doctorName']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text('Date: ${_formatDateTime(widget.appointment['dateTime'])}'),
            const SizedBox(height: 10),
            const Text(
              'How would you rate your experience?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // ⭐ Star Rating (no wrap, no overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5), // reduced space
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ), // smaller hitbox
                    padding: EdgeInsets.all(5), // remove internal padding
                    iconSize: 32, // smaller star size
                    onPressed: _isSubmitting
                        ? null
                        : () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            Text(
              _getRatingText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Additional Comments (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmitting || _rating == 0 ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Select a rating';
    }
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'Not specified';

    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else {
        dateTime = date.toDate();
      }

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.ratingService.submitRating(
        appointmentId: widget.appointmentId,
        doctorId: widget.appointment['doctorId'] ?? '',
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your rating!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        widget.onRatingSubmitted();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class RescheduleDialog extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> currentAppointment;

  const RescheduleDialog({
    super.key,
    required this.appointmentId,
    required this.currentAppointment,
  });

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  String? selectedDate;
  String? selectedTime;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current appointment date/time or future date
    try {
      final currentDateTime = widget.currentAppointment['dateTime'];
      if (currentDateTime != null) {
        DateTime dateTime;
        if (currentDateTime is DateTime) {
          dateTime = currentDateTime;
        } else {
          dateTime = currentDateTime.toDate();
        }

        // Check if the current appointment is in the future (at least 1 hour ahead)
        final now = DateTime.now();
        final minimumTime = now.add(const Duration(hours: 1));

        if (dateTime.isAfter(minimumTime)) {
          // Use current appointment time if it's valid - format as dd/mm/yyyy
          selectedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
          selectedTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        } else {
          // Set to tomorrow if current appointment is too soon
          final tomorrow = now.add(const Duration(days: 1));
          selectedDate = '${tomorrow.day}/${tomorrow.month}/${tomorrow.year}';
          selectedTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      // Set default to tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      selectedDate = '${tomorrow.day}/${tomorrow.month}/${tomorrow.year}';
      selectedTime = '10:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reschedule Appointment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Doctor: ${widget.currentAppointment['doctorName']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Reason: ${widget.currentAppointment['reason']}'),
            const SizedBox(height: 20),
            const Text(
              'Select new date and time:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Date Selection Dropdown
            DropdownButtonFormField<String>(
              value: selectedDate,
              decoration: const InputDecoration(
                labelText: 'Select Date',
                border: OutlineInputBorder(),
              ),
              items: _getNext3Days().map<DropdownMenuItem<String>>((date) {
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDate = value;
                  selectedTime = null; // Reset time when date changes
                });
              },
            ),
            const SizedBox(height: 16),

            // Time Selection Dropdown
            if (selectedDate != null)
              FutureBuilder<List<TimeSlot>>(
                future: _generateTimeSlotsForDoctor(selectedDate!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Loading time slots...',
                        border: OutlineInputBorder(),
                      ),
                      items: [],
                      onChanged: null,
                    );
                  }

                  if (snapshot.hasError) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Error loading slots',
                        border: OutlineInputBorder(),
                      ),
                      items: [],
                      onChanged: null,
                    );
                  }

                  final timeSlotObjects = snapshot.data ?? [TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)];

                  // Get available slots for validation
                  final availableSlots = timeSlotObjects.where((slot) => slot.isAvailable).toList();

                  // Ensure selectedTime matches an available slot or set to first available
                  if (availableSlots.isNotEmpty) {
                    if (selectedTime != null && !availableSlots.any((slot) => slot.time == selectedTime)) {
                      selectedTime = availableSlots[0].time;
                    } else if (selectedTime == null) {
                      selectedTime = availableSlots[0].time;
                    }
                  }

                  // If no available slots, show message instead of dropdown
                  if (availableSlots.isEmpty) {
                    return const Text(
                      'No available time slots for this date.',
                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: selectedTime!,
                    decoration: const InputDecoration(
                      labelText: 'Select Time',
                      border: OutlineInputBorder(),
                    ),
                    items: timeSlotObjects.map<DropdownMenuItem<String>>((timeSlot) {
                      return DropdownMenuItem<String>(
                        value: timeSlot.time,
                        child: Text(
                          timeSlot.time,
                          style: TextStyle(
                            color: timeSlot.isBooked ? Colors.red : (
                              timeSlot.isAvailable ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant
                            ),
                            fontWeight: timeSlot.isBooked ? FontWeight.w500 : null,
                            decoration: timeSlot.isBooked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        // Only allow selection if the slot is available
                        final selectedSlot = timeSlotObjects.firstWhere(
                          (slot) => slot.time == value,
                          orElse: () => TimeSlot(time: '', isAvailable: false, isBooked: true),
                        );
                        if (selectedSlot.isAvailable) {
                          setState(() {
                            selectedTime = value;
                          });
                        } else {
                          // Show feedback that the slot is not available
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sorry, $value is already booked. Please select another time slot.'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a time slot';
                      }
                      // Check if the selected time is actually available
                      final selectedSlot = timeSlotObjects.firstWhere(
                        (slot) => slot.time == value,
                        orElse: () => TimeSlot(time: '', isAvailable: false, isBooked: true),
                      );
                      if (!selectedSlot.isAvailable) {
                        return 'This time slot is no longer available';
                      }
                      return null;
                    },
                  );
                },
              ),

            // Show selected appointment preview
            if (selectedDate != null && selectedTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New appointment: $selectedDate at $selectedTime',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (selectedDate != null && selectedTime != null && !isLoading)
              ? _rescheduleAppointment
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Reschedule'),
        ),
      ],
    );
  }

  Future<void> _rescheduleAppointment() async {
    if (selectedDate == null || selectedTime == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      print('🔍 Rescheduling appointment:');
      print('   Selected date: $selectedDate');
      print('   Selected time: $selectedTime');

      // Parse selected date (format: "dd/mm/yyyy")
      final dateParts = selectedDate!.split('/');
      if (dateParts.length != 3) {
        throw Exception('Invalid date format. Expected dd/mm/yyyy');
      }

      print('   Date parts: $dateParts');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      print('   Parsed date: day=$day, month=$month, year=$year');

      // Parse selected time (format: "09:00 AM - 09:30 AM")
      // Extract just the start time part: "09:00 AM"
      final timeSlotParts = selectedTime!.split(' - ');
      if (timeSlotParts.isEmpty) {
        throw Exception('Invalid time format');
      }

      final startTimePart = timeSlotParts[0]; // "09:00 AM"
      final timeParts = startTimePart.split(':');
      if (timeParts.length < 2) {
        throw Exception('Invalid time format');
      }

      print('   Time slot parts: $timeSlotParts');
      print('   Start time part: $startTimePart');
      print('   Time parts: $timeParts');

      final hourMinute = timeParts[0]; // "09"
      final minuteSecond = timeParts[1]; // "00 AM"

      // Extract hour and minute, handling AM/PM
      int hour = int.parse(hourMinute);
      final minutePart = minuteSecond.substring(0, 2); // "00"
      final amPm = minuteSecond.substring(2).trim(); // "AM" or "PM"

      int minute = int.parse(minutePart);

      print('   Hour: $hour, Minute: $minute, AM/PM: $amPm');

      // Convert to 24-hour format
      if (amPm.toUpperCase() == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }

      print('   24-hour format: $hour:$minute');

      // Create new DateTime
      final newDateTime = DateTime(year, month, day, hour, minute);
      print('   New DateTime: $newDateTime');

      // Check if the new date/time is at least 1 hour in the future
      final now = DateTime.now();
      final minimumTime = now.add(const Duration(hours: 1));
      if (newDateTime.isBefore(minimumTime)) {
        throw Exception('Please select a future date and time.');
      }

      // Safety check: Verify the selected time is still available
      final doctorId = widget.currentAppointment['doctorId'];
      if (doctorId != null) {
        final doctorData = await _getDoctorData(doctorId);
        if (doctorData != null) {
          final timeSlots = await _generateTimeSlots(doctorData, selectedDate!);
          final selectedSlot = timeSlots.firstWhere(
            (slot) => slot.time == selectedTime,
            orElse: () => TimeSlot(time: '', isAvailable: false, isBooked: true),
          );

          if (!selectedSlot.isAvailable) {
            throw Exception('Sorry, $selectedTime is no longer available. Please select another time.');
          }
        }
      }

      final firebaseService = FirebaseService();
      await firebaseService.rescheduleAppointment(
        appointmentId: widget.appointmentId,
        newDateTime: newDateTime,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rescheduled successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error rescheduling appointment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rescheduling appointment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper methods for reschedule functionality
  int _parseTimeToMinutes(String time) {
    // Parse time in format "08:00" or "8:00 AM" to minutes since midnight
    try {
      if (time.contains('AM') || time.contains('PM')) {
        // Handle 12-hour format
        final parts = time.replaceAll(' ', '').split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1].substring(0, 2));

        if (time.contains('PM') && hour != 12) hour += 12;
        if (time.contains('AM') && hour == 12) hour = 0;

        return hour * 60 + minute;
      } else {
        // Handle 24-hour format (like "00:00", "02:00")
        final parts = time.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        return hour * 60 + minute;
      }
    } catch (e) {
      print('❌ Error parsing time "$time": $e');
      return 8 * 60; // Default to 8:00 AM
    }
  }

  String _formatTimeFromMinutes(int minutes) {
    int hour = minutes ~/ 60;
    int minute = minutes % 60;
    String period = 'AM';

    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) hour -= 12;
    }
    if (hour == 0) hour = 12;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Get next 3 days for date selection
  List<String> _getNext3Days() {
    final List<String> dates = [];
    final now = DateTime.now();
    for (int i = 0; i <= 2; i++) {  // Start from tomorrow (1 day ahead)
      final date = now.add(Duration(days: i));
      dates.add('${date.day}/${date.month}/${date.year}');
    }
    return dates;
  }

  // Get doctor's data from document_verification collection
  Future<Map<String, dynamic>?> _getDoctorData(String doctorId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('document_verification')
          .where('userId', isEqualTo: doctorId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting doctor data: $e');
      return null;
    }
  }

  // Generate time slots for doctor (simplified version for reschedule)
  Future<List<TimeSlot>> _generateTimeSlotsForDoctor(String selectedDate) async {
    try {
      final doctorId = widget.currentAppointment['doctorId'];
      if (doctorId == null) {
        return [TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)];
      }

      final doctorData = await _getDoctorData(doctorId);
      if (doctorData == null) {
        return [TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)];
      }

      return await _generateTimeSlots(doctorData, selectedDate);
    } catch (e) {
      print('❌ Error generating time slots for doctor: $e');
      return [TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)];
    }
  }

  // Generate available time slots for a doctor
  Future<List<TimeSlot>> _generateTimeSlots(Map<String, dynamic> doctorData, String selectedDate) async {
    // Extract time data with fallbacks
    final startTime = doctorData['startTime']?.toString().trim();
    final endTime = doctorData['endTime']?.toString().trim();
    final consultationDuration = doctorData['consultationDuration'];
    final gapDuration = doctorData['gapDuration'];

    // Check if we have valid time data
    if (startTime == null || startTime.isEmpty ||
        endTime == null || endTime.isEmpty ||
        consultationDuration == null) {

      print('⚠️ Missing time data, using default slots');
      return [
        TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)
      ];
    }

    try {
      // Parse times - these are in 24-hour format (00:00 to 02:00)
      final start = _parseTimeToMinutes(startTime);
      final end = _parseTimeToMinutes(endTime);
      final duration = consultationDuration is int ? consultationDuration :
          int.tryParse(consultationDuration.toString()) ?? 30;
      final gap = gapDuration != null ?
          (gapDuration is int ? gapDuration : int.tryParse(gapDuration.toString()) ?? 30) : 30;

      List<String> slots = [];
      int currentTime = start;

      // Check if selected date is today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool isToday = false;
      
      try {
        final dateParts = selectedDate.split('/');
        if (dateParts.length == 3) {
          final selectedDay = int.parse(dateParts[0]);
          final selectedMonth = int.parse(dateParts[1]);
          final selectedYear = int.parse(dateParts[2]);
          final selectedDateObj = DateTime(selectedYear, selectedMonth, selectedDay);
          isToday = selectedDateObj.isAtSameMomentAs(today);
        }
      } catch (e) {
        print('⚠️ Error parsing selected date: $e');
      }

      // Calculate minimum start time if today
      final currentMinutes = now.hour * 60 + now.minute;
      final minStartTime = currentMinutes + 60; // Current time + 1 hour

      // Generate slots from start time to end time
      while (currentTime + duration <= end) {
        // Skip slots that are before the minimum start time if today
        if (!isToday || currentTime >= minStartTime) {
          final startSlot = _formatTimeFromMinutes(currentTime);
          final endSlot = _formatTimeFromMinutes(currentTime + duration);
          slots.add('$startSlot - $endSlot');
        }
        currentTime += duration + gap; // Add duration + gap for next slot
      }

      // Get booked slots for the selected date
      final doctorId = widget.currentAppointment['doctorId'];
      final bookedSlots = doctorId != null ? await _getBookedTimeSlots(doctorId, selectedDate) : <String>{};

      // Create TimeSlot objects with availability status
      List<TimeSlot> timeSlots = slots.map((slot) {
        final isBooked = bookedSlots.contains(slot);
        return TimeSlot(
          time: slot,
          isAvailable: !isBooked,
          isBooked: isBooked,
        );
      }).toList();

      // Debug logging
      final availableCount = timeSlots.where((slot) => slot.isAvailable).length;
      final bookedCount = timeSlots.where((slot) => slot.isBooked).length;
      print('📊 Time slots for reschedule - ${doctorData['name'] ?? doctorId}:');
      print('   ✅ Available: $availableCount slots');
      print('   ❌ Booked: $bookedCount slots');
      if (bookedCount > 0) {
        print('   📅 Booked slots: ${timeSlots.where((slot) => slot.isBooked).map((slot) => slot.time).toList()}');
      }

      return timeSlots.isNotEmpty ? timeSlots : [TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)];

    } catch (e) {
      print('❌ Error generating time slots: $e');
      // Return default slots on error
      return [
        TimeSlot(time: 'No slots available', isAvailable: false, isBooked: false)
      ];
    }
  }

  // Check which time slots are already booked for a specific doctor on a specific date
  Future<Set<String>> _getBookedTimeSlots(String doctorId, String selectedDate) async {
    try {
      // Parse selected date (format: "dd/mm/yyyy")
      final dateParts = selectedDate.split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // Create start and end of the selected day
      final startOfDay = DateTime(year, month, day, 0, 0, 0);
      final endOfDay = DateTime(year, month, day, 23, 59, 59);

      print('🔍 Checking booked slots for doctor $doctorId on $selectedDate');
      print('   Date range: $startOfDay to $endOfDay');

      // Query appointments collection for this doctor on this date
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: ['scheduled', 'completed','rescheduled']) // Only active appointments
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThanOrEqualTo: endOfDay)
          .get();

      Set<String> bookedSlots = {};

      for (var doc in querySnapshot.docs) {
        final appointment = doc.data();
        final dateTime = appointment['dateTime'];

        if (dateTime != null) {
          // Convert Firestore Timestamp to DateTime
          DateTime appointmentDateTime;
          if (dateTime is Timestamp) {
            appointmentDateTime = dateTime.toDate();
          } else {
            appointmentDateTime = dateTime as DateTime;
          }

          // Get doctor's consultation duration
          final doctorData = await _getDoctorData(doctorId);
          final duration = doctorData?['consultationDuration'] is int
              ? doctorData!['consultationDuration'] as int
              : int.tryParse(doctorData?['consultationDuration'].toString() ?? '30') ?? 30;

          // Format time slot (e.g., "09:00 AM - 09:30 AM")
          final startTime = _formatTimeFromMinutes(appointmentDateTime.hour * 60 + appointmentDateTime.minute);
          final endTime = _formatTimeFromMinutes(appointmentDateTime.hour * 60 + appointmentDateTime.minute + duration);

          final slot = '$startTime - $endTime';
          bookedSlots.add(slot);

          print('   📅 Found booked appointment: $slot');
        }
      }

      print('✅ Total booked slots: ${bookedSlots.length}');
      return bookedSlots;

    } catch (e) {
      print('❌ Error checking booked slots: $e');
      return {};
    }
  }
}

class UpdateRatingPage extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> existingRating;
  final VoidCallback onRatingUpdated;

  const UpdateRatingPage({
    super.key,
    required this.appointmentId,
    required this.appointment,
    required this.existingRating,
    required this.onRatingUpdated,
  });

  @override
  State<UpdateRatingPage> createState() => _UpdateRatingPageState();
}

class _UpdateRatingPageState extends State<UpdateRatingPage> {
  late int _rating;
  late TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating['rating'] ?? 0;
    _commentController = TextEditingController(text: widget.existingRating['comment'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Your Rating'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Doctor: ${widget.appointment['doctorName']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text('Date: ${_formatDateTime(widget.appointment['dateTime'])}'),
            const SizedBox(height: 10),
            const Text(
              'Update your rating and comments:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // ⭐ Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.all(5),
                    iconSize: 32,
                    onPressed: _isSubmitting
                        ? null
                        : () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),
            Text(
              _getRatingText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Comments (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your updated experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmitting || _rating == 0 ? null : _updateRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Update Rating'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Select a rating';
    }
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'Not specified';

    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else {
        dateTime = date.toDate();
      }

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _updateRating() async {
    if (_rating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final ratingService = RatingService();
      await ratingService.updateRating(
        appointmentId: widget.appointmentId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        widget.onRatingUpdated();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rating: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
