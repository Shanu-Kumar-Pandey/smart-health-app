import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class PatientProfileModal extends StatefulWidget {
  final String userId;
  final String name;
  final String? photoUrl;
  final Map<String, dynamic>? userData;
  final DateTime? appointmentTime;

  const PatientProfileModal({
    Key? key,
    required this.userId,
    required this.name,
    this.photoUrl,
    this.userData,
    this.appointmentTime,
  }) : super(key: key);

  @override
  _PatientProfileModalState createState() => _PatientProfileModalState();
}

class _PatientProfileModalState extends State<PatientProfileModal> {
  final _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _healthMetricsFuture;
  late Future<List<Map<String, dynamic>>> _healthRecordsFuture;

  bool _isWithin30Minutes(DateTime appointmentTime) {
    final now = DateTime.now();
    // Check if current time is exactly at or after appointment time
    // and before 30 minutes after appointment time
    return now.isAtSameMomentAs(appointmentTime) || 
           (now.isAfter(appointmentTime) && 
            now.isBefore(appointmentTime.add(const Duration(minutes: 30))));
  }

  @override
  void initState() {
    super.initState();
    _healthMetricsFuture = _fetchHealthMetrics();
    _healthRecordsFuture = _fetchHealthRecords();
  }

  Future<List<Map<String, dynamic>>> _fetchHealthMetrics() async {
    try {
      final query = await _firestore
          .collection('healthMetrics')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('updatedAt', descending: true)
          .limit(30) // Get more than needed to find unique metrics
          .get();

      // Get unique metrics (latest of each type)
      final Map<String, Map<String, dynamic>> uniqueMetrics = {};
      for (var doc in query.docs) {
        final data = doc.data();
        final metricName = data['metricName'] as String?;
        if (metricName != null && !uniqueMetrics.containsKey(metricName)) {
          uniqueMetrics[metricName] = data;
        }
        // Stop if we have all 6 metrics
        if (uniqueMetrics.length >= 6) break;
      }

      return uniqueMetrics.values.toList();
    } catch (e) {
      debugPrint('Error fetching health metrics: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHealthRecords() async {
    try {
      final query = await _firestore
          .collection('healthrecord')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(10) // Limit to 10 most recent records
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching health records: $e');
      return [];
    }
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if appointment time is within 30 minutes
    if (widget.appointmentTime != null && !_isWithin30Minutes(widget.appointmentTime!)) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Profile Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Profile is only accessible within appointment time window.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final userData = widget.userData ?? {};
    final allergies = (userData['allergies'] as List?)?.join(', ') ?? 'None';
    final conditions = (userData['chronicConditions'] as List?)?.join(', ') ?? 'None';
   
    final age = (userData['age'] ?? '-').toString();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main scrollable content
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar
                  Container(
                    padding: const EdgeInsets.only(top: 50, bottom: 16),
                    color: theme.primaryColor.withOpacity(0.1),
                    child: Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.transparent,
                        child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: widget.photoUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white70,
                                ),
                              ),
                      ),
                    ),
                  ),
                  
                  // Patient Info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Personal Info
                    _buildListSection('Personal Information', [
                      _buildInfoRow('Age', age),
                      _buildInfoRow('Gender', userData['gender']?.toString()),
                      _buildInfoRow('Blood Group', userData['bloodGroup']?.toString()),
                      _buildInfoRow('Weight', userData['weight'] != null 
                          ? '${userData['weight']} kg' 
                          : null),
                      _buildInfoRow('Email', userData['email']?.toString()),
                    ]),
                    
                    // Health Info
                    _buildListSection('Health Information', [
                      _buildInfoRow('Allergies', allergies),
                      _buildInfoRow('Chronic Conditions', conditions),
                    ]),
                    
                    // Health Metrics
                    _buildListSection(
                      'Latest Health Metrics',
                      [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _healthMetricsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final metrics = snapshot.data ?? [];
                            if (metrics.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No health metrics available'),
                              );
                            }
                            
                            return Column(
                              children: metrics.map((metric) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${metric['metricName']}:',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text('${metric['value']} ${metric['unit'] ?? ''}'),
                                    if (metric['notes'] != null && (metric['notes'] as String).isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.info_outline, size: 16),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('${metric['metricName']} Notes'),
                                              content: Text(metric['notes']),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              )).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    // Health Records
                    _buildListSection(
                      'Medical Reports',
                      [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _healthRecordsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            final records = snapshot.data ?? [];
                            if (records.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No medical reports available'),
                              );
                            }
                            
                            return Column(
                              children: records.map((record) => ListTile(
                                title: Text(record['title'] ?? 'Untitled Report'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (record['description'] != null && (record['description'] as String).isNotEmpty)
                                      Text(record['description'] as String),
                                    if (record['createdAt'] != null)
                                      Text(
                                        'Uploaded on: ${DateFormat('MMM d, y hh:mm a').format((record['createdAt'] as Timestamp).toDate())}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: record['description'] != null && (record['description'] as String).isNotEmpty,
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  if (record['doclink'] != null) {
                                    // TODO: Handle document opening
                                    // You can use url_launcher to open the document URL
                                  }
                                },
                              )).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Close button - positioned at the top-right of the dialog
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                margin: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
