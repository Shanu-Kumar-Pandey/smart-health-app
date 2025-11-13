class PaymentMethod {
  final String? id;
  final String? userId;
  final String? cardNumber;
  final String? cardHolderName;
  final String? expiryMonth;
  final String? expiryYear;
  final String? paymentType;
  final DateTime? createdAt;

  PaymentMethod({
    this.id,
    this.userId,
    this.cardNumber,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.paymentType,
    this.createdAt,
  });

  factory PaymentMethod.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return PaymentMethod();
    }

    // Parse expiry date from "MM/YY" format
    String? expiryMonth;
    String? expiryYear;
    if (data['expiryDate'] != null) {
      final parts = data['expiryDate'].toString().split('/');
      if (parts.length == 2) {
        expiryMonth = parts[0];
        expiryYear = parts[1];
      }
    }

    return PaymentMethod(
      id: data['id'],
      userId: data['userId'],
      cardNumber: data['cardNumber'],
      cardHolderName: data['cardHolderName'],
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      paymentType: data['paymentType'],
      createdAt: data['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'cardNumber': cardNumber,
      'cardHolderName': cardHolderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'paymentType': paymentType,
      'createdAt': createdAt,
    };
  }

  // Helper method to get masked card number for display
  String getMaskedCardNumber() {
    if (cardNumber == null || cardNumber!.length < 4) return '****';
    return '**** **** **** ${cardNumber!.substring(cardNumber!.length - 4)}';
  }
}
