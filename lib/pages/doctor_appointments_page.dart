import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import '../services/doctor_service.dart';
import 'prescription_page.dart';

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

class DoctorAppointmentsPage extends StatefulWidget {
  const DoctorAppointmentsPage({super.key});

  @override
  State<DoctorAppointmentsPage> createState() => _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedFilter = 'all';
  final DoctorService doctorService = DoctorService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, GlobalKey> _menuButtonKeys = {};

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
    _searchController.dispose();
    super.dispose();
  }

  // Search functionality - optimized to only search by patient name
  Future<List<QueryDocumentSnapshot>> _searchAppointments(List<QueryDocumentSnapshot> allAppointments) async {
    if (_searchQuery.isEmpty) return allAppointments;
    
    // First, get all patient names in a single batch
    final patientIds = allAppointments.map((appt) => (appt.data() as Map<String, dynamic>)['userId']).toSet().toList();
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: patientIds)
        .get();
    
    // Create a map of userId -> userName for quick lookup
    final userMap = {
      for (var doc in usersSnapshot.docs)
        doc.id: (doc.data()['name'] ?? '').toLowerCase()
    };
    
    // Filter appointments based on patient name match
    return allAppointments.where((appointment) {
      final apptData = appointment.data() as Map<String, dynamic>;
      final patientId = apptData['userId'];
      if (patientId == null) return false;
      
      final patientName = userMap[patientId] ?? '';
      return patientName.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Appointments',
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
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by patient name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            
            // Filter chips
            _buildFilterChips(context),
            
            // Appointments list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: doctorService.getDoctorAppointments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }
                  
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  
                  var allAppointments = snapshot.data?.docs ?? [];
                  
                  // Apply filter based on selected tab
                  final filteredAppointments = _filterAppointments(allAppointments);
                  
                  if (_searchQuery.isEmpty) {
                    if (filteredAppointments.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildAppointmentsList(filteredAppointments);
                  }
                  
                  return FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _searchAppointments(filteredAppointments),
                    builder: (context, searchSnapshot) {
                      if (searchSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }
                      
                      final searchedAppointments = searchSnapshot.data ?? [];
                      
                      if (searchedAppointments.isEmpty) {
                        return _buildEmptyState();
                      }
                      
                      return _buildAppointmentsList(searchedAppointments);
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

  Widget _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list_rounded},
      {'key': 'upcoming', 'label': 'Upcoming', 'icon': Icons.schedule_rounded},
      
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
                    filter['icon'] as IconData? ?? Icons.circle,
                    size: 18,
                    color: isSelected 
                        ? Colors.white 
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(filter['label'] as String? ?? ''),
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading appointments...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_rounded,
              size: 64,
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.error
                  : AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.primary
                  : AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedFilter == 'all' 
                ? 'No appointments yet'
                : 'No ${_selectedFilter} appointments',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'No appointments have been scheduled yet'
                : 'Try selecting a different filter',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
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


  List<QueryDocumentSnapshot> _filterAppointments(List<QueryDocumentSnapshot> appointments) {
    if (_selectedFilter == 'all') return appointments;

    return appointments.where((doc) {
      final appointment = doc.data() as Map<String, dynamic>;
      final status = (appointment['status'] ?? 'scheduled').toString().toLowerCase();

      switch (_selectedFilter.toLowerCase()) {
        case 'upcoming':
          // Show both scheduled and rescheduled appointments
          return status == 'scheduled' || status == 'rescheduled';
        case 'completed':
          return status == 'completed';
        case 'cancelled':
          return status == 'cancelled';
        case 'scheduled':
          return status == 'scheduled';
        default:
          return true;
      }
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
            color: theme.brightness == Brightness.dark 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.dividerColor.withOpacity(0.5), width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with status and actions
          _buildCardHeader(context, appointment, statusInfo, appointmentId),
          
          // Appointment details
          _buildCardDetails(appointment),
          
          // Action buttons - Show for both modifiable and completed appointments
          _buildCardActions(context, appointmentId, appointment),
        ],
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
    final status = appointment['status'] ?? 'scheduled';
    
    // Ensure we have a key for this appointment
    _menuButtonKeys[appointmentId] ??= GlobalKey();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? statusInfo['color'].withOpacity(0.3)
                  : statusInfo['color'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusInfo['icon'],
                  size: 16,
                  color: statusInfo['color'],
                ),
                const SizedBox(width: 6),
                Text(
                  statusInfo['label'],
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusInfo['color'],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // More options button - Hide for cancelled appointments
          if (status != 'cancelled')
            IconButton(
              key: _menuButtonKeys[appointmentId],
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                if (status == 'completed') {
                  _showPrescriptionOptions(context, appointmentId, appointment);
                } else {
                  _showAppointmentOptions(context, appointmentId, appointment);
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildCardDetails(Map<String, dynamic> appointment) {
    final theme = Theme.of(context);
    final date = _formatDateTime(appointment['dateTime']);
    final patientId = appointment['userId'];
    final notes = appointment['notes'] ?? 'No notes provided';
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, snapshot) {
        String displayName = 'Loading...';
        String? patientImage;
        
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          if (userData != null) {
            displayName = userData['name']?.toString() ?? 'Unknown Patient';
            patientImage = userData['photoURL']?.toString();
          }
        } else if (snapshot.hasError) {
          displayName = 'Error loading';
        }
        
        // Check if the image URL is valid
        final isValidImageUrl = patientImage != null && 
            patientImage.isNotEmpty && 
            (patientImage.startsWith('http://') || patientImage.startsWith('https://'));
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient name and time
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isValidImageUrl)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(patientImage!),
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint('Error loading avatar: $exception');
                      },
                    )
                  else
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (appointment['reason'] != null && appointment['reason'].toString().isNotEmpty) 
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Reason: ${appointment['reason']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Notes
              if (notes.isNotEmpty && notes != 'No notes provided') ...[
                Text(
                  'Notes:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
    
  Future<Map<String, dynamic>?> _getPrescriptionData(String appointmentId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('prescription')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return {
          'id': querySnapshot.docs.first.id,
          ...querySnapshot.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching prescription: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _navigateToPrescriptionPage(
    String patientName,
    String appointmentId,
    String patientId, {
    bool isUpdate = false,
  }) async {
    if (!context.mounted) return;
    
    Map<String, dynamic>? prescriptionData;
    if (isUpdate) {
      prescriptionData = await _getPrescriptionData(appointmentId);
      if (prescriptionData == null) return;
    }

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrescriptionPage(
            patientName: patientName,
            patientId: patientId,
            appointmentId: appointmentId,
            prescriptionData: prescriptionData,
          ),
        ),
      );
      // Refresh the appointments list after returning from the prescription page
      setState(() {});
    }
  }

  Future<void> _showPrescriptionOptions(
    BuildContext context,
    String appointmentId, 
    Map<String, dynamic> appointment,
  ) async {
    final buttonKey = _menuButtonKeys[appointmentId];
    if (buttonKey?.currentContext == null) return;

    final RenderBox button = buttonKey!.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'update',
          child: Text('Update Prescription'),
        ),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Text('Remove Prescription', style: TextStyle(color: Colors.red)),
        ),
      ],
    );

    if (result == 'update') {
      // Update feature coming soon
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update prescription feature coming soon!')),
        );
      }
    } else if (result == 'remove') {
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Prescription'),
            content: const Text('Are you sure you want to remove this prescription?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _removePrescription(appointmentId);
        }
      }
    }
  }

  Future<void> _removePrescription(String appointmentId) async {
    try {
      // Find and delete the prescription
      final querySnapshot = await FirebaseFirestore.instance
          .collection('prescription')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('prescription')
            .doc(querySnapshot.docs.first.id)
            .delete();
      }

      // Update appointment to remove prescription reference
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'hasPrescription': false,
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription removed successfully')),
        );
        setState(() {}); // Refresh the UI
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing prescription: $e')),
        );
      }
    }
  }

  Future<bool> _hasPrescription(String appointmentId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('prescription')
          .where('appointmentId', isEqualTo: appointmentId)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking prescription: $e')),
        );
      }
      return false;
    }
  }

  Widget _buildCardActions(
    BuildContext context, 
    String appointmentId, 
    Map<String, dynamic> appointment,
  ) {
    final status = (appointment['status'] ?? 'scheduled').toString().toLowerCase();
    final canComplete = status == 'scheduled' || status == 'rescheduled';
    final canCancel = status == 'scheduled' || status == 'rescheduled';
    final isCompleted = status == 'completed';
    final hasPrescription = appointment['hasPrescription'] ?? false;
    
    // Debug print to check status
    debugPrint('Appointment $appointmentId - Status: $status, isCompleted: $isCompleted');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isCompleted) 
            Expanded(
              child: FutureBuilder<bool>(
                future: _hasPrescription(appointmentId),
                builder: (context, snapshot) {
                  final hasPrescription = snapshot.data ?? false;
                  return FilledButton.icon(
                    onPressed: () => _navigateToPrescriptionPage(
                      appointment['patientName'] ?? 'Patient',
                      appointmentId,
                      appointment['userId'],
                      isUpdate: hasPrescription,
                    ),
                    icon: Icon(hasPrescription ? Icons.edit : Icons.add, size: 18),
                    label: Text(hasPrescription ? 'Update Prescription' : 'Add Prescription'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  );
                },
              ),
            )
          else ...[
            if (canComplete) 
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markAsComplete(context, appointmentId, appointment),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Complete'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            
            if (canComplete && canCancel) const SizedBox(width: 12),
            
            if (canCancel)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(context, appointmentId, appointment),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ].where((widget) => widget != null).toList(),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'completed':
        return {
          'label': 'Completed',
          'color': Colors.green,
          'icon': Icons.check_circle_rounded,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.red,
          'icon': Icons.cancel_rounded,
        };
      case 'rescheduled':
        return {
          'label': 'Rescheduled',
          'color': Colors.orange,
          'icon': Icons.schedule_rounded,
        };
      case 'scheduled':
      default:
        return {
          'label': 'Scheduled',
          'color': Colors.blue,
          'icon': Icons.calendar_today_rounded,
        };
    }
  }

  void _showFilterDialog(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Appointments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterChip('All Appointments', 'all', context),
            _buildFilterChip('Upcoming', 'scheduled', context),
            _buildFilterChip('Completed', 'completed', context),
            _buildFilterChip('Cancelled', 'cancelled', context),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, BuildContext context) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.1) 
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.dividerColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? theme.colorScheme.primary : theme.hintColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppointmentOptions(
    BuildContext context, 
    String appointmentId, 
    Map<String, dynamic> appointment,
  ) {
    final status = (appointment['status'] ?? 'scheduled').toString().toLowerCase();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'scheduled' || status == 'rescheduled')
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Cancel Appointment'),
                onTap: () {
                  Navigator.pop(context);
                  _showCancelDialog(context, appointmentId, appointment);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsComplete(
    BuildContext context, 
    String appointmentId, 
    Map<String, dynamic> appointment,
  ) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark as Complete'),
          content: const Text('Are you sure you want to mark this appointment as complete?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Complete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Update appointment status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment marked as complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _showCancelDialog(
    BuildContext context, 
    String appointmentId, 
    Map<String, dynamic> appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text('Are you sure you want to cancel this appointment? This action cannot be undone.'),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('No, Keep It'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Yes, Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(dynamic date) {
    if (date == null) return 'No date set';
    
    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return 'Invalid date';
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
}