import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'doctor_patients_page.dart';
import '../services/notification_center.dart';
import '../services/firebase_service.dart';
import '../app_theme.dart';

import 'home_tab.dart';
import 'appointment_page.dart';
import 'vault_tab.dart';
import 'person_tab.dart';
import 'reminder_tab.dart';
import 'doctor_review_tab.dart';
import 'doctor_home_tab.dart';
import 'admin_home_tab.dart';
import 'doctor_list_tab.dart';
import 'patient_list_tab.dart';
import 'admin_review_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  // Expose a global key to control the tab programmatically
  static final GlobalKey<_HomePageState> homeKey = GlobalKey<_HomePageState>();

  // Helper to navigate to Reminders tab
  static void goToRemindersTab() {
    final st = homeKey.currentState;
    st?.goToRemindersTab();
  }

  // Helper to navigate to Doctors tab
  static void goToDoctorsTab() {
    final st = homeKey.currentState;
    st?.goToDoctorsTab();
  }

  // Helper to navigate to Patients tab
  static void goToPatientsTab() {
    final st = homeKey.currentState;
    st?.goToPatientsTab();
  }

  // Helper to navigate to Reviews tab
  static void goToReviewsTab() {
    final st = homeKey.currentState;
    st?.goToReviewsTab();
  }


  // Helper to open notifications panel
  static void openNotificationsPanel() {
    final st = homeKey.currentState;
    st?.openNotificationsPanel();
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseService _firebaseService = FirebaseService();

  // Role-based state
  String? _userRole;
  late List<Widget> _pages;
  late List<NavigationItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final userProfile = await _firebaseService.getUserData();
      if (userProfile != null && userProfile.role != null) {
        setState(() {
          _userRole = userProfile.role;
          _setupRoleBasedNavigation();
        });
      } else {
        // Default to patient if no role is set
        setState(() {
          _userRole = 'patient';
          _setupRoleBasedNavigation();
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
      // Default to patient on error
      setState(() {
        _userRole = 'patient';
        _setupRoleBasedNavigation();
      });
    }
  }

  void _setupRoleBasedNavigation() {
    // print('_setupRoleBasedNavigation called for role: $_userRole');
    if (_userRole == 'admin') {
      // print('Setting up admin navigation');
      // Admin navigation
      _pages = [
        AdminHomeTab( // Admin-specific home tab
          onNavigateToDoctors: () => goToDoctorsTab(),
          onNavigateToPatients: () => goToPatientsTab(),
          onNavigateToReviews: () => goToReviewsTab(),
        ),
        DoctorListTab(), // Manage doctors tab
        PatientListTab(), // Manage patients tab
        AdminReviewTab(), // Manage all reviews tab
        PersonTab(), // Profile tab
      ];

      _navigationItems = [
        NavigationItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          activeIcon: Icons.dashboard,
        ),
        NavigationItem(
          icon: Icons.local_hospital_rounded,
          label: 'Doctors',
          activeIcon: Icons.local_hospital,
        ),
        NavigationItem(
          icon: Icons.people_rounded,
          label: 'Patients',
          activeIcon: Icons.people,
        ),
        NavigationItem(
          icon: Icons.star_rounded,
          label: 'Reviews',
          activeIcon: Icons.star,
        ),
        NavigationItem(
          icon: Icons.person_rounded,
          label: 'Profile',
          activeIcon: Icons.person,
        ),
      ];
    } else if (_userRole == 'doctor') {
      // Doctor navigation
      _pages = [
        DoctorHomeTab(), // Doctor-specific home tab
        DoctorPatientsPage(), // Show doctor's patients
        DoctorReviewTab(), // Reviews instead of Records
        ReminderTab(), // Same reminder tab
        PersonTab(), // Profile tab with different content
      ];

      _navigationItems = [
        NavigationItem(
          icon: Icons.home_rounded,
          label: 'Home',
          activeIcon: Icons.home,
        ),
        NavigationItem(
          icon: Icons.search_rounded,
          label: 'Search',
          activeIcon: Icons.search,
        ),
        NavigationItem(
          icon: Icons.star_rounded,
          label: 'Reviews',
          activeIcon: Icons.star,
        ),
        NavigationItem(
          icon: Icons.calendar_today_rounded,
          label: 'Reminder',
          activeIcon: Icons.calendar_today,
        ),
        NavigationItem(
          icon: Icons.person_rounded,
          label: 'Profile',
          activeIcon: Icons.person,
        ),
      ];
    } else {
      // Patient navigation (default)
      _pages = [
        HomeTab(),
        AppointmentPage(),
        VaultTab(),
        ReminderTab(),
        PersonTab(),
      ];

      _navigationItems = [
        NavigationItem(
          icon: Icons.home_rounded,
          label: 'Home',
          activeIcon: Icons.home,
        ),
        NavigationItem(
          icon: Icons.search_rounded,
          label: 'Search',
          activeIcon: Icons.search,
        ),
        NavigationItem(
          icon: Icons.folder_rounded,
          label: 'Records',
          activeIcon: Icons.folder,
        ),
        NavigationItem(
          icon: Icons.calendar_today_rounded,
          label: 'Reminder',
          activeIcon: Icons.calendar_today,
        ),
        NavigationItem(
          icon: Icons.person_rounded,
          label: 'Profile',
          activeIcon: Icons.person,
        ),
      ];
    }
    // print('Navigation setup complete');
  }

  // Programmatically switch to the Reminders tab (index 3 for both roles)
  void goToRemindersTab() {
    _onItemTapped(3);
  }

  // Programmatically switch to the Doctors tab (index 1 for admin users)
  void goToDoctorsTab() {
    _onItemTapped(1);
  }

  // Programmatically switch to the Patients tab (index 2 for admin users)
  void goToPatientsTab() {
    _onItemTapped(2);
  }

  // Programmatically switch to the Reviews tab (index 3 for admin users)
  void goToReviewsTab() {
    _onItemTapped(3);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onItemTapped(int index) async {
    

    // Check if biometric gate is needed based on role and tab
    if (_shouldRequireBiometric(index)) {
      final allowed = await _handleRecordsBiometricGate();
      if (!allowed) {
        // Stay on current tab
        return;
      }
    }

    if (_currentIndex != index) {
      
      setState(() {
        _currentIndex = index;
      });

      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  bool _shouldRequireBiometric(int index) {
    // For patients: Records tab (index 2) requires biometric
    // For doctors: No tab requires biometric (they have Reviews instead of Records)
    return _userRole == 'patient' && index == 2;
  }
  // Returns true if user is allowed to open Records tab
  Future<bool> _handleRecordsBiometricGate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No user -> allow but warn
        _showSnack('Sign in to secure records', error: false);
        return true;
      }

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await docRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final biometricEnabled = (data['biometric'] as bool?) ?? false;

      if (!biometricEnabled) {
        return true;
      }

      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final methods = await _localAuth.getAvailableBiometrics();
      if (!(isSupported && canCheck) || methods.isEmpty) {
        // Enabled but device can't do biometrics -> allow (can't enforce)
        return true;
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your health records',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!didAuth) {
        _showSnack('Biometric authentication failed', error: true);
        return false;
      }

      return true;
    } on PlatformException catch (e) {
      _showSnack(e.message ?? 'Biometric not available', error: false);
      return true; // Don't block if platform throws non-fatal error
    } catch (e) {
      _showSnack('Biometric error: $e', error: true);
      return false;
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while user role is being loaded
    if (_userRole == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      appBar: _buildAppBar(context, isDark),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      endDrawer: _buildNotificationsDrawer(context),
      bottomNavigationBar: _buildBottomNavigationBar(context, isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      systemOverlayStyle: isDark 
          ? SystemUiOverlayStyle.light 
          : SystemUiOverlayStyle.dark,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_hospital_rounded,
              color: AppTheme.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Health',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.primaryBlue,
                ),
              ),
              Text(
                'Your Health Companion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            AppTheme.themeMode.value = 
                AppTheme.themeMode.value == ThemeMode.light 
                    ? ThemeMode.dark 
                    : ThemeMode.light;
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
              color: theme.colorScheme.primary,
            ),
          ),
          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
        ),
        IconButton(
  onPressed: () {
    _scaffoldKey.currentState?.openEndDrawer();
  },
  icon: ValueListenableBuilder<int>(
    valueListenable: NotificationCenter.instance.unreadCount,
    builder: (context, count, _) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_rounded,
            color: theme.colorScheme.primary,
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    },
  ),
  tooltip: 'Notifications',
),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => _onItemTapped(i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: _navigationItems.map((item) {
            final index = _navigationItems.indexOf(item);
            final isSelected = _currentIndex == index;
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(isSelected ? item.activeIcon : item.icon, size: 24),
              ),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  Drawer _buildNotificationsDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Notifications', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1))),
                  TextButton.icon(
                    onPressed: () async {
                      await NotificationCenter.instance.clearAll();
                    },
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder<List<AppNotificationItem>>(
                valueListenable: NotificationCenter.instance.notifications,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications yet',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = list[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: n.read ? theme.colorScheme.surface : theme.colorScheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                        ),
                        child: ListTile(
                          title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(n.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void openNotificationsPanel() {
    _scaffoldKey.currentState?.openEndDrawer();
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}







