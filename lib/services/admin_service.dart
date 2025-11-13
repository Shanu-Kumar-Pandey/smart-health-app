import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smarthealth/services/doctor_service.dart';
import '../app_theme.dart';

class AdminService {
  final DoctorService _doctorService = DoctorService();

  Future<void> approveVerification(
    BuildContext context, 
    String userId,
    VoidCallback onSuccess,
  ) async {
    try {
      await _doctorService.updateDoctorVerificationStatus(userId, 'true');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor verification approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> rejectVerification(
    BuildContext context, 
    String userId,
    VoidCallback onSuccess,
  ) async {
    try {
      await _doctorService.updateDoctorVerificationStatus(userId, 'rejected');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor verification rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showDoctorDetails(
    BuildContext context, 
    Map<String, dynamic> doctorData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Doctor Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${doctorData['name'] ?? 'N/A'}'),
              Text('Email: ${doctorData['email'] ?? 'N/A'}'),
              Text('Role: ${doctorData['role'] ?? 'N/A'}'),
              Text('Verified: ${doctorData['isVerified'] ?? 'N/A'}'),
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

  Stream<List<Map<String, dynamic>>> getAllDoctorsStream() {
    // Get all doctors from users collection
    final doctorsStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return doctorsStream.asyncMap((snapshot) async {
      final List<Map<String, dynamic>> result = [];
      
      for (var doc in snapshot.docs) {
        final doctorData = doc.data();
        final isVerified = doctorData['isVerified'] as String? ?? 'false';
        
        if (isVerified == 'false') {
          // For unverified doctors, use data from users collection
          result.add({
            ...doctorData,
            'id': doc.id,
            'docId': doc.id,
          });
        } else {
          // For verified doctors, get their verification data
          final verificationQuery = await FirebaseFirestore.instance
              .collection('document_verification')
              .where('userId', isEqualTo: doc.id)
              .where('status', whereIn: ['approved', 'rejected','pending'])
              .orderBy('reviewedAt', descending: true)
              .limit(1)
              .get();

          if (verificationQuery.docs.isNotEmpty) {
            final verificationData = verificationQuery.docs.first.data();
            result.add({
              ...verificationData,
              'id': verificationQuery.docs.first.id,
              'docId': verificationQuery.docs.first.id,
              'userData': doctorData,
            });
          } else {
            // Fallback to user data if no verification record found
            result.add({
              ...doctorData,
              'id': doc.id,
              'docId': doc.id,
            });
          }
        }
      }
      
      return result;
    });
  }

  // Get total count of doctors from users collection
  Stream<int> getTotalDoctorsCount() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get count of doctors by verification status
  // Stream<int> getDoctorsCountByStatus(String status) {
  //   if (status == 'all') {
  //     return getTotalDoctorsCount();
  //   }

  //   return FirebaseFirestore.instance
  //       .collection('users')
  //       .where('role', isEqualTo: 'doctor')
  //       .where('isVerified', isEqualTo: status)
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs.length);
  // }

    Stream<int> getTotalPatientCount() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  
    Stream<int> getTotalAppointmentCount() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get stream of all patients from users collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getPatientsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Block user functionality using Firebase Auth's built-in disable through HTTP API
  Future<void> blockUser(
    BuildContext context,
    String doctorEmail,
    VoidCallback onSuccess,
  ) async {
    try {
      // Get current user's ID token for authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Admin not authenticated')),
          );
        }
        onSuccess(); // Always call callback to reset loading state
        return;
      }

      final idToken = await currentUser.getIdToken();

      // Call backend HTTP endpoint to disable user account using Firebase Auth's built-in disable
      final response = await http.post(
        Uri.parse('http://192.168.1.6:3000/disableUserAccount'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userEmail': doctorEmail,
          'idToken': idToken,
        }),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$doctorEmail has been blocked successfully'),
              backgroundColor: Colors.green,
            ),
          );
          onSuccess();
        }
      } else {
        final error = jsonDecode(response.body);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error['error'] ?? 'Failed to block user'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        onSuccess(); // Always call callback to reset loading state
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error blocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      onSuccess(); // Always call callback to reset loading state
    }
  }

  // Unblock user functionality using Firebase Auth's built-in enable through HTTP API
  Future<void> unblockUser(
    BuildContext context,
    String doctorEmail,
    VoidCallback onSuccess,
  ) async {
    try {
      // Get current user's ID token for authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Admin not authenticated')),
          );
        }
        onSuccess(); // Always call callback to reset loading state
        return;
      }

      final idToken = await currentUser.getIdToken();

      // Call backend HTTP endpoint to enable user account using Firebase Auth's built-in enable
      final response = await http.post(
        Uri.parse('http://192.168.1.6:3000/enableUserAccount'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userEmail': doctorEmail,
          'idToken': idToken,
        }),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$doctorEmail has been unblocked successfully'),
              backgroundColor: Colors.green,
            ),
          );
          onSuccess();
        }
      } else {
        final error = jsonDecode(response.body);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error['error'] ?? 'Failed to unblock user'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        onSuccess(); // Always call callback to reset loading state
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unblocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      onSuccess(); // Always call callback to reset loading state
    }
  }

  // Enhanced date formatting utility method
  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Get the differences in various units
    final minutes = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;
    final weeks = (days / 7).floor();
    final months = (days / 30).floor(); // Approximate months
    final years = (days / 365).floor();

    // Less than 1 hour
    if (minutes < 60) {
      if (minutes < 1) {
        return 'Just now';
      } else if (minutes == 1) {
        return '1 minute ago';
      } else {
        return '$minutes minutes ago';
      }
    }

    // Less than 24 hours (but more than 1 hour)
    else if (hours < 24) {
      if (hours == 1) {
        return '1 hour ago';
      } else {
        return '$hours hours ago';
      }
    }

    // 1 day
    else if (days == 1) {
      return 'Yesterday';
    }

    // 2-6 days
    else if (days < 7) {
      return '$days days ago';
    }

    // 1-4 weeks
    else if (weeks < 5) {
      if (weeks == 1) {
        return '1 week ago';
      } else {
        return '$weeks weeks ago';
      }
    }

    // 1-12 months
    else if (months < 12) {
      if (months == 1) {
        return '1 month ago';
      } else {
        return '$months months ago';
      }
    }

    // 1+ years
    else {
      if (years == 1) {
        return '1 year ago';
      } else {
        return '$years years ago';
      }
    }
  }

  // Analytics Data Streams
  Stream<int> getTotalUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getActiveUsersStream() {
    //  users active in the last 7 days
    
    return FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getTotalAppointmentsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getTotalReviewsStream() {
    return FirebaseFirestore.instance
        .collection('ratings')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Utility functions for analytics
  DateTime? getTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return null;
  }

  String formatActivityTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Stream<List<Map<String, dynamic>>> getTopDoctorsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .asyncMap((snapshot) async {
          final Map<String, int> doctorCounts = {};

          for (var doc in snapshot.docs) {
            final doctorId = doc.data()['doctorId'] as String?;
            if (doctorId != null) {
              doctorCounts[doctorId] = (doctorCounts[doctorId] ?? 0) + 1;
            }
          }

          // Sort by count descending and take top 3
          final sortedDoctors = doctorCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Fetch names for top 3
          final topDoctors = <Map<String, dynamic>>[];
          for (var entry in sortedDoctors.take(3)) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(entry.key)
                  .get();
              final name = userDoc.data()?['name'] as String? ?? 'Unknown Doctor';
              topDoctors.add({
                'name': name,
                'count': entry.value,
              });
            } catch (e) {
              topDoctors.add({
                'name': 'Unknown Doctor',
                'count': entry.value,
              });
            }
          }

          return topDoctors;
        });
  }

  Stream<List<Map<String, dynamic>>> getUserDistributionStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
          final roleCounts = <String, int>{};
          int totalUsers = snapshot.docs.length;

          for (var doc in snapshot.docs) {
            final role = doc.data()['role'] as String? ?? 'patient';
            roleCounts[role] = (roleCounts[role] ?? 0) + 1;
          }

          return roleCounts.entries.map((entry) {
            final percentage = totalUsers > 0 ? (entry.value / totalUsers * 100) : 0.0;
            return {
              'role': entry.key,
              'count': entry.value,
              'percentage': percentage,
            };
          }).toList();
        });
  }

  Stream<Map<String, int>> getUserGrowthStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final thisWeek = today.subtract(Duration(days: today.weekday - 1));
          final thisMonth = DateTime(now.year, now.month, 1);

          int todayCount = 0;
          int thisWeekCount = 0;
          int thisMonthCount = 0;

          for (var doc in snapshot.docs) {
            final createdAt = doc.data()['createdAt'];
            if (createdAt != null) {
              DateTime? createdDate;

              // Handle both Timestamp and DateTime
              if (createdAt is Timestamp) {
                createdDate = createdAt.toDate();
              } else if (createdAt is DateTime) {
                createdDate = createdAt;
              }

              if (createdDate != null) {
                // Check if created today
                if (createdDate.year == today.year &&
                    createdDate.month == today.month &&
                    createdDate.day == today.day) {
                  todayCount++;
                }

                // Check if created this week
                if (createdDate.isAfter(thisWeek.subtract(const Duration(days: 1))) &&
                    createdDate.isBefore(today.add(const Duration(days: 1)))) {
                  thisWeekCount++;
                }

                // Check if created this month
                if (createdDate.year == thisMonth.year &&
                    createdDate.month == thisMonth.month) {
                  thisMonthCount++;
                }
              }
            }
          }

          return {
            'today': todayCount,
            'thisWeek': thisWeekCount,
            'thisMonth': thisMonthCount,
          };
        });
  }

  Stream<List<Map<String, double>>> getAppointmentActivityStream(String period) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final Map<String, int> groupedData = {};

          for (var doc in snapshot.docs) {
            final createdAt = doc.data()['createdAt'];
            if (createdAt != null) {
              DateTime? date = getTimestamp(createdAt);
              if (date != null) {
                String key;
                if (period == 'Day') {
                  key = date.hour.toString(); // 0-23
                } else if (period == 'Month') {
                  key = date.day.toString(); // 1-31
                } else if (period == 'Week') {
                  key = date.weekday.toString(); // 1-7
                } else {
                  key = date.month.toString(); // 1-12
                }
                groupedData[key] = (groupedData[key] ?? 0) + 1;
              }
            }
          }

          // Group into 6 ranges
          final Map<int, int> rangeData = {};
          if (period == 'Day') {
            // 6 ranges: 0-3, 4-7, 8-11, 12-15, 16-19, 20-23
            final ranges = [0, 4, 8, 12, 16, 20];
            for (int i = 0; i < ranges.length; i++) {
              int start = ranges[i];
              int end = (i == ranges.length - 1) ? 23 : ranges[i + 1] - 1;
              int count = 0;
              for (int h = start; h <= end; h++) {
                count += groupedData[h.toString()] ?? 0;
              }
              rangeData[i] = count;
            }
          } else if (period == 'Month') {
            // 6 ranges: 1-5, 6-10, 11-15, 16-20, 21-25, 26-31
            final ranges = [1, 6, 11, 16, 21, 26];
            for (int i = 0; i < ranges.length; i++) {
              int start = ranges[i];
              int end = (i == ranges.length - 1) ? 31 : ranges[i + 1] - 1;
              int count = 0;
              for (int d = start; d <= end; d++) {
                count += groupedData[d.toString()] ?? 0;
              }
              rangeData[i] = count;
            }
          } else if (period == 'Week') {
            // 6 ranges: 1, 2, 3, 4, 5, 6-7
            for (int i = 0; i < 6; i++) {
              int count = 0;
              if (i < 5) {
                int day = i + 1;
                count += groupedData[day.toString()] ?? 0;
              } else {
                count += groupedData['6'] ?? 0;
                count += groupedData['7'] ?? 0;
              }
              rangeData[i] = count;
            }
          } else {
            // 6 ranges: 1-2, 3-4, 5-6, 7-8, 9-10, 11-12
            final ranges = [1, 3, 5, 7, 9, 11];
            for (int i = 0; i < ranges.length; i++) {
              int start = ranges[i];
              int end = (i == ranges.length - 1) ? 12 : ranges[i + 1] - 1;
              int count = 0;
              for (int m = start; m <= end; m++) {
                count += groupedData[m.toString()] ?? 0;
              }
              rangeData[i] = count;
            }
          }

          List<Map<String, double>> data = [];
          for (int i = 0; i < rangeData.length; i++) {
            data.add({'x': (i + 1).toDouble(), 'y': rangeData[i]!.toDouble()});
          }
          return data;
        });
  }

  Future<List<Map<String, dynamic>>> getCombinedRecentActivities() async {
    final activities = <Map<String, dynamic>>[];

    try {
      // Get recent user registrations
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final name = data['name'] as String? ?? 'Unknown User';
        final role = data['role'] as String? ?? 'patient';

        if (createdAt != null) {
          final timestamp = getTimestamp(createdAt);
          if (timestamp != null) {
            activities.add({
              'description': 'New $role registered: $name',
              'time': formatActivityTime(timestamp),
              'icon': role == 'doctor' ? Icons.local_hospital_rounded : Icons.person_rounded,
              'color': AppTheme.primaryBlue,
              'timestamp': timestamp,
            });
          }
        }
      }

      // Get recent appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];

        if (createdAt != null) {
          final timestamp = getTimestamp(createdAt);
          if (timestamp != null) {
            activities.add({
              'description': 'New appointment scheduled',
              'time': formatActivityTime(timestamp),
              'icon': Icons.calendar_today_rounded,
              'color': AppTheme.warningOrange,
              'timestamp': timestamp,
            });
          }
        }
      }

      // Get recent reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final rating = data['rating'] as num? ?? 0;

        if (createdAt != null) {
          final timestamp = getTimestamp(createdAt);
          if (timestamp != null) {
            activities.add({
              'description': '${rating.toInt()}-star review submitted',
              'time': formatActivityTime(timestamp),
              'icon': Icons.star_rounded,
              'color': AppTheme.warningOrange,
              'timestamp': timestamp,
            });
          }
        }
      }

      // Get recent document verifications
      final verificationsSnapshot = await FirebaseFirestore.instance
          .collection('document_verification')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (var doc in verificationsSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final status = data['status'] as String? ?? 'pending';
        final userName = data['userName'] as String? ?? 'Unknown User';

        if (createdAt != null) {
          final timestamp = getTimestamp(createdAt);
          if (timestamp != null) {
            activities.add({
              'description': 'Document verification $status: $userName',
              'time': formatActivityTime(timestamp),
              'icon': Icons.verified_user_rounded,
              'color': status == 'approved' ? AppTheme.successGreen : AppTheme.warningOrange,
              'timestamp': timestamp,
            });
          }
        }
      }

      // Sort by timestamp (most recent first)
      activities.sort((a, b) {
        final timestampA = a['timestamp'] as DateTime?;
        final timestampB = b['timestamp'] as DateTime?;
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        return timestampB.compareTo(timestampA);
      });

      return activities;
    } catch (e) {
      print('Error fetching recent activities: $e');
      return [];
    }
  }
}
