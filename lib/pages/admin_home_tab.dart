import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/admin_service.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';

import 'admin_analytics_page.dart';


class AdminHomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToDoctors;
  final VoidCallback? onNavigateToPatients;
  final VoidCallback? onNavigateToReviews;

  const AdminHomeTab({
    super.key,
    this.onNavigateToDoctors,
    this.onNavigateToPatients,
    this.onNavigateToReviews,
  });

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final AdminService _adminService = AdminService();
  String _userName = 'Admin';
  String? _profileImageUrl;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final UserProfile? userData = await _firebaseService.getUserData();

      setState(() {
        _userName = userData?.name?.isNotEmpty == true ? userData!.name! : 'Admin';
        _profileImageUrl = userData?.photoURL;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _userName = 'Admin';
        _isLoading = false;
      });
      _animationController.forward();
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

            // System Overview Cards
            SliverToBoxAdapter(
              child: _buildSystemOverview(context, isDark),
            ),

            // Management Quick Actions
            SliverToBoxAdapter(
              child: _buildManagementActions(context, isDark),
            ),

            // Recent Activity
            // SliverToBoxAdapter(
            //   child: _buildRecentActivity(context, isDark),
            // ),

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
                  '$_userName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome to the admin dashboard',
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
        Icons.admin_panel_settings_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildSystemOverview(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
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
            childAspectRatio: 0.95,
            padding: EdgeInsets.zero,
            children: [
              _buildOverviewCard(
                context,
                icon: Icons.local_hospital_rounded,
                title: 'Total Doctors',
                value: StreamBuilder<int>(
                  stream: _adminService.getTotalDoctorsCount(),
                  builder: (context, snapshot) {
                    final theme = Theme.of(context);
                    if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Text(
                        'N/A',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else {
                      return Text(
                        '...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }
                  },
                ),
                color: AppTheme.primaryBlue,
              ),
              _buildOverviewCard(
                context,
                icon: Icons.people_rounded,
                title: 'Total Patients',
                  value: StreamBuilder<int>(
                  stream: _adminService.getTotalPatientCount(),
                  builder: (context, snapshot) {
                    final theme = Theme.of(context);
                    if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Text(
                        'N/A',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else {
                      return Text(
                        '...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }
                  },
                ),
                color: AppTheme.secondaryTeal,
              ),
              _buildOverviewCard(
                context,
                icon: Icons.star_rounded,
                title: 'Total Reviews',
                value: StreamBuilder<int>(
                  stream: _adminService.getTotalReviewsStream(),
                  builder: (context, snapshot) {
                    final theme = Theme.of(context);
                    if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningOrange,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Text(
                        'N/A',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else {
                      return Text(
                        '...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningOrange,
                        ),
                      );
                    }
                  },
                ),
                color: AppTheme.warningOrange,
              ),
              _buildOverviewCard(
                context,
                icon: Icons.calendar_today_rounded,
                title: 'Total Appointments',
                                value: StreamBuilder<int>(
                  stream: _adminService.getTotalAppointmentCount(),
                  builder: (context, snapshot) {
                    final theme = Theme.of(context);
                    if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Text(
                        'N/A',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    } else {
                      return Text(
                        '...',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    }
                  },
                ),
                color: AppTheme.successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget value,
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
          value,
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementActions(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 25, left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Management Actions',
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
                icon: Icons.local_hospital_rounded,
                title: 'Manage   Doctors',
                subtitle: 'Approve & verify',
                color: AppTheme.primaryBlue,
                onTap: () {
                  print('AdminHomeTab: Manage Doctors card tapped');
                  // Navigate to doctor management (DoctorListTab)
                  if (widget.onNavigateToDoctors != null) {
                    print('Using callback to navigate to doctors tab');
                    widget.onNavigateToDoctors!();
                  } else {
                    print('ERROR: No callback provided');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation not available')),
                    );
                  }
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.people_rounded,
                title: 'Manage Patients',
                subtitle: 'View & support',
                color: AppTheme.secondaryTeal,
                onTap: () {
                  print('AdminHomeTab: Manage Patients card tapped');
                  // Navigate to patient management (PatientListTab)
                  if (widget.onNavigateToPatients != null) {
                    print('Using callback to navigate to patients tab');
                    widget.onNavigateToPatients!();
                  } else {
                    print('ERROR: No callback provided');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation not available')),
                    );
                  }
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.star_rounded,
                title: 'Review Management',
                subtitle: 'Monitor & moderate',
                color: AppTheme.warningOrange,
                onTap: () {
                  print('AdminHomeTab: Review Management card tapped');
                  // Navigate to review management (AdminReviewTab)
                  if (widget.onNavigateToReviews != null) {
                    print('Using callback to navigate to reviews tab');
                    widget.onNavigateToReviews!();
                  } else {
                    print('ERROR: No callback provided');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation not available')),
                    );
                  }
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.analytics_rounded,
                title: 'System Analytics',
                subtitle: 'View reports',
                color: AppTheme.successGreen,
                onTap: () {
                  print('AdminHomeTab: System Analytics card tapped');
                  // Navigate to full-screen analytics page
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminAnalyticsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildRecentActivity(BuildContext context, bool isDark) {
  //   final theme = Theme.of(context);

  //   return Container(
  //     margin: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Recent Activity',
  //           style: theme.textTheme.titleLarge?.copyWith(
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Container(
  //           padding: const EdgeInsets.all(20),
  //           decoration: BoxDecoration(
  //             color: theme.colorScheme.surface,
  //             borderRadius: BorderRadius.circular(16),
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withOpacity(0.05),
  //                 blurRadius: 10,
  //                 offset: const Offset(0, 4),
  //               ),
  //             ],
  //           ),
  //           child: Column(
  //             children: [
  //               _buildActivityItem(
  //                 context,
  //                 icon: Icons.person_add_rounded,
  //                 title: 'New doctor registration',
  //                 subtitle: 'Dr. Sarah Johnson submitted verification documents',
  //                 time: '2 hours ago',
  //                 color: AppTheme.primaryBlue,
  //               ),
  //               const SizedBox(height: 16),
  //               _buildActivityItem(
  //                 context,
  //                 icon: Icons.star_rounded,
  //                 title: 'New review posted',
  //                 subtitle: '5-star review for Dr. Michael Chen',
  //                 time: '4 hours ago',
  //                 color: AppTheme.warningOrange,
  //               ),
  //               const SizedBox(height: 16),
  //               _buildActivityItem(
  //                 context,
  //                 icon: Icons.calendar_today_rounded,
  //                 title: 'Appointment completed',
  //                 subtitle: 'Patient appointment with Dr. Emily Davis',
  //                 time: '6 hours ago',
  //                 color: AppTheme.successGreen,
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildActivityItem(
  //   BuildContext context, {
  //   required IconData icon,
  //   required String title,
  //   required String subtitle,
  //   required String time,
  //   required Color color,
  // }) {
  //   final theme = Theme.of(context);

  //   return Row(
  //     children: [
  //       Container(
  //         padding: const EdgeInsets.all(10),
  //         decoration: BoxDecoration(
  //           color: color.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         child: Icon(
  //           icon,
  //           color: color,
  //           size: 20,
  //         ),
  //       ),
  //       const SizedBox(width: 16),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               title,
  //               style: theme.textTheme.titleSmall?.copyWith(
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 4),
  //             Text(
  //               subtitle,
  //               style: theme.textTheme.bodySmall?.copyWith(
  //                 color: theme.colorScheme.onSurface.withOpacity(0.6),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       Text(
  //         time,
  //         style: theme.textTheme.bodySmall?.copyWith(
  //           color: theme.colorScheme.onSurface.withOpacity(0.6),
  //         ),
  //       ),
  //     ],
  //   );
  // }

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
