import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'edit_profile_page.dart';
import 'faq_page.dart';
import 'payment_method_page.dart';

import 'profile_details_page.dart';
import 'my_appointments_page.dart';

import '../services/firebase_service.dart';
import '../services/appointment_service.dart';
import '../services/health_metrics_service.dart';
import '../services/doctor_service.dart';
import '../widgets/consultation_timing_dialog.dart';
import '../screen/login_screen.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';

class PersonTab extends StatefulWidget {
  const PersonTab({super.key});

  @override
  State<PersonTab> createState() => _PersonTabState();
}

class _PersonTabState extends State<PersonTab> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final AppointmentService _appointmentService = AppointmentService();
  final HealthMetricsService _healthMetricsService = HealthMetricsService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _biometricEnabled = false;
  bool _bioBusy = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _bioAvailable = true; // device supports biometrics and has at least one enrolled
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadUserProfile();
  }

  // Settings section: Theme + Biometric toggle underneath
  Widget _buildSettingsSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Theme item

          _buildMenuItem(
            context,
            ProfileMenuItem(
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              title: 'Theme',
              subtitle: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              color: AppTheme.neutralGray,
              onTap: () {
                HapticFeedback.lightImpact();
                AppTheme.themeMode.value =
                    AppTheme.themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
          // Biometric toggle beneath Theme
          if (_userProfile?.role != 'admin' && _userProfile?.role != 'doctor') ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue, size: 24),
              ),
              title: Text(
                'Biometric Lock',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _bioAvailable
                    ? 'Require fingerprint/biometric to open Records'
                    : 'Device biometrics unavailable or not enrolled',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: (_bioBusy || !_bioAvailable) ? null : (v) => _onBiometricToggle(v),
              ),
              onTap: (_bioBusy || !_bioAvailable) ? null : () => _onBiometricToggle(!_biometricEnabled),
            ),
          ),
          if (!_bioAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Your device biometrics are not enabled. Set up fingerprint/face unlock in system settings to use this feature.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          // Remaining items
           
          _buildMenuItem(
            context,
            ProfileMenuItem(
              icon: Icons.payment_rounded,
              title: 'Payment Methods',
              subtitle: 'Manage cards and payment options',
              color: AppTheme.secondaryTeal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentMethodPage()),
              ),
            ),
          ),
           ],
          _buildMenuItem(
            context,
            ProfileMenuItem(
              icon: Icons.help_rounded,
              title: 'FAQ',
              subtitle: 'Frequently asked questions',
              color: AppTheme.warningOrange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FAQPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBiometricToggle(bool enable) async {
    if (_bioBusy) return;
    setState(() => _bioBusy = true);
    try {
      final uid = _firebaseService.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to change biometric setting')),
        );
        return;
      }

      if (enable) {
        // Verify device capability and authenticate before enabling
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        final methods = await _localAuth.getAvailableBiometrics();
        if (!(supported && canCheck) || methods.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric not available/enrolled on this device')),
          );
          return;
        }
        final ok = await _localAuth.authenticate(
          localizedReason: 'Enable biometric lock for your health records',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication cancelled')),
          );
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'biometric': enable, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _biometricEnabled = enable);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biometric ${enable ? 'enabled' : 'disabled'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update setting: $e')),
      );
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  // Show consultation timing dialog
  Future<void> _showConsultationTimingDialog() async {
    final doctorService = DoctorService();
    
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Fetch existing timings
      final timings = await doctorService.getConsultationTimings();
      
      if (!mounted) return;
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      // Show the consultation timing dialog
      await showDialog(
        context: context,
        builder: (context) => ConsultationTimingDialog(
          doctorService: doctorService,
          initialStartTime: timings?['startTime'],
          initialEndTime: timings?['endTime'],
          initialConsultationDuration: timings?['consultationDuration'] ?? 30,
          initialGapDuration: timings?['gapDuration'] ?? 15,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load consultation timings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportHealthData() async {
    try {
      // Get user data
      final userData = await _firebaseService.getUserData();
      final healthScore = await _healthMetricsService.calculateHealthScore();
      
      // Get latest health metrics
      final metrics = [
        'Blood Pressure',
        'Blood Sugar',
        'Weight',
        'Heart Rate',
        'Body Temprature',
        'Oxygen Saturation'
      ];
      
      final Map<String, Map<String, dynamic>> latestMetrics = {};
      
      for (var metric in metrics) {
        try {
          final record = await _healthMetricsService.getLatestMetricRecord(metric);
          if (record != null) {
            latestMetrics[metric] = record;
          }
        } catch (e) {
          // Ignore errors for individual metrics
        }
      }
      
      // Generate PDF
      final pdf = pw.Document();
      final now = DateTime.now();
      
      // Add a page with the content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Health Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${now.day}/${now.month}/${now.year}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            
            // User Information
            pw.Header(level: 1, text: 'Personal Information'),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name', userData?.name ?? 'Not provided'),
                  _buildInfoRow('Email', userData?.email ?? 'Not provided'),
                  if (userData?.contact != null) _buildInfoRow('Phone', userData!.contact!),
                  if (userData?.gender != null) _buildInfoRow('Gender', userData!.gender!),
                  if (userData?.age != null) _buildInfoRow('Age', userData!.age.toString()),
                  if (userData?.weight != null) _buildInfoRow('Weight', '${userData!.weight} kg'),
                  if (userData?.bloodGroup != null) _buildInfoRow('Blood Group', userData!.bloodGroup!),
                  _buildInfoRow('Report Date', '${now.day}/${now.month}/${now.year}'),
                ],
              ),
            ),
            
            // Health Score
            pw.SizedBox(height: 10),
            pw.Header(level: 1, text: 'Health Overview'),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Your Health Score: ${healthScore.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _getHealthScoreColor(healthScore),
                  ),
                ),
              ),
            ),
            
            // Health Score Info
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: pw.Text(
                '* The health score is calculated based on the health data you have entered. Regular updates ensure more accurate assessments.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            // Health Metrics
            pw.SizedBox(height: 10),
            pw.Header(level: 1, text: 'Latest Health Metrics'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              headers: ['Metric', 'Value', 'Unit', 'Date Recorded'],
              data: latestMetrics.entries.map((entry) {
                final record = entry.value;
                final date = record['date'] is Timestamp 
                    ? (record['date'] as Timestamp).toDate() 
                    : DateTime.now();
                return [
                  entry.key,
                  record['value']?.toString() ?? 'N/A',
                  record['unit']?.toString() ?? 'N/A',
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                ];
              }).toList(),
            ),
            
            // Footer
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'Generated by Smart Health App - ${now.year}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
              ),
            ),
          ],
        ),
      );
      
      // Save the PDF document
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/health_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Open the PDF file
      await OpenFile.open(file.path);
      
    } catch (e) {
      throw Exception('Error generating health report: $e');
    }
  }
  
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
  
  PdfColor _getHealthScoreColor(double score) {
    if (score >= 75) return PdfColors.green;
    if (score >= 50) return PdfColors.orange;
    return PdfColors.red;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _firebaseService.getUserData();
      // Load biometric flag from user doc
      bool biometric = false;
      final uid = _firebaseService.currentUser?.uid;
      if (uid != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          biometric = (snap.data()?['biometric'] as bool?) ?? false;
        } catch (_) {}
      }
      // Determine device biometric availability (supported + enrolled)
      bool available = true;
      try {
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        final methods = await _localAuth.getAvailableBiometrics();
        available = supported && canCheck && methods.isNotEmpty;
      } catch (_) {
        available = false;
      }
      setState(() {
        _userProfile = profile;
        _isLoading = false;
        _biometricEnabled = biometric;
        _bioAvailable = available;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  // Build the change password dialog
  Widget _buildChangePasswordDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _currentPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        try {
                          // Reauthenticate user
                          final user = _firebaseService.currentUser;
                          if (user != null && user.email != null) {
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: _currentPasswordController.text,
                            );
                            
                            await user.reauthenticateWithCredential(credential);
                            
                            // Update password
                            await user.updatePassword(_newPasswordController.text);
                            
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          String message = 'An error occurred';
                          if (e.code == 'wrong-password') {
                            message = 'Incorrect current password';
                          } else if (e.code == 'weak-password') {
                            message = 'The password provided is too weak';
                          } else if (e.code == 'requires-recent-login') {
                            message = 'Please log in again to change your password';
                          }
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update password. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update Password'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, isDark),
            ),

            // Profile Stats (hidden for admin users)
            if (_userProfile?.role != 'admin' && _userProfile?.role != 'doctor') ...[
              SliverToBoxAdapter(
                child: _buildProfileStats(context, isDark),
              ),
            ],

            // Account Section
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: 'Account',
                items: [
                  ProfileMenuItem(
                    icon: Icons.person_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    color: AppTheme.primaryBlue,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(
                            onProfileUpdated: _loadUserProfile,
                          ),
                        ),
                      );
                      // Refresh the profile when returning from edit
                      await _loadUserProfile();
                    },
                  ),
                  ProfileMenuItem(
                    icon: Icons.info_rounded,
                    title: 'Profile Details',
                    subtitle: 'View your complete profile',
                    color: AppTheme.secondaryTeal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileDetailsPage()),
                    ),
                  ),
                  // Show Change Password only for non-Google users
                  if (_userProfile?.provider != 'google' && _userProfile?.provider != 'Google')
                    ProfileMenuItem(
                      icon: Icons.lock_reset_rounded,
                      title: 'Change Password',
                      subtitle: 'Update your account password',
                      color: AppTheme.warningOrange,
                      onTap: () {
                        // Show a dialog to enter current and new password
                        showDialog(
                          context: context,
                          builder: (context) => _buildChangePasswordDialog(context),
                        );
                      },
                    ),
                  if (_userProfile?.role == 'doctor' && _userProfile?.isVerified == 'true')
                    ProfileMenuItem(
                      icon: Icons.access_time_rounded,
                      title: 'Consultation Timings',
                      subtitle: 'Update your consultation timings',
                      color: AppTheme.primaryBlue,
                      onTap: _showConsultationTimingDialog,
                    ),
                ],
              ),
            ),

            // Health Section (hidden for admin users)
            if (_userProfile?.role != 'admin' && _userProfile?.role != 'doctor') ...[
              
              SliverToBoxAdapter(
                child: _buildSection(
                  context,
                  title: 'Health',
                  items: [
                    ProfileMenuItem(
                      icon: Icons.calendar_today_rounded,
                      title: 'My Appointments',
                      subtitle: 'View and manage appointments',
                      color: AppTheme.successGreen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyAppointmentsPage()),
                      ),
                    ),
  

                    
                    ProfileMenuItem(
                      icon: Icons.file_download_rounded,
                      title: 'Export Health Data',
                      subtitle: 'Download your health summary',
                      color: AppTheme.primaryBlue,
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Preparing health data export...'),
                            backgroundColor: AppTheme.primaryBlue,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        
                        try {
                          await _exportHealthData();
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Health data exported successfully!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to export health data: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    
                  ],
                ),
              ),
            ],

            // Settings Section with biometric toggle
            SliverToBoxAdapter(
              child: _buildSettingsSection(context, isDark),
            ),

            // Logout Section
            SliverToBoxAdapter(
              child: _buildLogoutSection(context, isDark),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final user = _firebaseService.currentUser;
    final userName = _userProfile?.name ?? 'User';
    final userEmail = user?.email ?? 'user@example.com';
    
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
      child: Column(
        children: [
          Row(
            children: [
              _buildProfileAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withOpacity(0.2),
                    //     borderRadius: BorderRadius.circular(20),
                    //   ),
                    //   child: Text(
                    //     'Premium Member',
                    //     style: theme.textTheme.bodySmall?.copyWith(
                    //       color: Colors.white,
                    //       fontWeight: FontWeight.w600,
                    //     ),
                    //   ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: _userProfile?.photoURL != null &&
               !_userProfile!.photoURL!.startsWith('avatar_')
            ? Image.network(
                _userProfile!.photoURL!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    Color avatarColor = AppTheme.primaryBlue;
    if (_userProfile?.photoURL != null &&
        _userProfile!.photoURL!.startsWith('avatar_')) {
      try {
        final colorValue = _userProfile!.photoURL!.replaceFirst('avatar_', '');
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
        size: 40,
      ),
    );
  }

  Widget _buildProfileStats(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<int>(
              future: _appointmentService.getScheduledAppointmentsCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return _buildStatCard(
                  context,
                  icon: Icons.calendar_today_rounded,
                  title: count.toString(),
                  subtitle: 'Appointments',
                  color: AppTheme.primaryBlue,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<double>(
              future: _healthMetricsService.calculateHealthScore(),
              builder: (context, snapshot) {
                final score = snapshot.data ?? 0.0;
                return _buildStatCard(
                  context,
                  icon: Icons.favorite_rounded,
                  title: '${score.round()}%',
                  subtitle: 'Health Score',
                  color: AppTheme.successGreen,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _healthMetricsService.getWeightProgressData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildStatCard(
                    context,
                    icon: Icons.trending_up_rounded,
                    title: 'Loading...',
                    subtitle: 'Progress ',
                    color: AppTheme.warningOrange,
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _buildStatCard(
                    context,
                    icon: Icons.trending_up_rounded,
                    title: 'Error',
                    subtitle: 'in Progress',
                    color: AppTheme.warningOrange,
                  );
                }

                final data = snapshot.data!;
                final currentWeight = data['currentWeight'] as String;
                final trend = data['trend'] as HealthTrend;

                // Choose icon based on weight trend
                IconData trendIcon;
                switch (trend) {
                  case HealthTrend.improving:
                    trendIcon = Icons.trending_up_rounded; // Above normal range
                    break;
                  case HealthTrend.declining:
                    trendIcon = Icons.trending_down_rounded; // Below normal range
                    break;
                  case HealthTrend.stable:
                    trendIcon = Icons.trending_flat_rounded; // Within normal range
                    break;
                }

                return _buildStatCard(
                  context,
                  icon: trendIcon,
                  title: currentWeight,
                  subtitle: 'Weight Progress',
                  color: AppTheme.warningOrange,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
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
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<ProfileMenuItem> items,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildMenuItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ProfileMenuItem item) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.icon,
            color: item.color,
            size: 24,
          ),
        ),
        title: Text(
          item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          item.subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap();
        },
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.errorRed.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.logout_rounded,
              color: AppTheme.errorRed,
              size: 24,
            ),
          ),
          title: Text(
            'Logout',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.errorRed,
            ),
          ),
          subtitle: Text(
            'Sign out and secure your account',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.errorRed.withOpacity(0.6),
          ),
          onTap: () => _showLogoutDialog(context),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: AppTheme.errorRed,
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _firebaseService.signOut();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}

class ProfileMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
