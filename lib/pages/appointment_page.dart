import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_theme.dart';
import 'payment_page.dart';
import '../services/rating_service.dart';

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

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> 
    with TickerProviderStateMixin {
  String? _selectedDoctor;
  String? _selectedDate;
  String? _selectedTime;
  String? _selectedReason;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedSpecialty = 'All';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _doctors = [];
  bool _isLoadingDoctors = true;
  String? _errorMessage;


Future<void> _fetchDoctors() async {
  try {
   
    setState(() {
      _isLoadingDoctors = true;
      _errorMessage = null;
    });

    // Get all users with role 'doctor'
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();

    // Filter doctors who are verified, have set_time: true, and are not disabled
    List<Map<String, dynamic>> doctors = [];

    for (var userDoc in userSnapshot.docs) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Convert string values to appropriate types
      final isVerified = userData['isVerified'] == 'true' || userData['isVerified'] == true;
      final hasSetTime = userData['set_time'] == true || userData['set_time'] == 'true';
      final isNotDisabled = userData['disabled'] == null ||
                          userData['disabled'] == false ||
                          userData['disabled'] == 'false';

      if (isVerified && hasSetTime && isNotDisabled) {
        // Fetch detailed doctor info from document_verification collection

        // Query by userId field instead of document ID
        QuerySnapshot verificationQuery = await FirebaseFirestore.instance
            .collection('document_verification')
            .where('userId', isEqualTo: userDoc.id)
            .limit(1)
            .get();

        if (verificationQuery.docs.isNotEmpty) {
          DocumentSnapshot docVerification = verificationQuery.docs.first;
          Map<String, dynamic> verificationData = docVerification.data() as Map<String, dynamic>;

          // Get real rating from rating service
          double averageRating = 0.0;
          try {
            averageRating = await RatingService().getDoctorAverageRating(userDoc.id);
          } catch (e) {
            // Handle rating error silently
          }

          // Format the doctor data with real information
          doctors.add({
            'id': userDoc.id,
            'name': userData['name'] ?? 'Doctor',
            'specialty': verificationData['specialization'] ?? 'General Physician',
            'experience': verificationData['experience'] ?? '5 years',
            'rating': averageRating > 0 ? averageRating.toStringAsFixed(1) : 'N/A',
            'fees': '₹${verificationData['fees'] ?? '1000'}',
            'doctorId': userDoc.id,
            'qualification': verificationData['qualification'] ?? 'MBBS',
            'hospital': verificationData['clinicName'] ?? 'N/A',
            'consultation': verificationData['consultation'] ?? 'N/A',
            'startTime': verificationData['startTime'],
            'endTime': verificationData['endTime'],
            'gapDuration':verificationData['gapDuration'],
            'consultationDuration': verificationData['consultationDuration'],
            
            'image': userData['photoURL'] ?? 'assets/doctor.png',
            'about': verificationData['about'] ?? verificationData['additionalInfo'] ?? 'Experienced medical professional',
            'clinicAddress': verificationData['clinicAddress'],

            'phoneNumber': verificationData['phoneNumber'],
          });
        } 
      } else {
        // Doctor doesn't meet criteria
      }
    }

    setState(() {
      _doctors = doctors;
      _isLoadingDoctors = false;
    });
  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to load doctors. Please try again.';
      _isLoadingDoctors = false;
    });
  }
}

List<String> _formatTimings(String? startTime, String? endTime, dynamic gapDuration) {
  if (startTime != null && endTime != null) {
    String gap = '';
    if (gapDuration != null) {
      int gapMinutes = (gapDuration is int) ? gapDuration : int.tryParse(gapDuration.toString()) ?? 30;
      gap = ' (Gap: ${gapMinutes}min)';
    }
    return ['$startTime - $endTime$gap'];
  }
  return ['Mon - Fri: 9:00 AM - 5:00 PM'];
}

  final List<String> _reasons = [
    'General Checkup',
    'Follow-up Visit',
    'Emergency Consultation',
    'Lab Results Review',
    'Prescription Renewal',
    'Vaccination',
    'Second Opinion',
    'Preventive Care',
    'Other',
  ];

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
    _fetchDoctors();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Book Appointment',
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
            tooltip: 'Filter doctors',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search and Filter Section
            _buildSearchSection(context),
            
            // Doctors List
            Expanded(
              child: _buildDoctorsList(context),
            ),
            
            // Appointment Form (if doctor selected)
            if (_selectedDoctor != null)
              _buildAppointmentBottomSheet(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          Container(
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
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search doctors, specialties...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Specialty Filter Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _getSpecialties().map((specialty) {
                final isSelected = _selectedSpecialty == specialty;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(specialty),
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpecialty = specialty;
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
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsList(BuildContext context) {
    if (_isLoadingDoctors) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDoctors,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredDoctors = _getFilteredDoctors();
    
    if (filteredDoctors.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 15,
        right: 15,
        bottom: 80, // Add extra space at the bottom to accommodate the bottom navigation bar
      ),
      itemCount: filteredDoctors.length,
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          child: _buildModernDoctorCard(filteredDoctors[index], index),
        );
      },
    );
  }

  // Show doctor profile in a dialog
  void _showDoctorProfile(BuildContext context, Map<String, dynamic> doctor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildDoctorImage(doctor['image']),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor['name'],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor['specialty'],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildInfoChip(
                                  icon: Icons.star_rounded,
                                  text: doctor['rating'],
                                  color: AppTheme.warningOrange,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoChip(
                                  icon: Icons.work_rounded,
                                  text: doctor['experience'],
                                  color: AppTheme.secondaryTeal,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.school_rounded,
                    title: 'Qualification',
                    value: doctor['qualification'],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.local_hospital_rounded,
                    title: 'Hospital',
                    value: doctor['hospital'],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.video_call_rounded,
                    title: 'Consultation',
                    value: doctor['consultation'],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'About',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    doctor['about'],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the dialog
                        setState(() {
                          _selectedDoctor = doctor['name'];
                          _selectedDate = null;
                          _selectedTime = null;
                          _selectedReason = null;
                        });
                        // Show booking bottom sheet
                        _buildAppointmentBottomSheet(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Book Appointment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernDoctorCard(Map<String, dynamic> doctor, int index) {
    final theme = Theme.of(context);
    
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildDoctorImage(doctor['image']),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor['specialty'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.star_rounded,
                            text: doctor['rating'],
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            icon: Icons.work_rounded,
                            text: doctor['experience'],
                            color: AppTheme.secondaryTeal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        doctor['fees'],
                        style: TextStyle(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showDoctorProfile(context, doctor);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppTheme.primaryBlue),
                    ),
                    icon: Icon(Icons.person_outline, color: AppTheme.primaryBlue, size: 20),
                    label: Text(
                      'View Profile',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedDoctor = doctor['name'];
                        _selectedDate = null;
                        _selectedTime = null;
                        _selectedReason = null;
                      });
                      _buildAppointmentBottomSheet(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
      ),
    );
  }

  
  Widget _buildDoctorImage(String? imageUrl) {
    // Check if it's a network URL (starts with http/https)
    if (imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppTheme.primaryBlue,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person_rounded,
            color: AppTheme.primaryBlue,
            size: 30,
          );
        },
      );
    } else {
      // Fallback to asset image
      return Image.asset(
        imageUrl ?? 'assets/doctor.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person_rounded,
            color: AppTheme.primaryBlue,
            size: 30,
          );
        },
      );
    }
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppTheme.primaryBlue,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No doctors found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSpecialties() {
    final specialties = _doctors.map((d) => d['specialty'] as String).toSet().toList();
    specialties.insert(0, 'All');
    return specialties;
  }

  List<Map<String, dynamic>> _getFilteredDoctors() {
    
    final filtered = _doctors.where((doctor) {
      final name = doctor['name']?.toString() ?? 'Unnamed';
      final specialty = doctor['specialty']?.toString() ?? 'General';
      
      final nameMatch = name.toLowerCase().contains(_searchQuery.toLowerCase());
      final specialtyMatch = _selectedSpecialty == null || 
          _selectedSpecialty == 'All' ||
          specialty.toLowerCase().contains(_selectedSpecialty!.toLowerCase());
      
   
      return nameMatch && specialtyMatch;
    }).toList();
    
    return filtered;
  }


  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Doctors',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Specialties'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getSpecialties().map((specialty) {
                          final isSelected = _selectedSpecialty == specialty;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(specialty),
                            onSelected: (selected) {
                              setState(() {
                                _selectedSpecialty = specialty;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85, // Limit height to 85% of screen
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Book Appointment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedDoctor = null;
                        _selectedDate = null;
                        _selectedTime = null;
                        _selectedReason = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAppointmentForm(),
              const SizedBox(height: 20), // Add some bottom padding
            ],
          ),
        ),
      ),
    );
  }

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

  Future<List<TimeSlot>> _generateTimeSlots(Map<String, dynamic> doctorData) async {
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
      int slotNumber = 1;

      // Check if selected date is today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool isToday = false;
      
      if (_selectedDate != null) {
        try {
          final dateParts = _selectedDate!.split('/');
          if (dateParts.length == 3) {
            final selectedDay = int.parse(dateParts[0]);
            final selectedMonth = int.parse(dateParts[1]);
            final selectedYear = int.parse(dateParts[2]);
            final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
            isToday = selectedDate.isAtSameMomentAs(today);
          }
        } catch (e) {
          print('⚠️ Error parsing selected date: $e');
        }
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
        slotNumber++;
      }

      // Get booked slots for the selected date (only if date is selected)
      Set<String> bookedSlots = {};
      if (_selectedDate != null) {
        bookedSlots = await _getBookedTimeSlots(doctorData['doctorId'], _selectedDate!);
      }

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
      print('📊 Time slots for ${doctorData['name']}:');
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

  int _getDoctorConsultationDuration(String doctorId) {
    final doctor = _doctors.firstWhere(
      (d) => d['doctorId'] == doctorId,
      orElse: () => {'consultationDuration': 30},
    );
    return doctor['consultationDuration'] is int
        ? doctor['consultationDuration']
        : int.tryParse(doctor['consultationDuration'].toString()) ?? 30;
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

          // Format time slot (e.g., "09:00 AM - 09:30 AM")
          final startTime = _formatTimeFromMinutes(appointmentDateTime.hour * 60 + appointmentDateTime.minute);
          final duration = _getDoctorConsultationDuration(doctorId);
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

  List<String> _getNext3Days() {
    final List<String> dates = [];
    final now = DateTime.now();
    for (int i = 0; i < 3; i++) {  // Changed from 7 to 3 days
      final date = now.add(Duration(days: i));
      dates.add('${date.day}/${date.month}/${date.year}');
    }
    return dates;
  }

  Widget _buildAppointmentForm() {
    final selectedDoctor = _doctors.firstWhere(
      (d) => d['name'] == _selectedDoctor,
    );

    return Column(
      children: [
        // Date Selection
        DropdownButtonFormField<String>(
          value: _selectedDate,
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
              _selectedDate = value;
              _selectedTime = null; // Always reset time when date changes
            });
          },
        ),
        const SizedBox(height: 16),

        // Time Selection
        if (_selectedDate != null)
          FutureBuilder<List<TimeSlot>>(
            future: _generateTimeSlots(selectedDoctor),
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

              // Show all slots in the dropdown (both available and booked)
              final allSlots = timeSlotObjects;

              return DropdownButtonFormField<String>(
                value: _selectedTime,
                decoration: const InputDecoration(
                  labelText: 'Select Time',
                  border: OutlineInputBorder(),
                ),
                items: allSlots.map<DropdownMenuItem<String>>((timeSlot) {
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
                    final selectedSlot = allSlots.firstWhere(
                      (slot) => slot.time == value,
                      orElse: () => TimeSlot(time: '', isAvailable: false, isBooked: true),
                    );
                    if (selectedSlot.isAvailable) {
                      setState(() {
                        _selectedTime = value;
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
              );
            },
          ),
        const SizedBox(height: 16),

        // Reason Selection
        DropdownButtonFormField<String>(
          value: _selectedReason,
          decoration: const InputDecoration(
            labelText: 'Reason for Visit',
            border: OutlineInputBorder(),
          ),
          items: _reasons.map<DropdownMenuItem<String>>((reason) {
            return DropdownMenuItem<String>(value: reason, child: Text(reason));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedReason = value;
            });
          },
        ),
        const SizedBox(height: 24),

        // Book Button
        if (_selectedDate != null && _selectedTime != null && _selectedReason != null)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _bookAppointment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Book Appointment',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        const SizedBox(height: 74),
      ],
    );
  }

  Future<void> _bookAppointment() async {
    if (_selectedDoctor == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedReason == null) {
      return;
    }

    // Safety check: Verify the selected time is still available
    final selectedDoctorData = _doctors.firstWhere(
      (d) => d['name'] == _selectedDoctor,
    );

    final timeSlots = await _generateTimeSlots(selectedDoctorData);
    final selectedSlot = timeSlots.firstWhere(
      (slot) => slot.time == _selectedTime,
      orElse: () => TimeSlot(time: '', isAvailable: false, isBooked: false),
    );

    if (!selectedSlot.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorry, $_selectedTime is no longer available. Please select another time.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the selected doctor's data to extract fees and doctorId
      final selectedDoctor = _doctors.firstWhere(
        (d) => d['name'] == _selectedDoctor,
      );

      final doctorFees = selectedDoctor['fees'] ?? '₹0';
      final doctorId = selectedDoctor['doctorId'] ?? 'UNKNOWN';

      // Navigate to payment page instead of directly booking
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentPage(
              doctorName: _selectedDoctor!,
              appointmentDate: _selectedDate!,
              appointmentTime: _selectedTime!,
              reason: _selectedReason!,
              fees: doctorFees,
              doctorId: doctorId,
            ),
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
