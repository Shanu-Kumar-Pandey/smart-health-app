import 'package:flutter/material.dart';
import '../services/doctor_service.dart';
import 'package:intl/intl.dart';

class ConsultationTimingDialog extends StatefulWidget {
  final DoctorService doctorService;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final int initialConsultationDuration;
  final int initialGapDuration;

  const ConsultationTimingDialog({
    Key? key,
    required this.doctorService,
    this.initialStartTime,
    this.initialEndTime,
    this.initialConsultationDuration = 30,
    this.initialGapDuration = 15,
  }) : super(key: key);

  @override
  _ConsultationTimingDialogState createState() => _ConsultationTimingDialogState();
}

class _ConsultationTimingDialogState extends State<ConsultationTimingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _consultationDuration; // in minutes
  late int _gapDuration; // in minutes
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = widget.initialEndTime ?? const TimeOfDay(hour: 17, minute: 0);
    _consultationDuration = widget.initialConsultationDuration;
    _gapDuration = widget.initialGapDuration;
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      try {
        final result = await widget.doctorService.saveConsultationTimings(
          startTime: _startTime,
          endTime: _endTime,
          consultationDuration: _consultationDuration,
          gapDuration: _gapDuration,
        );
        
        if (mounted) {
          // Show success/error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: result['success'] as bool ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          
          // Close dialog only on success
          if (result['success'] as bool) {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving timings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Consultation Timings'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please set your consultation timings:'),
              const SizedBox(height: 20),
              
              // Start Time
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_formatTime(_startTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, true),
              ),
              
              // End Time
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_formatTime(_endTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () => _selectTime(context, false),
              ),
              
               const SizedBox(height: 20),
              // Consultation Duration
              DropdownButtonFormField<int>(
                value: _consultationDuration,
                decoration: const InputDecoration(
                  labelText: 'Consultation Duration (minutes)',
                ),
                items: [15, 20, 30, 45, 60]
                    .map((duration) => DropdownMenuItem(
                          value: duration,
                          child: Text('$duration minutes'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _consultationDuration = value);
                  }
                },
                validator: (value) {
                  if (value == null || value <= 0) {
                    return 'Please select a valid duration';
                  }
                  return null;
                },
              ),
               const SizedBox(height: 20),
              
              // Gap Between Appointments
              DropdownButtonFormField<int>(
                value: _gapDuration,
                decoration: const InputDecoration(
                  labelText: 'Gap Between Appointments (minutes)',
                ),
                items: [5, 10, 15, 20, 30]
                    .map((gap) => DropdownMenuItem(
                          value: gap,
                          child: Text('$gap minutes'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gapDuration = value);
                  }
                },
                validator: (value) {
                  if (value == null || value < 0) {
                    return 'Please select a valid gap duration';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
