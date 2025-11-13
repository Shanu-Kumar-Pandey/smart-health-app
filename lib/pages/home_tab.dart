import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/health_metrics_service.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';
import 'assessment_page.dart';
import 'appointment_page.dart';
import 'my_appointments_page.dart';
import 'medication_page.dart';
import 'health_tracking_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final HealthMetricsService _healthMetricsService = HealthMetricsService();
  String _userName = 'User';
  String _userEmail = '';
  String? _profileImageUrl;
  bool _isLoading = true;


  // Real health data from database
  String _heartRate = '72';
  String _bloodSugar = '95';
  String _weight = '72.5';
  String _bodyTemperature = '36.8';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // final List<HealthTip> _healthTips = const [
  //   HealthTip(
  //     icon: Icons.directions_walk_rounded,
  //     title: 'Stay Active',
  //     description: 'Take a 10-minute walk after meals to aid digestion and boost energy.',
  //     color: AppTheme.successGreen,
  //   ),
  //   HealthTip(
  //     icon: Icons.water_drop_rounded,
  //     title: 'Stay Hydrated',
  //     description: 'Drink water regularly throughout the day. Aim for 8-10 glasses daily.',
  //     color: AppTheme.secondaryTeal,
  //   ),
  //   HealthTip(
  //     icon: Icons.bedtime_rounded,
  //     title: 'Quality Sleep',
  //     description: 'Get 7-8 hours of quality sleep for better recovery and mental clarity.',
  //     color: AppTheme.primaryBlue,
  //   ),
  //   HealthTip(
  //     icon: Icons.restaurant_rounded,
  //     title: 'Balanced Diet',
  //     description: 'Include colorful fruits and vegetables in every meal for optimal nutrition.',
  //     color: AppTheme.warningOrange,
  //   ),
  // ];

  @override
  void initState() {
    super.initState();
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
    _loadHealthData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final UserProfile? userData = await _firebaseService.getUserData();
      final user = _firebaseService.currentUser;

      setState(() {
        _userName = userData?.name?.isNotEmpty == true ? userData!.name! : 'User';
        _userEmail = user?.email ?? '';
        _profileImageUrl = userData?.photoURL;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _loadHealthData() async {
    try {
      // Load latest health metrics from database
      final heartRateData = await _healthMetricsService.getLatestMetricRecord('Heart Rate');
      final bloodSugarData = await _healthMetricsService.getLatestMetricRecord('Blood Sugar');
      final weightData = await _healthMetricsService.getLatestMetricRecord('Weight');
      final tempData = await _healthMetricsService.getLatestMetricRecord('Body Temprature');

      setState(() {
        _heartRate = heartRateData?['value']?.toString() ?? '72';
        _bloodSugar = bloodSugarData?['value']?.toString() ?? '95';
        _weight = weightData?['value']?.toString() ?? '72.5';
        _bodyTemperature = tempData?['value']?.toString() ?? '36.8';
      });
    } catch (e) {
      // If loading fails, keep default values
      print('Error loading health data: $e');
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

            // Health Metrics Cards
            SliverToBoxAdapter(
              child: _buildHealthMetrics(context, isDark),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(context, isDark),
            ),

            // Health Tips
            // SliverToBoxAdapter(
            //   child: _buildHealthTips(context, isDark),
            // ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
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
                  _userName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How are you feeling today?',
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


  Widget _buildHealthMetrics(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 20),

      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,


        children: [
          Text(

            'Your Health Status',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
              Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.favorite_rounded,
                  title: 'Heart Rate',
                  value: '$_heartRate',
                  subtitle: 'bpm',
                  color: AppTheme.errorRed,
                  progress: double.parse(_heartRate.isNotEmpty ? _heartRate : '72') / 100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.water_drop_rounded,
                  title: 'Blood Sugar',
                  value: '$_bloodSugar',
                  subtitle: 'mg/dL',
                  color: AppTheme.primaryBlue,
                  progress: double.parse(_bloodSugar.isNotEmpty ? _bloodSugar : '95') / 150,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.monitor_weight_rounded,
                  title: 'Weight',
                  value: '$_weight',
                  subtitle: 'kg',
                  color: AppTheme.successGreen,
                  progress: double.parse(_weight.isNotEmpty ? _weight : '72.5') / 100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  icon: Icons.thermostat_rounded,
                  title: 'Temperature',
                  value: '$_bodyTemperature',
                  subtitle: '°C',
                  color: AppTheme.secondaryTeal,
                  progress: double.parse(_bodyTemperature.isNotEmpty ? _bodyTemperature : '36.8') / 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required double progress,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: color,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      // margin: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
      // margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            children: [
              _buildActionCard(
                context,
                icon: Icons.calendar_today_rounded,
                title: 'Book Appointment',
                subtitle: 'Schedule doctor',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppointmentPage()),
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
                    MaterialPageRoute(builder: (_) => const MyAppointmentsPage()),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.assessment_rounded,
                title: 'Health Assessment',
                subtitle: 'Check your health',
                color: AppTheme.successGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AssessmentPage()),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.medication_rounded,
                title: 'Medications',
                subtitle: 'Track prescriptions',
                color: AppTheme.warningOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicationPage()),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.monitor_heart_rounded,
                title: 'Health Tracking',
                subtitle: 'Monitor vital signs',
                color: AppTheme.errorRed,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HealthTrackingPage()),
                  );
                },
              ),
              // _buildActionCard(
              //   context,
              //   icon: Icons.emergency_rounded,
              //   title: 'Emergency',
              //   subtitle: 'Quick SOS access',
              //   color: AppTheme.neutralGray,
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (_) => const EmergencyContactsPage()),
              //     );
              //   },
              // ),
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

  // Widget _buildHealthTips(BuildContext context, bool isDark) {
  //   final theme = Theme.of(context);

  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 20),

  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Health Tips',
  //           style: theme.textTheme.titleLarge?.copyWith(
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         SizedBox(
  //           height: 140,
  //           child: PageView.builder(
  //             controller: PageController(viewportFraction: 0.85),
  //             itemCount: _healthTips.length,
  //             itemBuilder: (context, index) {
  //               final tip = _healthTips[index];
  //               return Container(
  //                 margin: const EdgeInsets.only(right: 16),
  //                 padding: const EdgeInsets.all(20),
  //                 decoration: BoxDecoration(
  //                   gradient: LinearGradient(
  //                     begin: Alignment.topLeft,
  //                     end: Alignment.bottomRight,
  //                     colors: [
  //                       tip.color.withOpacity(0.1),
  //                       tip.color.withOpacity(0.05),
  //                     ],
  //                   ),
  //                   borderRadius: BorderRadius.circular(16),
  //                   border: Border.all(
  //                     color: tip.color.withOpacity(0.2),
  //                     width: 1,
  //                   ),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Row(
  //                       children: [
  //                         Icon(
  //                           tip.icon,
  //                           color: tip.color,
  //                           size: 24,
  //                         ),
  //                         const SizedBox(width: 12),
  //                         Expanded(
  //                           child: Text(
  //                             tip.title,
  //                             style: theme.textTheme.titleMedium?.copyWith(
  //                               fontWeight: FontWeight.bold,
  //                               color: tip.color,
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                     const SizedBox(height: 12),
  //                     Text(
  //                       tip.description,
  //                       style: theme.textTheme.bodyMedium?.copyWith(
  //                         color: theme.colorScheme.onSurface.withOpacity(0.8),
  //                         height: 1.4,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

class HealthTip {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const HealthTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

