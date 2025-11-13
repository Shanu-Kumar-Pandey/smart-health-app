import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../models/payment_method.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final PaymentService _paymentService = PaymentService();
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    print('=== Starting to load payment methods ===');
    setState(() {
      _isLoading = true;
    });

    try {
      print('Calling payment service to get user payment methods...');
      final paymentData = await _paymentService.getUserPaymentMethods();
      print('Payment data received from service: ${paymentData.length} items');
      print('Payment data: $paymentData');

      final paymentMethods = paymentData.map((data) => PaymentMethod.fromMap(data)).toList();
      print('Converted to PaymentMethod objects: ${paymentMethods.length} items');

      // Debug: Print detailed information for each payment method
      for (var i = 0; i < paymentMethods.length; i++) {
        final pm = paymentMethods[i];
        print('Payment Method $i Details:');
        print('  - ID: ${pm.id}');
        print('  - User ID: ${pm.userId}');
        print('  - Type: ${pm.paymentType}');
        print('  - Card Number: ${pm.cardNumber}');
        print('  - Card Holder: ${pm.cardHolderName}');
        print('  - Expiry: ${pm.expiryMonth}/${pm.expiryYear}');
        print('  - Created At: ${pm.createdAt}');
      }

      setState(() {
        _paymentMethods = paymentMethods;
        _isLoading = false;
      });
      print('State updated. Payment methods count: ${_paymentMethods.length}');
    } catch (e) {
      print('ERROR loading payment methods: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading payment methods: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('=== Building PaymentMethodPage ===');
    print('Loading state: $_isLoading');
    print('Payment methods count: ${_paymentMethods.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.add),
        //     onPressed: _addNewPaymentMethod,
        //   ),
        // ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
              ? _buildEmptyState()
              : _buildPaymentMethodsList(),
    );
  }

  Widget _buildEmptyState() {
    print('Building empty state - no payment methods found');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payment methods found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Text(
          //   'Add a payment method to get started',
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey[500],
          //   ),
          // ),
          const SizedBox(height: 24),
          // ElevatedButton.icon(
          //   onPressed: _addNewPaymentMethod,
          //   icon: const Icon(Icons.add),
          //   label: const Text('Add Payment Method'),
          // ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    print('Building payment methods list with ${_paymentMethods.length} items');
    return ListView.builder(
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final paymentMethod = _paymentMethods[index];
        print('Building item $index: ${paymentMethod.cardNumber ?? paymentMethod.paymentType}');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: InkWell(
            onTap: () => _showPaymentMethodDetails(paymentMethod),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with icon, basic info, and actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _getPaymentMethodIcon(paymentMethod),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Type Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getCardTypeColor(paymentMethod.paymentType ?? 'card'),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                (paymentMethod.paymentType ?? 'CARD').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Card Holder Name
                            if (paymentMethod.cardHolderName != null)
                              Text(
                                paymentMethod.cardHolderName!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),

                            // Payment Type and Masked Card Number
                            Text(
                              paymentMethod.cardNumber != null
                                  ? '**** **** **** ${paymentMethod.cardNumber!.substring(paymentMethod.cardNumber!.length - 4)}'
                                  : (paymentMethod.paymentType ?? 'Payment Method'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deletePaymentMethod(paymentMethod),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getCardTypeColor(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'credit':
        return Colors.purple;
      case 'debit':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Widget _getPaymentMethodIcon(PaymentMethod paymentMethod) {
    IconData iconData;
    Color iconColor;

    switch (paymentMethod.paymentType) {
      case 'card':
        iconData = Icons.credit_card;
        iconColor = Colors.blue;
        break;
      case 'upi':
        iconData = Icons.account_balance_wallet;
        iconColor = Colors.green;
        break;
      case 'netbanking':
        iconData = Icons.account_balance;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.payment;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor),
    );
  }


  void _showPaymentMethodDetails(PaymentMethod paymentMethod) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? null
                  : LinearGradient(
                      colors: [Colors.blue.shade50, Colors.green.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade200,
                width: 1
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade700
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.grey.shade300,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _getPaymentMethodIcon(paymentMethod),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Card Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getCardTypeColor(paymentMethod.paymentType ?? 'card'),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        (paymentMethod.paymentType ?? 'CARD').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card Holder Name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('Holder:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                        ),
                        Expanded(
                          child: Text(
                            paymentMethod.cardHolderName ?? 'Unknown Holder',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Card Number
                    if (paymentMethod.cardNumber != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text('Card no:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.black26
                                        : Colors.grey.shade200,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                paymentMethod.cardNumber!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Expiry Date
                    if (paymentMethod.expiryMonth != null || paymentMethod.expiryYear != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text('Expires:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange.shade800
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.orange.shade600
                                      : Colors.orange.shade200,
                                  width: 1
                                ),
                              ),
                              child: Text(
                                '${paymentMethod.expiryMonth ?? 'MM'}/${paymentMethod.expiryYear ?? 'YY'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Created At
                    if (paymentMethod.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text('Added on:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            ),
                            Text(
                              '${paymentMethod.createdAt!.day}/${paymentMethod.createdAt!.month}/${paymentMethod.createdAt!.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _deletePaymentMethod(PaymentMethod paymentMethod) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text(
          'Are you sure you want to delete this payment method? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('Deleting payment method: ${paymentMethod.id}');
        final success = await _paymentService.deletePaymentMethod(paymentMethod.id!);

        if (success) {
          // Refresh the list
          await _loadPaymentMethods();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment method deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete payment method')),
          );
        }
      } catch (e) {
        print('Error deleting payment method: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment method: $e')),
        );
      }
    }
  }
}
