class User {
  final String clientNumber;
  final String status;
  final double balance;
  final String fullName;
  final String email;

  User({
    required this.clientNumber,
    required this.status,
    required this.balance,
    required this.fullName,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      clientNumber: json['clientNumber'] as String? ?? 'N/A',
      status: json['status'] as String? ?? 'Desconocido',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      fullName: json['fullName'] as String? ?? 'Nombre Desconocido',
      email: json['email'] as String? ?? 'email@desconocido.com',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientNumber': clientNumber,
      'status': status,
      'balance': balance,
      'fullName': fullName,
      'email': email,
    };
  }
}