import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/doctor_service.dart';
import '../services/admin_service.dart';
import 'package:flutter/services.dart';

class DoctorListTab extends StatefulWidget {
  const DoctorListTab({super.key});

  @override
  State<DoctorListTab> createState() => _DoctorListTabState();
}

class _DoctorListTabState extends State<DoctorListTab> with TickerProviderStateMixin {
  bool _isLoadingAction = false; // Loading state for block/unblock operations
  final DoctorService _doctorService = DoctorService();
  final AdminService _adminService = AdminService();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  Stream<List<Map<String, dynamic>>>? _pendingVerificationsStream;
  Stream<List<Map<String, dynamic>>>? _rejectedDoctorsStream;
  Stream<List<Map<String, dynamic>>>? _approvedDoctorsStream;
  Stream<List<Map<String, dynamic>>>? _allDoctorsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStreams();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
     _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }



  void _loadStreams() {
    _pendingVerificationsStream = _doctorService.getPendingDoctorVerificationsWithUserData();
    _rejectedDoctorsStream = _doctorService.getDoctorsByVerificationStatusWithUserData('rejected');
    _approvedDoctorsStream = _doctorService.getDoctorsByVerificationStatusWithUserData('approved');
    _allDoctorsStream = _adminService.getAllDoctorsStream();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.only(top: 16,left: 16,right: 16 ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              // borderRadius: const BorderRadius.only(
              //   bottomLeft: Radius.circular(20),
              //   bottomRight: Radius.circular(20),
              // ),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search doctors by name, specialty...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Tabs
          Container(
            padding: const EdgeInsets.only(top: 8.0),
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  width: 2.0,
                  color: theme.colorScheme.primary,
                ),
              ),
              tabs: const [
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pending_actions_rounded, size: 20),
                      SizedBox(height: 6),
                      Text('Pending'),
                    ],
                  ),
                ),
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_rounded, size: 20),
                      SizedBox(height: 6),
                      Text('Rejected'),
                    ],
                  ),
                ),
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, size: 20),
                      SizedBox(height: 6),
                      Text('Approved'),
                    ],
                  ),
                ),
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_rounded, size: 20),
                      SizedBox(height: 6),
                      Text('All'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatusTab(theme, _pendingVerificationsStream, 'pending'),
                  _buildStatusTab(theme, _rejectedDoctorsStream, 'rejected'),
                  _buildStatusTab(theme, _approvedDoctorsStream, 'true'),
                  _buildAllDoctorsTab(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(ThemeData theme, Stream<List<Map<String, dynamic>>>? stream, String status) {
    return Stack(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(theme, 'Error loading ${status.capitalize()} doctors');
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var items = snapshot.data!;

            // Apply search filter
            if (_searchQuery.isNotEmpty) {
              items = items.where((item) {
                final userData = item['userData'] as Map<String, dynamic>? ?? {};
                final name = userData['name']?.toString().toLowerCase() ?? '';
                final email = userData['email']?.toString().toLowerCase() ?? '';
                final specialization = item['specialization']?.toString().toLowerCase() ?? '';
                return name.contains(_searchQuery) ||
                       email.contains(_searchQuery) ||
                       specialization.contains(_searchQuery);
              }).toList();
            }

            if (items.isEmpty) {
              return _buildEmptyState(
                theme,
                'No ${status.capitalize()} doctors',
                _searchQuery.isNotEmpty
                    ? 'No matching results for "$_searchQuery"'
                    : 'No ${status.capitalize().toLowerCase()} doctors found',
                _getStatusIcon(status),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final userData = item['userData'] as Map<String, dynamic>? ?? {};

                // Combine verification data with user data
                final combinedData = {
                  ...item,
                  ...userData,
                  'docId': item['id'],
                };

                if (status == 'pending') {
                  return _buildVerificationCard(combinedData, theme);
                } else {
                  return _buildDoctorCard(combinedData, theme, showActions: false);
                }
              },
            );
          },
        ),

        // Loading overlay for block/unblock operations
        if (_isLoadingAction) ...[
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ],
    );
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'true':
        return Icons.verified_rounded;
      default:
        return Icons.local_hospital_rounded;
    }
  }

  Widget _buildAllDoctorsTab(ThemeData theme) {
    return Stack(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _allDoctorsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(theme, 'Error loading doctors');
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var items = snapshot.data!;

            // Apply search filter
            if (_searchQuery.isNotEmpty) {
              items = items.where((item) {
                // Check if this is a verified doctor with userData
                final userData = item['userData'] as Map<String, dynamic>? ?? item;
                final name = userData['name']?.toString().toLowerCase() ?? '';
                final email = userData['email']?.toString().toLowerCase() ?? '';
                final specialization = item['specialization']?.toString().toLowerCase() ??
                                     userData['specialization']?.toString().toLowerCase() ?? '';

                return name.contains(_searchQuery) ||
                       email.contains(_searchQuery) ||
                       specialization.contains(_searchQuery);
              }).toList();
            }

            if (items.isEmpty) {
              return _buildEmptyState(
                theme,
                'No Doctors Found',
                _searchQuery.isNotEmpty
                    ? 'No matching results for "$_searchQuery"'
                    : 'No doctors found in the system',
                Icons.people_outline_rounded,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                // For unverified doctors, use item directly
                // For verified doctors, combine verification data with user data
                final combinedData = item['userData'] != null
                    ? {
                        ...item,
                        ...item['userData'] as Map<String, dynamic>,
                        'docId': item['id'],
                      }
                    : item;

                return _buildDoctorCard(combinedData, theme, showActions: false, showMenuIcon: true);
              },
            );
          },
        ),

        // Loading overlay for block/unblock operations
        if (_isLoadingAction) ...[
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ],
    );
  }

  // Build initial avatar with user's initial
  Widget _buildInitialAvatar(String name, ThemeData theme, [double size = 40]) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.primaryColor.withOpacity(0.3)
          : theme.primaryColor.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'D',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.onPrimary
              : theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  // Show the actual verification details dialog
  void _showVerificationDetailsDialog(
    Map<String, dynamic> docData, 
    ThemeData theme, 
    Map<String, dynamic> userData
  ) {
    final TextEditingController _rejectionController = TextEditingController();
    bool showRejectReason = false;
    bool isLoadingApprove = false;
    bool isLoadingReject = false;
    final userId = docData['userId'] as String?;
    final docId = docData['docId'] as String?;
    
    if (userId == null || docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Invalid verification data')),
      );
      return;
    }
    
    final doctorName = userData['name'] as String? ?? 'Unknown Doctor';
    final doctorEmail = userData['email'] as String? ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Stack(
                children: [
                  const Text('Verification Details'),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: (isLoadingApprove || isLoadingReject) ? null : () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: (isLoadingApprove || isLoadingReject)
                            ? theme.colorScheme.onSurface.withOpacity(0.3)
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                children: [
                  // Profile Image Section
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: userData['photoURL'] != null && userData['photoURL'].toString().isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                userData['photoURL'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(doctorName, theme, 40),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return _buildInitialAvatar(doctorName, theme, 40);
                                },
                              ),
                            )
                          : _buildInitialAvatar(doctorName, theme, 40),
                    ),
                  ),
                  // Details Section
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDetailRow(theme, 'Name', doctorName),
                          _buildDetailRow(theme, 'Email', doctorEmail),
                          _buildDetailRow(theme, 'License', docData['licenseNumber'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Specialization', docData['specialization'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Experience', docData['experience'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Clinic', docData['clinicName'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Phone', docData['phoneNumber'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Qualification', docData['qualification'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Consultation Fee', docData['fees'] ?? 'N/A'),
                          _buildDetailRow(theme, 'Consultation Type', docData['consultation'] ?? 'N/A'),

                          if (docData['about'] != null && (docData['about'] as String).isNotEmpty)
                            _buildDetailRow(theme, 'About', docData['about']),

                          if (showRejectReason) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Reason for Rejection:',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _rejectionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Enter reason for rejection',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!showRejectReason) ...[
                  TextButton(
                    onPressed: isLoadingApprove || isLoadingReject ? null : () {
                      setState(() => showRejectReason = true);
                    },
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isLoadingApprove ? null : () async {
                      setState(() => isLoadingApprove = true);
                      try {
                        // Update verification document
                        await FirebaseFirestore.instance
                            .collection('document_verification')
                            .doc(docId)
                            .update({
                              'status': 'approved',
                              'reviewedAt': FieldValue.serverTimestamp(),
                            });

                        // Update user's verification status
                        await _adminService.approveVerification(
                          context,
                          userId,
                          _loadStreams,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error approving verification: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoadingApprove = false);
                        }
                      }
                    },
                    child: isLoadingApprove
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ],
                if (showRejectReason) ...[
                  TextButton(
                    onPressed: isLoadingReject ? null : () async {
                      setState(() => isLoadingReject = true);
                      try {
                        final reason = _rejectionController.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a reason for rejection')),
                          );
                          setState(() => isLoadingReject = false);
                          return;
                        }

                        // Update verification document with rejection reason
                        await FirebaseFirestore.instance
                            .collection('document_verification')
                            .doc(docId)
                            .update({
                              'rejectionReason': reason,
                              'status': 'rejected',
                              'reviewedAt': FieldValue.serverTimestamp(),
                            });

                        // Update user's verification status
                        await _doctorService.updateDoctorVerificationStatus(userId, 'rejected');

                        if (mounted) {
                          Navigator.pop(context);
                          _loadStreams(); // Refresh the list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification rejected'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error rejecting verification: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoadingReject = false);
                        }
                      }
                    },
                    child: isLoadingReject
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          )
                        : const Text(
                            'Confirm Reject',
                            style: TextStyle(color: Colors.red),
                          ),
                  ),
                  TextButton(
                    onPressed: isLoadingReject || isLoadingApprove ? null : () {
                      _rejectionController.clear();
                      setState(() => showRejectReason = false);
                    },
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: (isLoadingReject || isLoadingApprove)
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // This is the original _buildVerificationCard method, now only used internally
  Widget _buildVerificationCard(Map<String, dynamic> docData, ThemeData theme) {
    // For now, we'll just return the summary card
    // The full details will be shown in the dialog
    return _buildVerificationSummaryCard(docData, theme);
  }

  // Summary card for pending verifications
  Widget _buildVerificationSummaryCard(Map<String, dynamic> docData, ThemeData theme) {
    final userId = docData['userId'] as String?;
    final submittedAt = docData['submittedAt'] as Timestamp?;

    if (userId == null || userId.isEmpty) {
      return _buildEmptyState(
        theme,
        'Invalid Doctor',
        'This doctor record is missing required information',
        Icons.error_outline_rounded,
      );
    }

    // Use FutureBuilder to fetch doctor details from users collection
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading...'),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyState(
            theme,
            'Doctor Not Found',
            'Could not find doctor details',
            Icons.person_off_rounded,
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final doctorName = userData['name'] as String? ?? 'Unknown Doctor';
        final doctorEmail = userData['email'] as String? ?? 'N/A';

        return GestureDetector(
          onTap: () => _showVerificationDetails(docData, theme, userData),
          child: Container(
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
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: userData['photoURL'] != null && userData['photoURL'].toString().isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    userData['photoURL'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(doctorName, theme, 25),
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return _buildInitialAvatar(doctorName, theme, 25);
                                    },
                                  ),
                                )
                              : _buildInitialAvatar(doctorName, theme, 25),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                doctorEmail,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _buildDetailRow(theme, 'Specialization', docData['specialization'] ?? 'Not specified'),
                    _buildDetailRow(theme, 'Experience', docData['experience'] ?? 'Not specified'),
                    _buildDetailRow(theme, 'Status', 'Pending Verification'),

                    // Bottom row with timing
                    if (submittedAt != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1), // Changed from theme.colorScheme.primary.withOpacity(0.1) to orange
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _adminService.formatDate(submittedAt.toDate()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange, // Changed from theme.colorScheme.primary to orange
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                // Arrow button at top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show verification details in a dialog
  void _showVerificationDetails(Map<String, dynamic> docData, ThemeData theme, [Map<String, dynamic>? userData]) {
    if (userData == null) {
      final userId = docData['userId'] as String?;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid verification data')),
        );
        return;
      }

      // Show loading dialog while fetching user data
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading doctor details...'),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              Navigator.pop(context); // Close loading dialog
              return const SizedBox.shrink();
            }

            // Now that we have the user data, show the details dialog
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context); // Close loading dialog
              _showVerificationDetailsDialog(docData, theme, userData);
            });
            return const SizedBox.shrink();
          },
        ),
      );
    } else {
      _showVerificationDetailsDialog(docData, theme, userData);
    }
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctorData, ThemeData theme, {bool showActions = true, bool showMenuIcon = false}) {
    final doctorName = doctorData['name'] as String? ?? 'Unknown Doctor';
    final doctorEmail = doctorData['email'] as String? ?? 'N/A';
    final isVerified = doctorData['isVerified'] as String? ?? 'false';
    final specialization = doctorData['specialization'] as String? ?? 'N/A';
    final experience = doctorData['experience'] as String? ?? 'N/A';

    // For rejected/approved doctors, use reviewedAt if available, otherwise use createdAt
    final reviewedAt = doctorData['reviewedAt'] as Timestamp?;
    final createdAt = doctorData['createdAt'] as Timestamp?;
    final displayTimestamp = reviewedAt ?? createdAt;

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
      child: Stack(
        children: [
          // Main card content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: doctorData['photoURL'] != null && doctorData['photoURL'].toString().isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              doctorData['photoURL'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(doctorName, theme, 25),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildInitialAvatar(doctorName, theme, 25);
                              },
                            ),
                          )
                        : _buildInitialAvatar(doctorName, theme, 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          doctorEmail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildDetailRow(theme, 'Specialization', specialization),
              _buildDetailRow(theme, 'Experience', experience),
              _buildDetailRow(theme, 'Status',
                  isVerified == 'true' ? 'Approved' :
                  isVerified == 'rejected' ? 'Rejected' : 'Not Verified'),

              // Bottom row with timing
              if (displayTimestamp != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVerified == 'true'
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : isVerified == 'rejected'
                                ? Colors.red.withOpacity(0.1)
                                : isVerified == 'pending' || isVerified == 'false'
                                    ? Colors.orange.withOpacity(0.1)
                                    : theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _adminService.formatDate(displayTimestamp.toDate()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isVerified == 'true'
                              ? theme.colorScheme.primary
                              : isVerified == 'rejected'
                                  ? Colors.red
                                  : isVerified == 'pending' || isVerified == 'false'
                                      ? Colors.orange
                                      : theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (showActions && isVerified != 'true') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _adminService.showDoctorDetails(context, doctorData),
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
                  ],
                ),
              ],
            ],
          ),

          // Blocked tag in bottom left if user is disabled
          if (doctorData['disabled'] == 'true') ...[
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Blocked',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          // 3-dot menu icon positioned at top right (only show in All tab)
          if (showMenuIcon) ...[
            Positioned(
              top: -10,
              right: -10,
              child: PopupMenuButton<String>(
                onSelected: (String value) async {
                  if (value == 'view_profile') {
                    _showViewProfileDialog(doctorData, theme);
                  } else if (value == 'block') {
                    setState(() {
                      _isLoadingAction = true;
                    });
                    await _adminService.blockUser(context, doctorData['email'], () => _loadStreams());
                    if (mounted) {
                      setState(() {
                        _isLoadingAction = false;
                      });
                    }
                  } else if (value == 'unblock') {
                    setState(() {
                      _isLoadingAction = true;
                    });
                    await _adminService.unblockUser(context, doctorData['email'], () => _loadStreams());
                    if (mounted) {
                      setState(() {
                        _isLoadingAction = false;
                      });
                    }
                  }
                },
                itemBuilder: (BuildContext context) {
                  // Check user's disabled status dynamically
                  final isDisabled = doctorData['disabled'] == 'true';
                  return [
                    const PopupMenuItem<String>(
                      value: 'view_profile',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('View Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: isDisabled ? 'unblock' : 'block',
                      child: Row(
                        children: [
                          Icon(
                            isDisabled ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                            size: 18,
                            color: isDisabled ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDisabled ? 'Unblock' : 'Block',
                            style: TextStyle(
                              color: isDisabled ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                splashRadius: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // Show view profile dialog (read-only version of verification details)
  void _showViewProfileDialog(Map<String, dynamic> doctorData, ThemeData theme) {
    final doctorName = doctorData['name'] as String? ?? 'Unknown Doctor';
    final doctorEmail = doctorData['email'] as String? ?? 'N/A';
    final specialization = doctorData['specialization'] as String? ?? 'N/A';
    final experience = doctorData['experience'] as String? ?? 'N/A';
    final isVerified = doctorData['isVerified'] as String? ?? 'false';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Stack(
            children: [
              const Text('Doctor Profile'),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Image Section
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: doctorData['photoURL'] != null && doctorData['photoURL'].toString().isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            doctorData['photoURL'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(doctorName, theme, 40),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildInitialAvatar(doctorName, theme, 40);
                            },
                          ),
                        )
                      : _buildInitialAvatar(doctorName, theme, 40),
                ),
              ),
              // Details Section
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDetailRow(theme, 'Name', doctorName),
                      _buildDetailRow(theme, 'Email', doctorEmail),
                      _buildDetailRow(theme, 'Specialization', specialization),
                      _buildDetailRow(theme, 'Experience', experience),
                      _buildDetailRow(theme, 'Status',
                          isVerified == 'true' ? 'Approved' :
                          isVerified == 'rejected' ? 'Rejected' : 'Not Verified'),
                      if (doctorData['phoneNumber'] != null)
                        _buildDetailRow(theme, 'Phone', doctorData['phoneNumber']),
                      if (doctorData['clinicName'] != null)
                        _buildDetailRow(theme, 'Clinic', doctorData['clinicName']),
                      if (doctorData['qualification'] != null)
                        _buildDetailRow(theme, 'Qualification', doctorData['qualification']),
                      if (doctorData['fees'] != null)
                        _buildDetailRow(theme, 'Consultation Fee', doctorData['fees']),
                      if (doctorData['consultation'] != null)
                        _buildDetailRow(theme, 'Consultation Type', doctorData['consultation']),
                      if (doctorData['licenseNumber'] != null)
                        _buildDetailRow(theme, 'License', doctorData['licenseNumber']),
                      if (doctorData['about'] != null && (doctorData['about'] as String).isNotEmpty)
                        _buildDetailRow(theme, 'About', doctorData['about']),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
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
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle, IconData icon) {
    return Center(
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
    );
  }
}

  extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
    }
  }
