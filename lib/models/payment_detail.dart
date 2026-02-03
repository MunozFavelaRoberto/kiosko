class PaymentDetail {
  final int paymentId;
  final String amount;
  final String description;
  final int key;
  final String uiid;

  PaymentDetail({
    required this.paymentId,
    required this.amount,
    required this.description,
    required this.key,
    required this.uiid,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    // Parsear amount de forma segura
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        // Remover comas y espacios
        final cleaned = value.replaceAll(',', '').replaceAll(' ', '');
        final parsed = double.tryParse(cleaned);
        return parsed ?? 0.0;
      }
      return 0.0;
    }
    
    return PaymentDetail(
      paymentId: json['payment_id'] as int,
      amount: (parseAmount(json['amount'])).toStringAsFixed(2),
      description: json['description'] as String,
      key: json['key'] as int,
      uiid: json['uiid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'amount': amount,
      'description': description,
      'key': key,
      'uiid': uiid,
    };
  }
}
