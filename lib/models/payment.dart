class Payment {
  final int id;
  final int serviceId;
  final String serviceName;
  final double amount;
  final String reference;
  final DateTime date;
  final String status; // 'Pendiente' or 'Pagado'
  final String? folio;

  Payment({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.amount,
    required this.reference,
    required this.date,
    required this.status,
    this.folio,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      serviceId: json['service_id'] as int,
      serviceName: json['service_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      reference: json['reference'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      folio: json['folio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'service_name': serviceName,
      'amount': amount,
      'reference': reference,
      'date': date.toIso8601String(),
      'status': status,
      'folio': folio,
    };
  }
}