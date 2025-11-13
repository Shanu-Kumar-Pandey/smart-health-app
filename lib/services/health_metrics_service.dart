import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum HealthStatus {
  normal,
  warning,
  critical,
}

enum HealthTrend {
  improving,
  stable,
  declining,
}

class HealthMetricsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Fetch recent health records
  Future<List<HealthRecord>> getRecentHealthRecords({int limit = 5}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final recentRecordsQuery = await _firestore
          .collection('healthMetrics')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return recentRecordsQuery.docs.map((doc) {
        final data = doc.data();
        return HealthRecord(
          id: doc.id,
          metricName: data['metricName'] ?? '',
          value: data['value'].toString(),
          timestamp: (data['date'] as Timestamp).toDate(),
          notes: data['notes'] ?? '',
        );
      }).toList();
    } catch (e) {
      throw Exception('Error fetching recent records: $e');
    }
  }

  // Get latest record for a specific metric
  Future<Map<String, dynamic>?> getLatestMetricRecord(String metricName) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final querySnapshot = await _firestore
          .collection('healthMetrics')
          .where('userId', isEqualTo: _currentUserId)
          .where('metricName', isEqualTo: metricName)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching latest record for $metricName: $e');
    }
  }

  // Count normal status metrics
  Future<int> countNormalStatusMetrics() async {
    if (_currentUserId == null) return 0;

    final metricTypes = [
      'Blood Pressure',
      'Blood Sugar',
      'Weight',
      'Heart Rate',
      'Body Temprature',  // Fixed spelling to match database
      'Oxygen Saturation'
    ];

    final normalRanges = [
      '90-120/60-80',  // Blood Pressure
      '70-100',        // Blood Sugar
      '65-75',         // Weight (example range)
      '60-100',        // Heart Rate
      '36.1-37.2',     // Body Temperature
      '95-100'         // Oxygen Saturation
    ];

    int normalCount = 0;

    for (int i = 0; i < metricTypes.length; i++) {
      try {
        final querySnapshot = await _firestore
            .collection('healthMetrics')
            .where('userId', isEqualTo: _currentUserId)
            .where('metricName', isEqualTo: metricTypes[i])
            .orderBy('date', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final latestRecord = querySnapshot.docs.first.data();
          final currentValue = latestRecord['value'].toString();
          final status = calculateHealthStatus(currentValue, normalRanges[i], metricTypes[i]);

          if (status == HealthStatus.normal) {
            normalCount++;
          }
        }
      } catch (e) {
        // If query fails for a specific metric, continue with others
        continue;
      }
    }

    return normalCount;
  }

  // Check if a record exists for today for a specific metric
  Future<bool> hasRecordForToday(String metricName) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final existingRecordQuery = await _firestore
          .collection('healthMetrics')
          .where('userId', isEqualTo: _currentUserId)
          .where('metricName', isEqualTo: metricName)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('date', isLessThan: Timestamp.fromDate(today.add(const Duration(days: 1))))
          .limit(1)
          .get();

      return existingRecordQuery.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking existing record: $e');
    }
  }

  // Add or update health record
  Future<String> saveHealthRecord({
    required String metricName,
    required String value,
    required String unit,
    String? notes,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if a record already exists for this metric today
      final existingRecordQuery = await _firestore
          .collection('healthMetrics')
          .where('userId', isEqualTo: _currentUserId)
          .where('metricName', isEqualTo: metricName)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('date', isLessThan: Timestamp.fromDate(today.add(const Duration(days: 1))))
          .limit(1)
          .get();

      // Prepare record data
      final recordData = {
        'userId': _currentUserId,
        'metricName': metricName,
        'value': value,
        'unit': unit,
        'notes': notes?.isNotEmpty == true ? notes : null,
        'date': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingRecordQuery.docs.isNotEmpty) {
        // Update existing record
        await _firestore
            .collection('healthMetrics')
            .doc(existingRecordQuery.docs.first.id)
            .update(recordData);
        return existingRecordQuery.docs.first.id;
      } else {
        // Create new record
        recordData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await _firestore
            .collection('healthMetrics')
            .add(recordData);
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Error saving health record: $e');
    }
  }

  // Helper method to calculate health status based on value and normal range
  HealthStatus calculateHealthStatus(String value, String normalRange, String metricName) {
    try {
      // Handle blood pressure format (e.g., "120/80")
      if (metricName.toLowerCase().contains('pressure')) {
        final parts = value.split('/');
        if (parts.length == 2) {
          final systolic = double.parse(parts[0]);
          final diastolic = double.parse(parts[1]);

          // Parse normal range for blood pressure (e.g., "90-120/60-80")
          final rangeParts = normalRange.split('/');
          if (rangeParts.length == 2) {
            final systolicRange = rangeParts[0].split('-');
            final diastolicRange = rangeParts[1].split('-');

            if (systolicRange.length == 2 && diastolicRange.length == 2) {
              final minSystolic = double.parse(systolicRange[0]);
              final maxSystolic = double.parse(systolicRange[1]);
              final minDiastolic = double.parse(diastolicRange[0]);
              final maxDiastolic = double.parse(diastolicRange[1]);

              // Check if both values are within normal range
              if (systolic >= minSystolic && systolic <= maxSystolic &&
                  diastolic >= minDiastolic && diastolic <= maxDiastolic) {
                return HealthStatus.normal;
              } else if (systolic > maxSystolic || diastolic > maxDiastolic) {
                return HealthStatus.critical;
              } else {
                return HealthStatus.warning;
              }
            }
          }
        }
      } else {
        // Handle single numeric values
        final numericValue = double.parse(value);

        // Parse normal range (e.g., "70-100")
        final rangeParts = normalRange.split('-');
        if (rangeParts.length == 2) {
          final min = double.parse(rangeParts[0]);
          final max = double.parse(rangeParts[1]);

          if (numericValue >= min && numericValue <= max) {
            return HealthStatus.normal;
          } else if (numericValue < min * 0.8 || numericValue > max * 1.2) {
            return HealthStatus.critical;
          } else {
            return HealthStatus.warning;
          }
        }
      }
    } catch (e) {
      // If parsing fails, default to normal status
    }

    return HealthStatus.normal;
  }

  // Helper method to calculate trend based on current value vs normal range
  HealthTrend calculateTrendFromStatus(String currentValue, String normalRange, String metricName) {
    try {
      // Handle blood pressure format (e.g., "120/80")
      if (metricName.toLowerCase().contains('pressure')) {
        final parts = currentValue.split('/');
        if (parts.length == 2) {
          final systolic = double.parse(parts[0]);
          final diastolic = double.parse(parts[1]);

          // Parse normal range for blood pressure (e.g., "90-120/60-80")
          final rangeParts = normalRange.split('/');
          if (rangeParts.length == 2) {
            final systolicRange = rangeParts[0].split('-');
            final diastolicRange = rangeParts[1].split('-');

            if (systolicRange.length == 2 && diastolicRange.length == 2) {
              final minSystolic = double.parse(systolicRange[0]);
              final maxSystolic = double.parse(systolicRange[1]);
              final minDiastolic = double.parse(diastolicRange[0]);
              final maxDiastolic = double.parse(diastolicRange[1]);

              // Check if both values are within normal range
              final isWithinRange = (systolic >= minSystolic && systolic <= maxSystolic) &&
                                   (diastolic >= minDiastolic && diastolic <= maxDiastolic);

              if (isWithinRange) {
                return HealthTrend.stable; // Within range = stable (flat arrow)
              } else if (systolic > maxSystolic || diastolic > maxDiastolic) {
                return HealthTrend.improving; // Above range = up trend (orange)
              } else {
                return HealthTrend.declining; // Below range = down trend (red)
              }
            }
          }
        }
      } else {
        // Handle single numeric values
        final numericValue = double.parse(currentValue);

        // Parse normal range (e.g., "70-100")
        final rangeParts = normalRange.split('-');
        if (rangeParts.length == 2) {
          final min = double.parse(rangeParts[0]);
          final max = double.parse(rangeParts[1]);

          if (numericValue >= min && numericValue <= max) {
            return HealthTrend.stable; // Within range = stable (flat arrow)
          } else if (numericValue > max) {
            return HealthTrend.improving; // Above range = up trend (orange)
          } else {
            return HealthTrend.declining; // Below range = down trend (red)
          }
        }
      }
    } catch (e) {
      // If parsing fails, default to stable
    }

    return HealthTrend.stable;
  }

  /// Get weight progress data with trend information
  Future<Map<String, dynamic>> getWeightProgressData() async {
    try {
      final latestWeightRecord = await getLatestMetricRecord('Weight');

      if (latestWeightRecord == null) {
        return {
          'currentWeight': 'N/A',
          'trend': HealthTrend.stable,
        };
      }

      final currentWeight = latestWeightRecord['value'].toString();
      final trend = calculateTrendFromStatus(currentWeight, '50-100', 'Weight');

      return {
        'currentWeight': '${currentWeight} kg',
        'trend': trend,
      };

    } catch (e) {
      print('Error getting weight progress data: $e');
      return {
        'currentWeight': 'Error',
        'trend': HealthTrend.stable,
      };
    }
  }

  // Helper method to get time ago string
  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Calculate health score percentage based on normal status metrics
  Future<double> calculateHealthScore() async {
    try {
      // Get count of normal status metrics (out of 6 total metrics)
      final normalCount = await countNormalStatusMetrics();

      // Calculate percentage: (normal metrics / total metrics) * 100
      // Total metrics is always 6 based on countNormalStatusMetrics method
      const totalMetrics = 6;
      return (normalCount / totalMetrics) * 100;

    } catch (e) {
      print('Error calculating health score: $e');
      return 0.0;
    }
  }

  /// Helper method to get normal range for a metric (you can expand this based on your metric definitions)
  // Removed _getNormalRangeForMetric method
}

class HealthRecord {
  final String id;
  final String metricName;
  final String value;
  final DateTime timestamp;
  final String notes;

  HealthRecord({
    required this.id,
    required this.metricName,
    required this.value,
    required this.timestamp,
    required this.notes,
  });
}
