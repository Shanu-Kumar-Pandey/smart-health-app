import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../app_theme.dart';

class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _prescriptions = [];
  final Map<String, String> _doctorNames = {}; // Cache for doctor names
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  // Future<void> _generateAndSharePdf(Map<String, dynamic> prescription) async {
  //   try {
  //     // Create a PDF document
  //     final pdf = pw.Document();
      
  //     // Get doctor's name
  //     final doctorId = prescription['doctorId']?.toString();
  //     String doctorName = 'Dr. Doctor';
  //     if (doctorId != null) {
  //       doctorName = 'Dr. ${await _getDoctorName(doctorId)}';
  //     }
      
  //     // Format date
  //     final date = prescription['date'] != null
  //         ? DateFormat('MMMM d, y').format(
  //             prescription['date'] is Timestamp 
  //                 ? (prescription['date'] as Timestamp).toDate()
  //                 : prescription['date'] as DateTime
  //           )
  //         : 'No date';
      
  //     // Add page to the PDF
  //     pdf.addPage(
  //       pw.Page(
  //         build: (pw.Context context) {
  //           return pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.start,
  //             children: [
  //               // Header
  //               pw.Header(
  //                 level: 0,
  //                 child: pw.Text('PRESCRIPTION', 
  //                   style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
  //               ),
  //               pw.SizedBox(height: 20),
                
  //               // Doctor and Date
  //               pw.Row(
  //                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                     children: [
  //                       pw.Text('Prescribed by:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                       pw.Text(doctorName),
  //                     ],
  //                   ),
  //                   pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.end,
  //                     children: [
  //                       pw.Text('Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                       pw.Text(date),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //               pw.Divider(),
                
  //               // Patient Info
  //               pw.Text('Patient:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //               pw.Text(_auth.currentUser?.displayName ?? 'Patient', style: const pw.TextStyle(fontSize: 14)),
  //               pw.SizedBox(height: 10),
                
  //               // Symptoms
  //               if (prescription['symptoms']?.toString().isNotEmpty ?? false)
  //                 pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Text('Symptoms:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     pw.Text(prescription['symptoms'].toString()),
  //                     pw.SizedBox(height: 10),
  //                   ],
  //                 ),
                
  //               // Notes
  //               if (prescription['notes']?.toString().isNotEmpty ?? false)
  //                 pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //                     pw.Text(prescription['notes'].toString()),
  //                     pw.SizedBox(height: 10),
  //                   ],
  //                 ),
                
  //               // Medications
  //               pw.Text('Medications:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  //               pw.SizedBox(height: 5),
  //               ...(prescription['medications'] as List<dynamic>?)?.map((med) {
  //                 final timeSlots = <String>[];
  //                 if (med['morning'] == true) timeSlots.add('Morning');
  //                 if (med['afternoon'] == true) timeSlots.add('Afternoon');
  //                 if (med['evening'] == true) timeSlots.add('Evening');
  //                 if (med['night'] == true) timeSlots.add('Night');
                  
  //                 return pw.Container(
  //                   margin: const pw.EdgeInsets.only(bottom: 10),
  //                   child: pw.Column(
  //                     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                     children: [
  //                       pw.Text(
  //                         '• ${med['name']} (${med['dosage'] ?? ''})',
  //                         style:pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                       ),
  //                       if (timeSlots.isNotEmpty)
  //                         pw.Text('  Time: ${timeSlots.join(', ')}'),
  //                       if (med['duration']?.toString().isNotEmpty ?? false)
  //                         pw.Text('  Duration: ${med['duration']} days'),
  //                       pw.Text('  Take ${med['beforeFood'] == true ? 'before' : 'after'} food'),
  //                     ],
  //                   ),
  //                 );
  //               }).toList() ?? [],
                
  //               // Footer
  //               pw.Spacer(),
  //               pw.Divider(),
  //               pw.Text('This is a computer-generated prescription', 
  //                 style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
  //             ],
  //           );
  //         },
  //       ),
  //     );

  //     // Save the PDF to a temporary file
  //     final output = await getTemporaryDirectory();
  //     final file = File('${output.path}/prescription_${DateTime.now().millisecondsSinceEpoch}.pdf');
  //     await file.writeAsBytes(await pdf.save());
      
  //     // Open the PDF file
  //     await OpenFile.open(file.path);
      
  //   } catch (e) {
  //     debugPrint('Error generating PDF: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error generating PDF: $e')),
  //       );
  //     }
  //   }
  // }

  
Future<void> _generateAndSharePdf(Map<String, dynamic> prescription) async {
  try {
    final pdf = pw.Document();
    
    // Debug: Print the entire prescription data
    debugPrint('=== PRESCRIPTION DATA ===');
    debugPrint(prescription.toString());
    debugPrint('========================');

    // Get doctor's details
    final doctorId = prescription['doctorId']?.toString();
    debugPrint('Doctor ID: $doctorId');
    
    String doctorName = 'Dr. Doctor';
    String specialization = 'g';
    String licenseNumber = 'X';
    String clinicName = 'Clinic Name';
    String clinicAddress = '123 Health Street, City, Country';
    String phoneNumber = '+1 234 567 890';
    String experience = '';
    String qualification = '';

    if (doctorId != null) {
      doctorName = 'Dr. ${await _getDoctorName(doctorId)}';
      debugPrint('Fetching doctor details for ID: $doctorId');
      final doctorDetails = await _getDoctorDetails(doctorId);
      debugPrint('Doctor details: ${doctorDetails?.toString() ?? 'null'}');
      
      if (doctorDetails != null) {
        specialization = doctorDetails['specialization'] ?? 'General ';
        licenseNumber = doctorDetails['licenseNumber'] ?? 'XXXXXX';
        clinicName = doctorDetails['clinicName'] ?? 'Clinic Name';
        clinicAddress = doctorDetails['clinicAddress'] ?? '123 Health Street, City, Country';
        phoneNumber = doctorDetails['phoneNumber'] ?? '+1 234 567 890';
        experience = doctorDetails['experience'] ?? '';
        qualification = doctorDetails['qualification'] ?? '';
        
        // Debug: Print all doctor details
        debugPrint('\n=== DOCTOR DETAILS ===');
        debugPrint('Name: $doctorName');
        debugPrint('Specialization: $specialization');
        debugPrint('License: $licenseNumber');
        debugPrint('Clinic: $clinicName');
        debugPrint('Address: $clinicAddress');
        debugPrint('Phone: $phoneNumber');
        debugPrint('Experience: $experience');
        debugPrint('Qualification: $qualification');
        debugPrint('=====================\n');
      } else {
        debugPrint('No doctor details found for ID: $doctorId');
      }
    }

    // Get patient details
    String patientName = _auth.currentUser?.displayName ?? 'Patient Name';
    String age = '';
    String gender = '';
    final userId = _auth.currentUser?.uid;
    debugPrint('Current User ID: $userId');
    
    if (userId != null) {
      debugPrint('Fetching patient details for user ID: $userId');
      final patientDetails = await _getPatientDetails(userId);
      debugPrint('Patient details: ${patientDetails?.toString() ?? 'null'}');
      
      if (patientDetails != null) {
        patientName = patientDetails['name'] ?? patientName;
        age = patientDetails['age']?.toString() ?? '';
        gender = patientDetails['gender']?.toString() ?? '';
        
        // Debug: Print all patient details
        debugPrint('\n=== PATIENT DETAILS ===');
        debugPrint('Name: $patientName');
        debugPrint('Age: $age');
        debugPrint('Gender: $gender');
        debugPrint('======================\n');
      } else {
        debugPrint('No patient details found for user ID: $userId');
      }
    }

    // Format date
    final date = prescription['date'] != null
        ? DateFormat('MMMM d, y').format(
            prescription['date'] is Timestamp
                ? (prescription['date'] as Timestamp).toDate()
                : prescription['date'] as DateTime)
        : DateFormat('MMMM d, y').format(DateTime.now());

    // Load the image asset first
    final ByteData imageData = await rootBundle.load('assets/Caduceus.jpg');
    final Uint8List imageBytes = imageData.buffer.asUint8List();

    // Add page to the PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo and title
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(
                      pw.MemoryImage(imageBytes),
                      width: 55,
                      height: 55,
                    ),
                    // pw.SizedBox(width: 2),
                    pw.Text(
                      'PRESCRIPTION',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'Date: $date',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Doctor and patient info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Doctor's info
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Prescribed By:',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(doctorName),
                          if (qualification.isNotEmpty) pw.Text('Qualification: $qualification'),
                          if (specialization.isNotEmpty) pw.Text('Specialization: $specialization'),
                         
                          pw.Text('License: $licenseNumber'),
                          pw.SizedBox(height: 10),
                          if (clinicName.isNotEmpty) pw.Text('Clinic: $clinicName'),
                          if (clinicAddress.isNotEmpty) pw.Text('Address: $clinicAddress'),
                          if (phoneNumber.isNotEmpty) pw.Text('Phone: $phoneNumber'),
                        ],
                      ),
                    ),

                    // Patient info
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Patient:',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(patientName),
                          if (age.isNotEmpty) pw.Text('Age: $age'),
                          if (gender.isNotEmpty) pw.Text('Gender: ${gender[0].toUpperCase()}${gender.substring(1)}'),
                          
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Divider(),
                pw.SizedBox(height: 20),

                // Rx symbol and medications
                // pw.Center(
                //   child: pw.Text('℞', style: pw.TextStyle(fontSize: 40)),
                // ),
                // pw.SizedBox(height: 20),

                // Medications table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Table header
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text('Medicine',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text('Dose',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text('Frequency',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8.0),
                          child: pw.Text('Duration',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Medication rows
                    ...(prescription['medications'] as List<dynamic>?)?.map((med) {
                      final timeSlots = <String>[];
                      if (med['morning'] == true) timeSlots.add('Morning');
                      if (med['afternoon'] == true) timeSlots.add('Afternoon');
                      if (med['evening'] == true) timeSlots.add('Evening');
                      if (med['night'] == true) timeSlots.add('Night');

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(med['name']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(med['dosage']?.toString() ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text(timeSlots.join(', ')),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8.0),
                            child: pw.Text('${med['duration'] ?? ''} days'),
                          ),
                        ],
                      );
                    }).toList() ?? [],
                  ],
                ),

                pw.SizedBox(height: 30),

                // Doctor's signature
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(doctorName,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        if (qualification.isNotEmpty || specialization.isNotEmpty)
                          pw.Text([
                            if (qualification.isNotEmpty) qualification,
                            if (specialization.isNotEmpty) specialization
                          ].join(', ')),
                        if (licenseNumber.isNotEmpty) pw.Text('License: $licenseNumber'),
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 20),
                          width: 150,
                          height: 1,
                          color: PdfColors.black,
                        ),
                        pw.Text('Signature & Stamp'),
                      ],
                    ),
                  ],
                ),

                // Footer note
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    'This is a computer-generated prescription. No physical signature is required.',
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save the PDF to a temporary file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/prescription_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    // Open the PDF file
    await OpenFile.open(file.path);
    
  } catch (e) {
    debugPrint('Error generating PDF: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }
}
  // Fetch doctor's details from document_verification collection
Future<Map<String, dynamic>?> _getDoctorDetails(String userId) async {
  try {
    debugPrint('Querying Firestore for doctor with userId: $userId');
    
    // Query the document_verification collection where userId field matches
    final querySnapshot = await _firestore
        .collection('document_verification')
        .where('userId', isEqualTo: userId)
        .limit(1)  // Since we expect only one document per doctor
        .get();

    debugPrint('Found ${querySnapshot.docs.length} matching documents');
    
    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      debugPrint('Doctor document data: ${data.toString()}');
      return data;
    } else {
      debugPrint('No document found for doctor with userId: $userId');
      return null;
    }
  } catch (e) {
    debugPrint('Error fetching doctor details: $e');
    return null;
  }
}

  // Fetch patient details from users collection
  Future<Map<String, dynamic>?> _getPatientDetails(String userId) async {
    try {
      debugPrint('Querying Firestore for user ID: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      
      debugPrint('User document exists: ${doc.exists}');
      if (doc.exists) {
        final data = doc.data();
        debugPrint('User document data: ${data?.toString() ?? 'null'}');
        return data;
      } else {
        debugPrint('No document found for user ID: $userId');
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching patient details: $e');
      return null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String> _getDoctorName(String doctorId) async {
    // Return from cache if available
    if (_doctorNames.containsKey(doctorId)) {
      return _doctorNames[doctorId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(doctorId).get();
      if (doc.exists) {
        final name = doc.data()?['name']?.toString() ?? 'Doctor';
        _doctorNames[doctorId] = name; // Cache the result
        return name;
      }
      return 'Doctor';
    } catch (e) {
      debugPrint('Error fetching doctor name: $e');
      return 'Doctor';
    }
  }

  Future<void> _loadPrescriptions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }

      // Get prescriptions for the current patient
      final querySnapshot = await _firestore
          .collection('prescription')
          .where('patientId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .get();

      // Process prescriptions
      final prescriptions = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Handle both Timestamp and DateTime cases
        dynamic date = data['date'];
        if (date is Timestamp) {
          date = date.toDate();
        }
        
        prescriptions.add({
          'id': doc.id,
          ...data,
          'date': date,
        });
      }

      setState(() {
        _prescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading prescriptions: $e';
      });
    }
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
          'My Medications',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _prescriptions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medication_rounded,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No medications found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your prescribed medications will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPrescriptions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _prescriptions.length,
                        itemBuilder: (context, index) {
                          return _buildPrescriptionCard(
                            context,
                            _prescriptions[index],
                            isDark,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildPrescriptionCard(
      BuildContext context, Map<String, dynamic> prescription, bool isDark) {
    final theme = Theme.of(context);
    final date = prescription['date'] != null
        ? DateFormat('MMM d, y').format(
            prescription['date'] is Timestamp 
                ? (prescription['date'] as Timestamp).toDate()
                : prescription['date'] as DateTime
          )
        : 'No date';
    final doctorId = prescription['doctorId']?.toString();
    final doctorNameFuture = doctorId != null 
        ? _getDoctorName(doctorId)
        : Future.value('Doctor');
    final symptoms = prescription['symptoms']?.toString() ?? 'No symptoms listed';
    final notes = prescription['notes']?.toString();
    final medications = List<Map<String, dynamic>>.from(
        prescription['medications'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and doctor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FutureBuilder<String>(
                  future: doctorNameFuture,
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? 'Doctor';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dr. $name',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Symptoms
            if (symptoms.isNotEmpty) ..._buildSection(
              context,
              'Symptoms',
              symptoms,
              Icons.medical_services_outlined,
            ),

            // Notes
            if (notes?.isNotEmpty ?? false) ..._buildSection(
              context,
              'Notes',
              notes!,
              Icons.note_outlined,
            ),

            // Medications
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Medications',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // const SizedBox(height: 8),
              ...medications.map((med) => _buildMedicationItem(context, med)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _generateAndSharePdf(prescription),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Download Prescription'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildMedicationItem(
      BuildContext context, Map<String, dynamic> medication) {
    final theme = Theme.of(context);
    final name = medication['name']?.toString() ?? 'Unnamed Medication';
    final dosage = medication['dosage']?.toString();
    final duration = medication['duration']?.toString();
    final beforeFood = medication['beforeFood'] == true;

    // Get time slots
    final timeSlots = <String>[];
    if (medication['morning'] == true) timeSlots.add('Morning');
    if (medication['afternoon'] == true) timeSlots.add('Afternoon');
    if (medication['evening'] == true) timeSlots.add('Evening');
    if (medication['night'] == true) timeSlots.add('Night');

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Dosage
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (dosage != null && dosage.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '• $dosage',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
          
          // Timing
          if (timeSlots.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      timeSlots.join(', '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          
          // Duration
          if (duration != null && duration.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'For $duration Days',
                style: theme.textTheme.bodySmall,
              ),
            ),
          
          // Food timing
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 4),
              Text(
                beforeFood ? 'Take before food' : 'Take after food',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          
        ],
      ),
    );
  }
}
