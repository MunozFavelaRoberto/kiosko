import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Modelo que representa un tipo de biometría disponible en el dispositivo
class BiometricTypeInfo {
  final BiometricType type;
  final String displayName;
  final IconData icon;

  BiometricTypeInfo({
    required this.type,
    required this.displayName,
    required this.icon,
  });

  /// Obtiene la información de un tipo de biometría específico
  static BiometricTypeInfo fromType(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return BiometricTypeInfo(
          type: type,
          displayName: 'Face ID',
          icon: Icons.face,
        );
      case BiometricType.fingerprint:
        return BiometricTypeInfo(
          type: type,
          displayName: 'Huella Digital',
          icon: Icons.fingerprint,
        );
      case BiometricType.iris:
        return BiometricTypeInfo(
          type: type,
          displayName: 'Iris',
          icon: Icons.remove_red_eye,
        );
      case BiometricType.strong:
        // En Android, strong puede incluir huella
        return BiometricTypeInfo(
          type: type,
          displayName: 'Huella Digital',
          icon: Icons.fingerprint,
        );
      case BiometricType.weak:
        // En Android, weak puede incluir huella
        return BiometricTypeInfo(
          type: type,
          displayName: 'Huella Digital',
          icon: Icons.fingerprint,
        );
    }
  }

  /// Verifica si este tipo representa una huella digital
  bool get isFingerprint {
    return type == BiometricType.fingerprint || 
           type == BiometricType.strong || 
           type == BiometricType.weak;
  }

  /// Clave de preferencia única para este tipo de biometría
  /// Usa fingerprint como clave para strong/weak (todos representan huella)
  String get preferenceKey {
    if (isFingerprint) {
      return 'biometric_fingerprint_enabled';
    }
    return 'biometric_${type.toString().split('.').last}_enabled';
  }
}
