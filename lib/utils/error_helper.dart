import 'dart:convert';

/// Helper centralizado para parsear errores de API
class ErrorHelper {
  /// Parsea un error de API y devuelve un mensaje amigable
  static String parseError(String errorStr, {String defaultMsg = 'Error desconocido'}) {
    if (errorStr.contains('Error HTTP')) {
      try {
        final startIndex = errorStr.indexOf('{');
        if (startIndex != -1) {
          final errorBody = errorStr.substring(startIndex);
          final errorJson = jsonDecode(errorBody);
          return errorJson['msg'] ?? defaultMsg;
        }
      } catch (_) {
        return defaultMsg;
      }
    }

    // Errores de conexión comunes
    if (errorStr.contains('No hay conexión a internet')) {
      return 'No hay conexión a internet. Verifica tu red.';
    }
    if (errorStr.contains('Error de conexión')) {
      return 'Error de conexión. Intenta de nuevo.';
    }

    return defaultMsg;
  }

  /// Verifica si el error es de red (sin conexión)
  static bool isNetworkError(String errorStr) {
    return errorStr.contains('No hay conexión a internet') ||
           errorStr.contains('Error de conexión') ||
           errorStr.contains('SocketException');
  }
}
