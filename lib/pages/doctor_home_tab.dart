import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/doctor_service.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';
import 'appointment_page.dart';
import 'my_appointments_page.dart';
import '../widgets/doctor_verification_dialog.dart';
import '../widgets/consultation_timing_dialog.dart';
import 'home_page.dart';
import 'doctor_patients_page.dart';
import 'doctor_review_tab.dart';
import 'doctor_appointments_page.dart';


class DoctorHomeTab extends StatefulWidget {
  const DoctorHomeTab({super.key});

  @override
  State<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends State<DoctorHomeTab> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final DoctorService _doctorService = DoctorService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Appointment state variables
  int _todayAppointmentsCount = 0;
  int _completedAppointmentsCount = 0;
  String? _nextAppointmentTime;
  bool _isLoadingAppointments = true;
  String _userName = 'Doctor';
  String? _profileImageUrl;
  bool _isLoading = true;
  int _patientCount = 0;
  int _appointmentCount = 0;
  double _totalEarnings = 0.0;
  int _reviewsCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppointmentsData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConsultationTimings() async {
    try {
      // Only check if user is a doctor
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final role = userData['role'] as String?;
          final isVerified = userData['isVerified'] as String?;
          
          if (role == 'doctor' && isVerified == 'true') {
            final isTimingSet = await _doctorService.checkConsultationTimingsSet();
            if (!isTimingSet && mounted) {
              // Show consultation timing dialog
              await showDialog(
                context: context,
                barrierDismissible: false, // Prevent dismissing by tapping outside
                builder: (context) => ConsultationTimingDialog(
                  doctorService: _doctorService,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error checking consultation timings: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Check and set default verification status for doctors
      await _doctorService.checkAndSetDoctorVerification();

      final UserProfile? userData = await _firebaseService.getUserData();

      setState(() {
        _userName = userData?.name?.isNotEmpty == true ? userData!.name! : 'Doctor';
        _profileImageUrl = userData?.photoURL;
        _isLoading = false;
      });

      // Check if doctor needs verification
      await _checkDoctorVerification();

      _animationController.forward();

      await _loadPatientCount();
      await _loadAppointmentCount();
      await _loadTotalEarnings();
      await _loadReviewsCount();
      
      // Check if consultation timings are set
      await _checkConsultationTimings();
    } catch (e) {
      print('Error in _loadUserData: $e');
      setState(() {
        _userName = 'Doctor';
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  // Load today's appointments data
  Future<void> _loadAppointmentsData() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoadingAppointments = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get today's appointments
      final todayAppointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _auth.currentUser!.uid)
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThan: endOfDay)
          .orderBy('dateTime')
          .get();

      // Get next appointment
      final nextAppointment = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _auth.currentUser!.uid)
          .where('dateTime', isGreaterThan: now)
          .orderBy('dateTime')
          .limit(1)
          .get();

      // Get completed appointments count for today
      final completedAppointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: _auth.currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('dateTime', isLessThan: endOfDay)
          .get();

      setState(() {
        _todayAppointmentsCount = todayAppointments.docs.length;
        _completedAppointmentsCount = completedAppointments.docs.length;
        
        if (nextAppointment.docs.isNotEmpty) {
          final next = nextAppointment.docs.first;
          final dateTime = (next['dateTime'] as Timestamp).toDate();
          _nextAppointmentTime = DateFormat('h:mm a').format(dateTime);
        } else {
          _nextAppointmentTime = 'No upcoming appointments';
        }
        
        _isLoadingAppointments = false;
      });
    } catch (e) {
      print('Error loading appointments: $e');
      setState(() {
        _isLoadingAppointments = false;
      });
    }
  }

  Future<void> _showRejectionDialog(String reason) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text(
                  'Verification Rejected',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: Colors.red),
                ),
              ],
            ),
        
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your verification request was rejected for the following reason:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                reason.isNotEmpty ? reason : 'No reason provided',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Please review the reason and submit a new verification request.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reapply Now'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _showVerificationDialog();
    }
  }

  Future<String?> _getRejectionReason() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No current user found');
        return null;
      }
      
      print('Fetching rejection reason for user: ${currentUser.uid}');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('document_verification')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'rejected')
          .orderBy('submittedAt', descending: true) // Changed from updatedAt to submittedAt
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No rejected documents found for user');
        return null;
      }
      
      final docData = querySnapshot.docs.first.data();
      final reason = docData['rejectionReason'] as String?;
      
      print('Found document with data: $docData');
      print('Extracted rejection reason: $reason');
      
      return reason;
    } catch (e) {
      print('Error getting rejection reason: $e');
      if (e is FirebaseException) {
        print('Firebase error: ${e.code} - ${e.message}');
      }
      return null;
    }
  }

  Future<void> _checkDoctorVerification() async {
    try {
      final verificationStatus = await _doctorService.getDoctorVerificationStatus();
      final userData = await _firebaseService.getUserData();

      if (userData?.role == 'doctor') {
        if (verificationStatus == 'false') {
          if (mounted) {
            await _showVerificationDialog();
          }
        } else if (verificationStatus == 'rejected' && mounted) {
          final reason = await _getRejectionReason();
          await _showRejectionDialog(reason ?? 'No reason provided');
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
    }
  }

  Future<void> _loadPatientCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _patientCount = await _doctorService.getUniquePatientCount(currentUser.uid);
        setState(() {});
      } else {
        print('Current user is null');
      }
    } catch (e) {
      print('Error loading patient count: $e');
    }
  }

  Future<void> _loadAppointmentCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {

        _appointmentCount = await _doctorService.getCompletedAppointmentsCount(currentUser.uid);

        setState(() {});
      }
    } catch (e) {
      print('Error loading appointment count: $e');
    }
  }

  Future<void> _loadTotalEarnings() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {

        _totalEarnings = await _doctorService.getTotalEarnings(currentUser.uid);

        setState(() {});
      }
    } catch (e) {
      print('Error loading total earnings: $e');
    }
  }

  Future<void> _loadReviewsCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {

        _reviewsCount = await _doctorService.getReviewsCount(currentUser.uid);

        setState(() {});
      }
    } catch (e) {
      print('Error loading reviews count: $e');
    }
  }

  Future<void> _showVerificationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DoctorVerificationDialog(),
    );

    if (result == true) {
      // Verification was submitted successfully, check status again
      await _checkDoctorVerification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(
              child: _buildWelcomeHeader(context, isDark),
            ),

            // Today's Schedule Overview
            SliverToBoxAdapter(
              child: _buildTodaySchedule(context, isDark),
            ),

            // Dashboard Overview Cards
            SliverToBoxAdapter(
              child: _buildDashboardCards(context, isDark),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(context, isDark),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good Morning';
    IconData greetingIcon = Icons.wb_sunny_rounded;

    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 17) {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay_rounded;
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1F2E),
                  const Color(0xFF2D3748),
                ]
              : [
                  AppTheme.primaryBlue,
                  AppTheme.secondaryTeal,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.primaryBlue).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      greetingIcon,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dr. $_userName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to help your patients today?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          _buildProfileAvatar(isDark),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDark) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: _profileImageUrl != null && !_profileImageUrl!.startsWith('avatar_')
            ? Image.network(
                _profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    Color avatarColor = AppTheme.primaryBlue;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('avatar_')) {
      try {
        final colorValue = _profileImageUrl!.replaceFirst('avatar_', '');
        avatarColor = Color(int.parse(colorValue));
      } catch (e) {
        avatarColor = AppTheme.primaryBlue;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: avatarColor,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Schedule",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isLoadingAppointments
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              color: AppTheme.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_todayAppointmentsCount Appointments Today',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Text(
                                //   _nextAppointmentTime ?? 'No upcoming appointments',
                                //   style: theme.textTheme.bodyMedium?.copyWith(
                                //     color: theme.colorScheme.onSurface.withOpacity(0.6),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_todayAppointmentsCount > 0) ...[
                        LinearProgressIndicator(
                          value: _todayAppointmentsCount > 0
                              ? _completedAppointmentsCount / _todayAppointmentsCount
                              : 0,
                          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_completedAppointmentsCount of $_todayAppointmentsCount appointments completed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'No appointments scheduled for today',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDashboardCards(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height:16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            padding: EdgeInsets.zero,
            children: [
              _buildDashboardCard(
                context,
                icon: Icons.people_rounded,
                title: 'Total Patients',
                value: _patientCount.toString(),
                subtitle: '',
                color: AppTheme.primaryBlue,
              ),
              _buildDashboardCard(
                context,
                icon: Icons.calendar_today_rounded,
                title: 'Appointments',
                value: _appointmentCount.toString(),
                subtitle: '',
                color: AppTheme.secondaryTeal,
              ),
              _buildDashboardCard(
                context,
                icon: Icons.account_balance_wallet_rounded,
                title: 'Total Earning',
                value: '₹${_totalEarnings.toStringAsFixed(2)}',
                subtitle: '',
                color: AppTheme.successGreen,
              ),
              _buildDashboardCard(
                context,
                icon: Icons.star_rounded,
                title: 'Reviews',
                value: _reviewsCount.toString(),
                subtitle: '',
                color: AppTheme.warningOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 35, left: 20, right: 20, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            // padding: EdgeInsets.zero,
            children: [
              _buildActionCard(
                context,
                icon: Icons.calendar_today_rounded,
                title: "Today's Schedule",
                subtitle: 'View Patient Profile',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorPatientsPage()),
                  );
                  
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.assignment_rounded,
                title: 'My Appointments',
                subtitle: 'View & manage',
                color: AppTheme.secondaryTeal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorAppointmentsPage()),
                  );
                },
              ),

              _buildActionCard(
                context,
                icon: Icons.star_sharp,
                title: 'Rating Analytics',
                subtitle: 'View Ratings',
                color: AppTheme.warningOrange,
                onTap: () {
                 Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoctorReviewTab()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
