class Service {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final double? fee;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    this.fee,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as int,
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'fee': fee,
    };
  }
}