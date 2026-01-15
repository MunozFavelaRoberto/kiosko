class User {
  final String clientNumber;
  final String status;
  final double balance;

  User({
    required this.clientNumber,
    required this.status,
    required this.balance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      clientNumber: json['clientNumber'] as String,
      status: json['status'] as String,
      balance: (json['balance'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientNumber': clientNumber,
      'status': status,
      'balance': balance,
    };
  }
}