class PaymentHistory {
  final int id;
  final DateTime createdAt;
  final double amount;
  final int transactionId;
  final String? invoiceId;
  final int key;
  final String uiid;
  final List<PaymentItem> paymentItems;

  PaymentHistory({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.transactionId,
    this.invoiceId,
    required this.key,
    required this.uiid,
    required this.paymentItems,
  });

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      amount: double.parse(json['amount'] as String),
      transactionId: json['transaction_id'] as int,
      invoiceId: json['invoice_id'] as String?,
      key: json['key'] as int,
      uiid: json['uiid'] as String,
      paymentItems: (json['payment_items'] as List)
          .map((item) => PaymentItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'amount': amount.toStringAsFixed(2),
      'transaction_id': transactionId,
      'invoice_id': invoiceId,
      'key': key,
      'uiid': uiid,
      'payment_items': paymentItems.map((e) => e.toJson()).toList(),
    };
  }
}

class PaymentItem {
  final int paymentId;
  final PaymentDetail payment;

  PaymentItem({
    required this.paymentId,
    required this.payment,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      paymentId: json['payment_id'] as int,
      payment: PaymentDetail.fromJson(json['payment'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'payment': payment.toJson(),
    };
  }
}

class PaymentDetail {
  final double amount;
  final String description;

  PaymentDetail({
    required this.amount,
    required this.description,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    return PaymentDetail(
      amount: double.parse(json['amount'] as String),
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount.toStringAsFixed(2),
      'description': description,
    };
  }
}
