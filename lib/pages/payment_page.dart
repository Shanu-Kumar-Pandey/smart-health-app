import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/payment_service.dart';
import '../models/payment_method.dart';
import '../app_theme.dart';

enum PaymentMethodType { debitCard, creditCard }

class PaymentPage extends StatefulWidget {
  final String doctorName;
  final String appointmentDate;
  final String appointmentTime;
  final String reason;
  final String fees;
  final String doctorId;

  const PaymentPage({
    super.key,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.reason,
    required this.fees,
    required this.doctorId,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final PaymentService _paymentService = PaymentService();
  PaymentMethodType _selectedPaymentMethod = PaymentMethodType.debitCard;
  bool _isLoading = false;
  bool _savePaymentMethod = false;
  bool _useExistingPaymentMethod = false; // New: Track if user wants to use existing payment method
  List<PaymentMethod> _savedPaymentMethods = []; // New: List of saved payment methods
  PaymentMethod? _selectedExistingPaymentMethod; // New: Selected existing payment method

  // Card form controllers
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPaymentMethods();
  }

  Future<void> _loadSavedPaymentMethods() async {
    try {
      final paymentData = await _paymentService.getUserPaymentMethods();
      final paymentMethods = paymentData.map((data) => PaymentMethod.fromMap(data)).toList();
      setState(() {
        _savedPaymentMethods = paymentMethods;
      });
    } catch (e) {
      debugPrint('Error loading saved payment methods: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appointment Summary Card
            _buildAppointmentSummary(),

            const SizedBox(height: 24),

            // Payment Method Choice
            if (!_useExistingPaymentMethod) _buildPaymentMethodChoice(),

            // Show existing payment methods if selected
            if (_useExistingPaymentMethod) _buildExistingPaymentMethods(),

            const SizedBox(height: 24),

            // Payment Methods (only show if using new payment method)
            if (!_useExistingPaymentMethod) ...[
              Text(
                'Select Payment Method',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method Selection
              _buildPaymentMethodSelection(),

              const SizedBox(height: 24),

              // Card Details Form
              if (_selectedPaymentMethod != PaymentMethodType.debitCard ||
                  _selectedPaymentMethod != PaymentMethodType.creditCard)
                _buildCardDetailsForm(),

              const SizedBox(height: 16),

              // Save Payment Method Checkbox
              _buildSavePaymentCheckbox(),

              const SizedBox(height: 32),

              // Pay Now Button
              _buildPayNowButton(),
            ],

            // Use Selected Payment Button (only show if using existing payment method)
            if (_useExistingPaymentMethod && _selectedExistingPaymentMethod != null)
              _buildUseSelectedPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentSummary() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Appointment Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Doctor:', widget.doctorName),
          _buildSummaryRow('Date:', widget.appointmentDate),
          _buildSummaryRow('Time:', widget.appointmentTime),
          _buildSummaryRow('Reason:', widget.reason),
          _buildSummaryRow('Fees:', widget.fees),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChoice() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Payment Method',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildChoiceCard(
                  icon: Icons.add_card,
                  title: 'Add New',
                  subtitle: 'Enter new payment details',
                  isSelected: !_useExistingPaymentMethod,
                  onTap: () {
                    setState(() {
                      _useExistingPaymentMethod = false;
                      _selectedExistingPaymentMethod = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceCard(
                  icon: Icons.credit_card,
                  title: 'Use Saved',
                  subtitle: 'Select from saved methods',
                  isSelected: _useExistingPaymentMethod,
                  onTap: () {
                    setState(() {
                      _useExistingPaymentMethod = true;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildPaymentMethodCard(
            method: PaymentMethodType.debitCard,
            icon: Icons.credit_card_rounded,
            title: 'Debit Card',
            color: _selectedPaymentMethod == PaymentMethodType.debitCard
                ? AppTheme.primaryBlue
                : Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPaymentMethodCard(
            method: PaymentMethodType.creditCard,
            icon: Icons.credit_card,
            title: 'Credit Card',
            color: _selectedPaymentMethod == PaymentMethodType.creditCard
                ? AppTheme.primaryBlue
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required PaymentMethodType method,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedPaymentMethod == method
                ? color
                : color.withOpacity(0.3),
            width: _selectedPaymentMethod == method ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetailsForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Card Holder Name
          TextFormField(
            controller: _cardHolderNameController,
            decoration: const InputDecoration(
              labelText: 'Card Holder Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_rounded),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter card holder name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Card Number
          TextFormField(
            controller: _cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Card Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card_rounded),
            ),
            keyboardType: TextInputType.number,
            maxLength: 19,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberFormatter(),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter card number';
              }
              if (value.replaceAll(' ', '').length < 13) {
                return 'Please enter valid card number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Expiry Date and CVV Row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryDateController,
                  decoration: const InputDecoration(
                    labelText: 'MM/YY',
                    border: OutlineInputBorder(),
                    hintText: 'MM/YY',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryDateFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    border: OutlineInputBorder(),
                    hintText: '123',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (value.length < 3) {
                      return 'Invalid CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavePaymentCheckbox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _savePaymentMethod,
            onChanged: (value) {
              setState(() {
                _savePaymentMethod = value ?? false;
              });
            },
            activeColor: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save payment method',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  'Your payment details will be saved for future appointments',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayNowButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Pay Now & Book Appointment',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildExistingPaymentMethods() {
    final theme = Theme.of(context);

    if (_savedPaymentMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Saved Payment Methods',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t saved any payment methods yet. Please add a new payment method.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _useExistingPaymentMethod = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add New Payment Method'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _useExistingPaymentMethod = false;
                    _selectedExistingPaymentMethod = null;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Payment Options',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select Payment Method',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _savedPaymentMethods.length,
            itemBuilder: (context, index) {
              final paymentMethod = _savedPaymentMethods[index];
              return _buildExistingPaymentMethodCard(paymentMethod);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExistingPaymentMethodCard(PaymentMethod paymentMethod) {
    final theme = Theme.of(context);
    final isSelected = _selectedExistingPaymentMethod == paymentMethod;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedExistingPaymentMethod = paymentMethod;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : theme.colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? AppTheme.primaryBlue.withOpacity(0.05)
                : theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              // Payment method icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getPaymentMethodColor(paymentMethod.paymentType ?? 'card').withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPaymentMethodIcon(paymentMethod.paymentType ?? 'card'),
                  color: _getPaymentMethodColor(paymentMethod.paymentType ?? 'card'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentMethodColor(paymentMethod.paymentType ?? 'card'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (paymentMethod.paymentType ?? 'CARD').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Card holder name
                    if (paymentMethod.cardHolderName != null)
                      Text(
                        paymentMethod.cardHolderName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    // Masked card number
                    Text(
                      paymentMethod.cardNumber != null
                          ? '**** **** **** ${paymentMethod.cardNumber!.substring(paymentMethod.cardNumber!.length - 4)}'
                          : 'Payment Method',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryBlue,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPaymentMethodColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'credit':
        return Colors.purple;
      case 'debit':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getPaymentMethodIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'credit':
        return Icons.credit_card;
      case 'debit':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Widget _buildUseSelectedPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_selectedExistingPaymentMethod == null || _isLoading) ? null : _processPaymentWithExistingMethod,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Use Selected Payment Method & Book',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Future<void> _processPaymentWithExistingMethod() async {
    if (_selectedExistingPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Book the appointment using the selected payment method
      await _bookAppointment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Appointment booked.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
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

  Future<void> _processPayment() async {
    // Validate form
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Debug: Check if checkbox is ticked and user is authenticated
      debugPrint('Save payment method checkbox: $_savePaymentMethod');
      debugPrint('Current user: ${_firebaseService.currentUser?.uid ?? 'Not authenticated'}');

      // Save payment method if checkbox is ticked
      if (_savePaymentMethod) {
        debugPrint('Attempting to save payment method...');
        try {
          await _savePaymentMethodToFirebase();
          debugPrint('Payment method save completed');
        } catch (e) {
          debugPrint('Payment method save failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment method could not be saved, but appointment will still be booked: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('Payment method save skipped - checkbox not ticked');
      }

      // Book the appointment
      await _bookAppointment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Appointment booked.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
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

  bool _validateForm() {
    if (_cardHolderNameController.text.isEmpty ||
        _cardNumberController.text.replaceAll(' ', '').length < 13 ||
        _expiryDateController.text.isEmpty ||
        _cvvController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all card details'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _savePaymentMethodToFirebase() async {
    try {
      debugPrint('Starting save payment method process...');

      // Check if user is authenticated
      if (_firebaseService.currentUser == null) {
        debugPrint('ERROR: User not authenticated');
        throw Exception('User not authenticated');
      }

     
      await _firebaseService.savePaymentMethod(
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        expiryDate: _expiryDateController.text,
        cardHolderName: _cardHolderNameController.text,
        paymentType: _selectedPaymentMethod == PaymentMethodType.creditCard
            ? 'credit'
            : 'debit',
      );
    } catch (e) {
      // Handle save payment method error silently for now
      debugPrint('Failed to save payment method: $e');
      debugPrint('Error type: ${e.runtimeType}');
      // Re-throw to show error to user if needed
      throw e;
    }
  }

  Future<void> _bookAppointment() async {
    try {


      // Parse the selected date and time into a proper DateTime object
      DateTime appointmentDateTime = _parseDateTime(widget.appointmentDate, widget.appointmentTime);

      await _firebaseService.addAppointment(
        doctorName: widget.doctorName,
        dateTime: appointmentDateTime, // ✅ FIXED: Use actual selected date/time
        reason: widget.reason,
        fees: widget.fees,
        doctorId: widget.doctorId,
      );
      debugPrint('Appointment booked successfully in Firebase');
    } catch (e) {
      debugPrint('ERROR: Failed to book appointment: $e');
      debugPrint('Error type: ${e.runtimeType}');
      throw Exception('Failed to book appointment: $e');
    }
  }

  // Helper method to parse date and time strings into DateTime
  DateTime _parseDateTime(String dateString, String timeString) {
    try {
      // Parse date (format: "dd/mm/yyyy")
      final dateParts = dateString.split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      // Parse time (format: "hh:mm AM/PM")
      final timeParts = timeString.split(' - ')[0]; // Get start time (e.g., "09:00 AM")
      final timeOnly = timeParts.split(' ')[0]; // Get "09:00"
      final period = timeParts.split(' ')[1]; // Get "AM" or "PM"

      final timeComponents = timeOnly.split(':');
      int hour = int.parse(timeComponents[0]);
      final minute = int.parse(timeComponents[1]);

      // Convert 12-hour to 24-hour format
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('Error parsing date/time: $e');
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderNameController.dispose();
    super.dispose();
  }
}

// Card Number Formatter
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');

    if (text.length > 16) {
      text = text.substring(0, 16);
    }

    var newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        newText += ' ';
      }
      newText += text[i];
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Expiry Date Formatter
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');

    if (text.length > 4) {
      text = text.substring(0, 4);
    }

    var newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        newText += '/';
      }
      newText += text[i];
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
