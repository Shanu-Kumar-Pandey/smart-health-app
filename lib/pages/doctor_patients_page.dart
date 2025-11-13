import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/patient_profile_modal.dart';
import '../widgets/appointment_history_modal.dart';

class DoctorPatientsPage extends StatefulWidget {
  const DoctorPatientsPage({Key? key}) : super(key: key);

  @override
  _DoctorPatientsPageState createState() => _DoctorPatientsPageState();
}

class _DoctorPatientsPageState extends State<DoctorPatientsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _firestore = FirebaseFirestore.instance;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Format date to display
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
  
  // Format time to display
  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default: // scheduled
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      body: Column(
        
        children: [
          
          Padding(
            
            padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('appointments')
                  .where('doctorId', isEqualTo: currentUser?.uid)
                  .where('status', isNotEqualTo: 'cancelled')
                  .where('dateTime', isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                  .where('dateTime', isLessThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1))
                  .orderBy('dateTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No appointments found'));
                }

                final appointments = snapshot.data!.docs;
                final now = DateTime.now();
                
                if (appointments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No appointments for today', 
                             style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Group appointments by patient
                final Map<String, List<Map<String, dynamic>>> patientAppointmentsMap = {};
                
                for (var doc in appointments) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientId = data['userId'] as String;
                  
                  if (!patientAppointmentsMap.containsKey(patientId)) {
                    patientAppointmentsMap[patientId] = [];
                  }
                  
                  patientAppointmentsMap[patientId]!.add({
                    'appointment': data,
                    'appointmentTime': data['dateTime'] as Timestamp,
                    'status': data['status'] ?? 'scheduled',
                  });
                }

                // For each patient, find their next upcoming appointment or most recent past
                final patientAppointmentsList = <Map<String, dynamic>>[];
                
                patientAppointmentsMap.forEach((patientId, appts) {
                  // Sort patient's appointments by time
                  appts.sort((a, b) => (a['appointmentTime'] as Timestamp)
                      .compareTo(b['appointmentTime'] as Timestamp));
                  
                  // Find the next upcoming appointment
                  Map<String, dynamic>? nextAppointment;
                  for (var appt in appts) {
                    final apptTime = (appt['appointmentTime'] as Timestamp).toDate();
                    if (apptTime.isAfter(now)) {
                      nextAppointment = appt;
                      break;
                    }
                  }
                  
                  // If no upcoming, use the most recent past appointment
                  final displayAppointment = nextAppointment ?? appts.last;
                  
                  patientAppointmentsList.add({
                    'patientId': patientId,
                    'appointment': displayAppointment['appointment'],
                    'appointmentTime': displayAppointment['appointmentTime'],
                    'status': displayAppointment['status'],
                    'isUpcoming': nextAppointment != null,
                  });
                });
                
                // Sort patients by appointment time (upcoming first, then past)
                patientAppointmentsList.sort((a, b) {
                  final aTime = a['appointmentTime'] as Timestamp;
                  final bTime = b['appointmentTime'] as Timestamp;
                  final aIsUpcoming = a['isUpcoming'] as bool;
                  final bIsUpcoming = b['isUpcoming'] as bool;
                  
                  if (aIsUpcoming && !bIsUpcoming) return -1;
                  if (!aIsUpcoming && bIsUpcoming) return 1;
                  return aTime.compareTo(bTime);
                });

                return ListView.builder(
                  itemCount: patientAppointmentsList.length,
                  itemBuilder: (context, index) {
                    final item = patientAppointmentsList[index];
                    final appointmentData = item['appointment'] as Map<String, dynamic>;
                    final patientId = item['patientId'] as String;
                    final appointmentTime = item['appointmentTime'] as Timestamp;
                    final status = item['status'] as String;
                    final isUpcoming = appointmentTime.toDate().isAfter(now);
                    

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(patientId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(
                            leading: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            title: Text('Loading...'),
                          );
                        }

                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return const ListTile(
                            leading: Icon(Icons.error_outline, color: Colors.red),
                            title: Text('Patient not found'),
                          );
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        final fullName = '${userData?['name']?? ''}'.trim();
                        final displayName = fullName.isNotEmpty ? fullName : 'Unknown Patient';
                        
                        // Filter by search query
                        if (_searchQuery.isNotEmpty && 
                            !displayName.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildPatientAvatar(context, userData, displayName),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (appointmentTime != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Appointment: ${_formatDate(appointmentTime.toDate())}',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            Text(
                                              'Time: ${_formatTime(appointmentTime.toDate())}',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(appointmentData['status'] ?? '').withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _getStatusColor(appointmentData['status'] ?? ''),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                (appointmentData['status'] ?? 'Scheduled').toString().toUpperCase(),
                                                style: TextStyle(
                                                  color: _getStatusColor(appointmentData['status'] ?? ''),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          final currentUser = FirebaseAuth.instance.currentUser;
                                          if (currentUser != null) {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor: Colors.transparent,
                                              builder: (context) => AppointmentHistoryModal(
                                                patientId: patientId,
                                                doctorId: currentUser.uid,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.history, size: 16),
                                        label: const Text('History'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.blue[900]!.withOpacity(0.3) 
                                              : Colors.blue[50],
                                          foregroundColor: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.blue[100]
                                              : Colors.blue,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.blue[700]!
                                                  : Colors.blue[200]!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) => PatientProfileModal(
                                              userId: patientId ?? '',
                                              name: displayName,
                                              photoUrl: userData?['photoURL'],
                                              userData: userData,
                                              appointmentTime: appointmentTime?.toDate(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.person_outline, size: 16),
                                        label: const Text('Profile'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.green[900]!.withOpacity(0.3) 
                                              : Colors.green[50],
                                          foregroundColor: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.green[100]
                                              : Colors.green,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.green[700]!
                                                  : Colors.green[200]!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Check if the URL is valid for network image
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  // Build patient avatar with proper error handling
  Widget _buildPatientAvatar(BuildContext context, Map<String, dynamic>? userData, String displayName) {
    final photoUrl = userData?['photoURL']?.toString();
    
    if (!_isValidImageUrl(photoUrl)) {
      return _buildInitialsAvatar(context, displayName);
    }

    return CachedNetworkImage(
      imageUrl: photoUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => _buildInitialsAvatar(context, displayName),
      errorWidget: (context, url, error) => _buildInitialsAvatar(context, displayName),
    );
  }

  // Build avatar with user's initials
  Widget _buildInitialsAvatar(BuildContext context, String displayName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return CircleAvatar(
      backgroundColor: isDark 
          ? colorScheme.primary.withOpacity(0.3)
          : colorScheme.primary.withOpacity(0.2),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          color: isDark 
              ? colorScheme.onPrimary
              : colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

}
