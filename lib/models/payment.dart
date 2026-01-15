class Payment {
  final int id;
  final int serviceId;
  final double amount;
  final String reference;
  final DateTime date;

  Payment({
    required this.id,
    required this.serviceId,
    required this.amount,
    required this.reference,
    required this.date,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      serviceId: json['service_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      reference: json['reference'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'amount': amount,
      'reference': reference,
      'date': date.toIso8601String(),
    };
  }
}