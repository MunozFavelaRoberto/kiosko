import 'package:intl/intl.dart';

/// Formatea un número como monto en USD con dos decimales.
/// Retorna '-' si el valor no es válido.
///
/// Ejemplos:
/// - getAmountFormat(null) → "-"
/// - getAmountFormat("") → "-"
/// - getAmountFormat("abc") → "-"
/// - getAmountFormat(1234) → "$1,234.00"
/// - getAmountFormat(1234.5) → "$1,234.50"
/// - getAmountFormat(1234.567) → "$1,234.57"
/// - getAmountFormat(0) → "$0.00"
String getAmountFormat(dynamic value) {
  // Caso null
  if (value == null) {
    return '-';
  }

  // Caso String vacío
  if (value is String && value.isEmpty) {
    return '-';
  }

  // Intentar convertir a double
  double? numeric;

  if (value is double) {
    numeric = value;
  } else if (value is int) {
    numeric = value.toDouble();
  } else if (value is String) {
    // Limpiar el string (quitar comas, espacios)
    final cleaned = value.replaceAll(',', '').replaceAll(' ', '');
    numeric = double.tryParse(cleaned);
  }

  // Si no se pudo convertir a número, retornar "-"
  if (numeric == null || numeric.isNaN) {
    return '-';
  }

  // Formatear como moneda USD
  final formatter = NumberFormat.currency(
    locale: 'en-US',
    symbol: '\$',
    decimalDigits: 2,
  );

  return formatter.format(numeric);
}

/// Versión simplificada que acepta double? nullable
String getAmountFormatDouble(double? value) {
  return getAmountFormat(value);
}

/// Versión simplificada que acepta int? nullable
String getAmountFormatInt(int? value) {
  return getAmountFormat(value);
}
