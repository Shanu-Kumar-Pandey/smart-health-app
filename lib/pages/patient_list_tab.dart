import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/admin_service.dart';
import '../services/appointment_service.dart';

class PatientListTab extends StatefulWidget {
  const PatientListTab({super.key});

  @override
  State<PatientListTab> createState() => _PatientListTabState();
}

class _PatientListTabState extends State<PatientListTab> with TickerProviderStateMixin {
  late TextEditingController _searchController;
  String _searchQuery = '';
  bool _isLoadingAction = false; // Loading state for block/unblock operations
  final AdminService _adminService = AdminService();
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Search header
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
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search patients by name or email...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
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
                  ),
                ),
                const SizedBox(height: 12),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        'Total Patients',
                        StreamBuilder<int>(
                          stream: _adminService.getTotalPatientCount(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                '${snapshot.data}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'N/A',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              return Text(
                                '...',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              );
                            }
                          },
                        ),
                        Icons.people_rounded,
                        AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        'Total Appointments',
                        StreamBuilder<int>(
                          stream: _adminService.getTotalAppointmentCount(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                '${snapshot.data}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'N/A',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              return Text(
                                '...',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              );
                            }
                          },
                        ),
                        Icons.calendar_today_rounded,
                        AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Patients list
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _adminService.getPatientsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorState(theme, 'Error loading patients');
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final patientDocs = snapshot.data!.docs;

                    if (patientDocs.isEmpty) {
                      return _buildEmptyState(
                        theme,
                        'No patients found',
                        'No patients have registered yet',
                        Icons.people_outline_rounded,
                      );
                    }

                    // Filter patients based on search query
                    final filteredPatients = patientDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] as String? ?? '').toLowerCase();
                      final email = (data['email'] as String? ?? '').toLowerCase();
                      return name.contains(_searchQuery) || email.contains(_searchQuery);
                    }).toList();

                    if (filteredPatients.isEmpty) {
                      return _buildEmptySearchState(theme);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 86),
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patientData = filteredPatients[index].data() as Map<String, dynamic>;
                        return _buildPatientCard(patientData, theme);
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, Widget value, IconData icon, Color color) {
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
          value,
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

  Widget _buildPatientCard(Map<String, dynamic> patientData, ThemeData theme) {
    final patientName = patientData['name'] as String? ?? 'Unknown Patient';
    final patientEmail = patientData['email'] as String? ?? 'N/A';
    final age = patientData['age'] as int? ?? 0;
    final gender = patientData['gender'] as String? ?? 'N/A';
    final bloodGroup = patientData['bloodGroup'] as String? ?? 'N/A';
    final createdAt = patientData['createdAt'] as Timestamp?;

    // Note: userId will be fetched from users collection using email when needed
    // The actual userId is the document ID in the users collection

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // onTap: () => _showPatientDetails(patientData),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                        // Profile avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: ClipOval(
                            child: patientData['photoURL'] != null && !patientData['photoURL'].startsWith('avatar_')
                                ? Image.network(
                                    patientData['photoURL'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildDefaultPatientAvatar(),
                                  )
                                : _buildDefaultPatientAvatar(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                patientEmail,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Patient details chips
                    Row(
                      children: [
                        if (age > 0)
                          _buildDetailChip(theme, 'Age $age', AppTheme.primaryBlue),
                        if (gender.isNotEmpty && gender != 'N/A')
                          _buildDetailChip(theme, gender, AppTheme.secondaryTeal),
                        if (bloodGroup.isNotEmpty && bloodGroup != 'N/A')
                          _buildDetailChip(theme, bloodGroup, AppTheme.successGreen),
                      ],
                    ),

                    // Bottom row with timing
                    if (createdAt != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _adminService.formatDate(createdAt.toDate()),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                        ],
                        
                      ),

                       
                    ],
                      // const SizedBox(height: 50),
                  ],
                ),
  
                // Blocked tag in bottom left if patient is disabled
                if (patientData['disabled'] == 'true') ...[
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

                // 3-dot menu positioned at top right
                Positioned(
                  top: -10,
                  right: -10,
                  child: PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuSelection(value, patientData),
                    itemBuilder: (context) {
                      // Check patient's disabled status dynamically
                      final isDisabled = patientData['disabled'] == 'true';
                      return [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('View History'),
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
                                isDisabled ? 'Unblock Patient' : 'Block Patient',
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
            ),
            
          ),
          
        ),
        
      ),
      
    );
    
  }

  Widget _buildDefaultPatientAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(
        Icons.person_rounded,
        color: AppTheme.primaryBlue,
        size: 25,
      ),
    );
  }

  Widget _buildDetailChip(ThemeData theme, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
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

  Widget _buildEmptySearchState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Name', patientData['name'] ?? 'N/A'),
              _buildDetailItem('Email', patientData['email'] ?? 'N/A'),
              _buildDetailItem('Age', patientData['age']?.toString() ?? 'N/A'),
              _buildDetailItem('Gender', patientData['gender'] ?? 'N/A'),
              _buildDetailItem('Blood Group', patientData['bloodGroup'] ?? 'N/A'),
              _buildDetailItem('Role', patientData['role'] ?? 'N/A'),
              _buildDetailItem('Created', _adminService.formatDate(patientData['createdAt']?.toDate())),
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

  void _handleMenuSelection(String value, Map<String, dynamic> patientData) async {
    switch (value) {
      case 'view':
        _showPatientDetails(patientData);
        break;
      case 'history':
        // Get userId by querying users collection using email (document ID is the userId)
        final email = patientData['email'] as String?;
        if (email != null && email.isNotEmpty) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

            if (userDoc.docs.isNotEmpty) {
              final userId = userDoc.docs.first.id; // Document ID is the userId
              _showPatientHistory(userId);
            } else {
              _showPatientHistory(''); // Show empty results
            }
          } catch (e) {
            _showPatientHistory(''); // Show empty results
          }
        } else {
          _showPatientHistory(''); // Show empty results
        }
        break;
      case 'block':
        _showBlockConfirmationDialog(patientData);
        break;
      case 'unblock':
        _showUnblockConfirmationDialog(patientData);
        break;
    }
  }

  void _blockPatientConfirmed(Map<String, dynamic> patientData) async {
    setState(() {
      _isLoadingAction = true;
    });
    await _adminService.blockUser(context, patientData['email'], () {});
    if (mounted) {
      setState(() {
        _isLoadingAction = false;
      });
      // Show toast from main widget context
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('${patientData['name'] ?? 'Patient'} has been blocked successfully'),
      //     backgroundColor: Colors.green,
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
    }
  }

  void _unblockPatientConfirmed(Map<String, dynamic> patientData) async {
    setState(() {
      _isLoadingAction = true;
    });
    await _adminService.unblockUser(context, patientData['email'], () {});
    if (mounted) {
      setState(() {
        _isLoadingAction = false;
      });
      // Show toast from main widget context
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('${patientData['name'] ?? 'Patient'} has been unblocked successfully'),
      //     backgroundColor: Colors.green,
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
    }
  }

  void _showPatientHistory(String userId) async {
    setState(() {
      _isLoadingAction = true;
    });

    final appointments = await _appointmentService.getUserAppointmentsById(userId);

    if (mounted) {
      setState(() {
        _isLoadingAction = false;
      });
      _showAppointmentHistoryDialog(userId, appointments);
    }
  }

  void _showBlockConfirmationDialog(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Patient'),
        content: Text('Are you sure you want to block ${patientData['name'] ?? 'this patient'}? They will not be able to access the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _blockPatientConfirmed(patientData);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmationDialog(Map<String, dynamic> patientData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock Patient'),
        content: Text('Are you sure you want to unblock ${patientData['name'] ?? 'this patient'}? They will regain access to the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unblockPatientConfirmed(patientData);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentHistoryDialog(String userId, List<Map<String, dynamic>> appointments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Patient Appointment History'),
        content: SizedBox(
          width: double.maxFinite,
          child: appointments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No appointments found', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('This patient has not booked any appointments yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return _buildAppointmentCard(appointment, context);
                  },
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
  Widget _buildAppointmentCard(Map<String, dynamic> appointment, BuildContext context) {
    final doctorName = appointment['doctorName'] as String? ?? 'Unknown Doctor';
    final doctorId = appointment['doctorId'] as String? ?? 'N/A';
    final date = appointment['dateTime'] as Timestamp?;
    final status = appointment['status'] as String? ?? 'unknown';
    final fees = appointment['fees'] as String? ?? 'N/A';
    final reason = appointment['reason'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ID: $doctorId',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                  ),
                  child: Text(
                    _capitalizeFirst(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  date != null ? DateFormat('MMM dd, yyyy hh:mm a').format(date.toDate()) : 'N/A',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (fees.isNotEmpty && fees != 'N/A') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.currency_rupee, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    fees,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

}
