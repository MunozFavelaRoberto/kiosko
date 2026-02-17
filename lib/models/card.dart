import 'package:flutter/material.dart';

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
      id: json['id'] as int,
      cardId: json['card_id'] as String,
      isFavorite: json['is_favorite'] as int,
      key: json['key'] as int,
      uiid: json['uiid'] as String,
      cardNumber: json['card_number'] as String,
      holderName: json['holder_name'] as String,
      expirationYear: json['expiration_year'] as String,
      expirationMonth: json['expiration_month'] as String,
      type: json['type'] as String,
      brand: json['brand'] as String,
      bankName: json['bank_name'] as String,
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

  // Métodos de utilidad para la UI

  /// Detectar la marca de la tarjeta basándose en el número
  static String detectBrand(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');
    
    if (cleanNumber.startsWith('4')) {
      return 'visa';
    }
    if (cleanNumber.startsWith(RegExp(r'5[1-5]'))) {
      return 'mastercard';
    }
    if (cleanNumber.startsWith(RegExp(r'3[47]'))) {
      return 'amex';
    }
    if (cleanNumber.startsWith(RegExp(r'(6011|65|64[4-9])'))) {
      return 'discover';
    }
    return 'unknown';
  }

  /// Validar número de tarjeta con algoritmo de Luhn
  static bool validateLuhn(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');
    if (cleanNumber.isEmpty) return false;
    
    int sum = 0;
    bool isEven = false;
    
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      isEven = !isEven;
    }
    
    return sum % 10 == 0;
  }

  /// Obtener la longitud esperada del CVV según la marca
  static int getCvvLength(String brand) {
    return brand.toLowerCase() == 'amex' ? 4 : 3;
  }

  /// Obtener la longitud esperada del número según la marca
  static int getCardNumberLength(String brand) {
    return brand.toLowerCase() == 'amex' ? 15 : 16;
  }

  /// Formatear el número de tarjeta según la marca
  static String formatCardNumber(String cardNumber, [String brand = '']) {
    final cleanNumber = cardNumber.replaceAll(' ', '').replaceAll('-', '');
    final detectedBrand = brand.isNotEmpty ? brand : detectBrand(cleanNumber);
    
    if (detectedBrand == 'amex') {
      // American Express: grupos de 4-6-5
      final groups = <String>[];
      if (cleanNumber.length > 4) groups.add(cleanNumber.substring(0, 4));
      if (cleanNumber.length > 10) groups.add(cleanNumber.substring(4, 10));
      if (cleanNumber.length > 10) groups.add(cleanNumber.substring(10));
      return groups.join(' ');
    } else {
      // Visa, Mastercard, Discover: grupos de 4
      final groups = <String>[];
      for (int i = 0; i < cleanNumber.length; i += 4) {
        groups.add(cleanNumber.substring(i, (i + 4).clamp(0, cleanNumber.length)));
      }
      return groups.join(' ');
    }
  }

  /// Obtener el color del gradiente según la marca
  static Map<String, Color> getBrandColors(String brand) {
    final brandLower = brand.toLowerCase();
    switch (brandLower) {
      case 'visa':
        return {
          'primary': const Color(0xFF1a237e),
          'secondary': const Color(0xFF3949ab),
        };
      case 'mastercard':
        return {
          'primary': const Color(0xFFec7711),
          'secondary': const Color(0xFF5B6BC0),
        };
      case 'amex':
        return {
          'primary': const Color(0xFF2e7d32),
          'secondary': const Color(0xFF4caf50),
        };
      case 'discover':
        return {
          'primary': const Color(0xFF6a1b9a),
          'secondary': const Color(0xFF9c27b0),
        };
      default:
        return {
          'primary': const Color(0xFF616161),
          'secondary': const Color(0xFF757575),
        };
    }
  }

  /// Obtener la ruta del logo de la marca (asset local)
  /// Retorna la ruta del asset o cadena vacía si no existe
  static String getBrandLogo(String brand) {
    final logos = {
      'visa': 'assets/images/Visa_Inc._logo.svg',
      'mastercard': 'assets/images/Mastercard-logo.svg',
      'amex': 'assets/images/American_Express_logo.svg',
      'discover': 'assets/images/discover.png',
    };
    return logos[brand.toLowerCase()] ?? '';
  }

  /// Verificar si la tarjeta está expirada
  bool isExpired() {
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    
    final expYear = int.tryParse(expirationYear) ?? 0;
    final expMonth = int.tryParse(expirationMonth) ?? 0;
    
    if (expYear < currentYear) return true;
    if (expYear == currentYear && expMonth < currentMonth) return true;
    return false;
  }

  /// Obtener fecha de expiración formateada
  String getFormattedExpiry() {
    return '$expirationMonth/$expirationYear';
  }

  /// Obtener número de tarjeta enmascarado (últimos 4 dígitos visibles)
  String getMaskedNumber() {
    if (cardNumber.length >= 4) {
      return '****${cardNumber.substring(cardNumber.length - 4)}';
    }
    return cardNumber;
  }
}
