class CardModel {
  final int id;
  final String cardId;
  final int isFavorite;
  final int key;
  final String uiid;
  final String cardNumber;
  final String holderName;
  final String expirationYear;
  final String expirationMonth;
  final String type;
  final String brand;
  final String bankName;

  CardModel({
    required this.id,
    required this.cardId,
    required this.isFavorite,
    required this.key,
    required this.uiid,
    required this.cardNumber,
    required this.holderName,
    required this.expirationYear,
    required this.expirationMonth,
    required this.type,
    required this.brand,
    required this.bankName,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      cardId: json['card_id'],
      isFavorite: json['is_favorite'],
      key: json['key'],
      uiid: json['uiid'],
      cardNumber: json['card_number'],
      holderName: json['holder_name'],
      expirationYear: json['expiration_year'],
      expirationMonth: json['expiration_month'],
      type: json['type'],
      brand: json['brand'],
      bankName: json['bank_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_id': cardId,
      'is_favorite': isFavorite,
      'key': key,
      'uiid': uiid,
      'card_number': cardNumber,
      'holder_name': holderName,
      'expiration_year': expirationYear,
      'expiration_month': expirationMonth,
      'type': type,
      'brand': brand,
      'bank_name': bankName,
    };
  }
}