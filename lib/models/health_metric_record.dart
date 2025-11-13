// class HealthMetricRecord {
//   final String id;
//   final String userId;
//   final DateTime date;  // Date of the record
//   final Map<String, dynamic> metrics; // Map of metric name to value
//   final String? notes;
//   final DateTime timestamp;

//   HealthMetricRecord({
//     required this.id,
//     required this.userId,
//     required this.date,
//     required this.metrics,
//     this.notes,
//     DateTime? timestamp,
//   }) : timestamp = timestamp ?? DateTime.now();

//   // Convert to Map for Firebase
//   Map<String, dynamic> toMap() {
//     return {
//       'userId': userId,
//       'date': date.toIso8601String(),
//       'metrics': metrics,
//       'notes': notes,
//       'timestamp': timestamp.toIso8601String(),
//     };
//   }

//   // Create from Firebase document
//   factory HealthMetricRecord.fromMap(String id, Map<String, dynamic> map) {
//     return HealthMetricRecord(
//       id: id,
//       userId: map['userId'] as String,
//       date: DateTime.parse(map['date'] as String),
//       metrics: Map<String, dynamic>.from(map['metrics'] as Map),
//       notes: map['notes'] as String?,
//       timestamp: DateTime.parse(map['timestamp'] as String),
//     );
//   }
// }
