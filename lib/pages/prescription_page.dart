import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_theme.dart';

class PrescriptionPage extends StatefulWidget {
  final String patientName;
  final String patientId;
  final String appointmentId;
  final Map<String, dynamic>? prescriptionData;

  const PrescriptionPage({
    super.key,
    required this.patientName,
    required this.patientId,
    required this.appointmentId,
    this.prescriptionData,
  });

  @override
  State<PrescriptionPage> createState() => _PrescriptionPageState();
}

class _PrescriptionPageState extends State<PrescriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, dynamic>> _medicines = [];
  String _patientName = 'Loading...';
  String _patientGender = '';
  String _patientAge = '';
  String _patientWeight = '';

  @override
  void initState() {
    super.initState();
    
    // If we have prescription data, load it
    if (widget.prescriptionData != null) {
      final data = widget.prescriptionData!;
      _symptomsController.text = data['symptoms'] ?? '';
      _notesController.text = data['notes'] ?? '';
      
      // Clear any existing medicines
      _medicines.clear();
      
      // Add medicines from the prescription data
      if (data['medications'] != null) {
        for (var med in data['medications']) {
          _medicines.add({
            'name': TextEditingController(text: med['name'] ?? ''),
            'dosage': TextEditingController(text: med['dosage'] ?? ''),
            'duration': TextEditingController(text: med['duration'] ?? ''),
            'morning': med['morning'] ?? false,
            'afternoon': med['afternoon'] ?? false,
            'evening': med['evening'] ?? false,
            'night': med['night'] ?? false,
            'isBeforeFood': med['beforeFood'] ?? false,
          });
        }
      }
    } else {
      // Add one empty medicine field by default for new prescriptions
      _addMedicine();
    }
    
    _fetchPatientInfo();
  }

  Future<void> _fetchPatientInfo() async {
    try {
      // First get the appointment to get the patient ID
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();
          
      if (appointmentDoc.exists) {
        final appointment = appointmentDoc.data() as Map<String, dynamic>?;
        final patientId = appointment?['userId'];
        
        if (patientId != null) {
          // Then get the patient's details
          final patientDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .get();
              
          if (patientDoc.exists) {
            final patientData = patientDoc.data() as Map<String, dynamic>?;
            if (mounted) {
              setState(() {
                _patientName = patientData?['name']?.toString() ?? 'N/A';
                final gender = patientData?['gender']?.toString() ?? '';
                _patientGender = gender.isNotEmpty 
                    ? '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}'
                    : 'N/A';
                _patientAge = patientData?['age']?.toString() ?? 'N/A';
                _patientWeight = patientData?['weight']?.toString() ?? 'N/A';
                if (_patientWeight != 'N/A') {
                  _patientWeight += ' kg';
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _patientName = 'Error loading patient';
          _patientGender = 'Error';
          _patientAge = 'Error';
          _patientWeight = 'Error';
        });
      }
      debugPrint('Error fetching patient info: $e');
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addMedicine() {
    setState(() {
      _medicines.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'duration': TextEditingController(),
        'isBeforeFood': true,
        'morning': false,
        'afternoon': false,
        'evening': false,
        'night': false,
      });
    });
  }

  void _removeMedicine(int index) {
    setState(() {
      _medicines.removeAt(index);
    });
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save prescriptions')),
        );
      }
      return;
    }

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Prepare prescription data
      final prescriptionData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': user.uid,
        'appointmentId': widget.appointmentId,
        'date': FieldValue.serverTimestamp(),
        'symptoms': _symptomsController.text.trim(),
        'notes': _notesController.text.trim(),
        'medications': _medicines.map((medicine) => ({
              'name': medicine['name'].text.trim(),
              'dosage': medicine['dosage']?.text?.trim() ?? '',
              'duration': medicine['duration']?.text?.trim() ?? '',
              'morning': medicine['morning'] ?? false,
              'afternoon': medicine['afternoon'] ?? false,
              'evening': medicine['evening'] ?? false,
              'night': medicine['night'] ?? false,
              'beforeFood': medicine['isBeforeFood'] ?? false,
              'afterFood': !(medicine['isBeforeFood'] ?? false),
            })).toList(),
        'createdAt': widget.prescriptionData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save or update in Firestore
      if (widget.prescriptionData != null) {
        // Update existing prescription
        await FirebaseFirestore.instance
            .collection('prescription')
            .doc(widget.prescriptionData!['id'])
            .update(prescriptionData);
      } else {
        // Create new prescription
        await FirebaseFirestore.instance
            .collection('prescription')
            .add(prescriptionData);
            
        // Update appointment status only for new prescriptions
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .update({
              'status': 'completed',
              'hasPrescription': true,
            });
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.prescriptionData != null 
                ? 'Prescription updated successfully' 
                : 'Prescription saved successfully'
            ),
          ),
        );
        Navigator.pop(context); // Go back to previous screen
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error ${widget.prescriptionData != null ? 'updating' : 'saving'} prescription: ${e.message}'
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred')),
        );
      }
    }
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _notesController.dispose();
    for (var medicine in _medicines) {
      medicine['name'].dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(PrescriptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appointmentId != oldWidget.appointmentId) {
      _fetchPatientInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpdate = widget.prescriptionData != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isUpdate ? 'Update Prescription' : 'Create Prescription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor.withOpacity(0.5),
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Name', _patientName, Icons.person_outline),
                      const Divider(height: 24, thickness: 0.5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow('Gender', _patientGender, Icons.people_outline),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoRow('Age', _patientAge, Icons.cake_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Weight', _patientWeight, Icons.monitor_weight_outlined),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Symptoms
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Text(
                      'Symptoms',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextFormField(
                    controller: _symptomsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter patient symptoms...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    style: theme.textTheme.bodyLarge,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter symptoms';
                      }
                      return null;
                    },
                  ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Medicines header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Medicines',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add Medicine',
                  ),
                ],
              ),
              
              // Medicine list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _medicines.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Medicine name and delete button
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _medicines[index]['name'],
                                  decoration: const InputDecoration(
                                    labelText: 'Medicine Name',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_medicines.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeMedicine(index),
                                ),
                            ],
                          ),
                          
                          
                          const SizedBox(height: 12),
                             // Dosage
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0, right: 8.0),
                                child: Text(
                                  'Dosage:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _medicines[index]['dosage'],
                                  decoration: const InputDecoration(
                                    hintText: 'e.g., 1 tablet, 5ml, 10mg',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Dosage Duration
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0, right: 8.0),
                                child: Text(
                                  'Dosage Duration (Days):',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _medicines[index]['duration'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g., 5, 7, 10',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),

                          
                          
                       
                          
                          // Before/After food toggle
                          Row(
                            children: [
                               Text('Timing:'),
                              const SizedBox(width: 8),
                              ToggleButtons(
                                isSelected: [
                                  _medicines[index]['isBeforeFood'],
                                  !_medicines[index]['isBeforeFood']
                                ],
                                onPressed: (int buttonIndex) {
                                  setState(() {
                                    _medicines[index]['isBeforeFood'] = buttonIndex == 0;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text('Before Food'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Text('After Food'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          // Dosage timings
                          Text(
                            'Dosage Times:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Dosage times grid
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // First row with Morning and Afternoon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildDosageTimeCheckbox(
                                        context: context,
                                        label: 'Morning',
                                        value: _medicines[index]['morning'],
                                        onChanged: (value) {
                                          setState(() {
                                            _medicines[index]['morning'] = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildDosageTimeCheckbox(
                                        context: context,
                                        label: 'Afternoon',
                                        value: _medicines[index]['afternoon'],
                                        onChanged: (value) {
                                          setState(() {
                                            _medicines[index]['afternoon'] = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Second row with Evening and Night
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildDosageTimeCheckbox(
                                        context: context,
                                        label: 'Evening',
                                        value: _medicines[index]['evening'] ?? false,
                                        onChanged: (value) {
                                          setState(() {
                                            _medicines[index]['evening'] = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildDosageTimeCheckbox(
                                        context: context,
                                        label: 'Night',
                                        value: _medicines[index]['night'],
                                        onChanged: (value) {
                                          setState(() {
                                            _medicines[index]['night'] = value ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Save button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _savePrescription,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save Prescription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDosageTimeCheckbox({
    required BuildContext context,
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Text(label),
      ],
    );
  }
}
