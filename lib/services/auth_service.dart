import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosko/models/biometric_type_info.dart';
import 'package:kiosko/models/auth_response.dart';
import 'package:kiosko/services/api_service.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  final ApiService _apiService = ApiService();

  // --- BIOMETRÍA ---

  Future<bool> get canCheckBiometrics async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      return canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Error soporte: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      // En versiones nuevas, AuthenticationOptions y los mensajes
      // van dentro de authMessages o directamente en los parámetros de la plataforma.
      return await _auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a Kiosko',
        // Se eliminó el parámetro 'options' de nivel superior y se usan estos:
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Inicio de Sesión - Kiosko',
            signInHint: 'Toca el sensor de huellas',
            cancelButton: 'Cerrar',
          ),
        ],
        // Opciones de comportamiento:
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Error autenticación: $e');
      return false;
    }
  }

  // --- PREFERENCIA DE BIOMETRÍA (LEGACY) ---

  Future<void> setUseBiometrics(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useBiometrics', value);
    } catch (e) {
      debugPrint('Error guardando preferencia biometría: $e');
    }
  }

  Future<bool> getUseBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('useBiometrics') ?? false;
    } catch (e) {
      debugPrint('Error leyendo preferencia biometría: $e');
      return false;
    }
  }

  // --- BIOMETRÍAS DISPONIBLES (NUEVO SISTEMA) ---

  /// Obtiene la lista de tipos de biometría disponibles en el dispositivo
  Future<List<BiometricTypeInfo>> getAvailableBiometrics() async {
    try {
      final List<BiometricType> availableTypes = await _auth.getAvailableBiometrics();
      
      return availableTypes.map((type) => BiometricTypeInfo.fromType(type)).toList();
    } catch (e) {
      debugPrint('Error obteniendo biometrías disponibles: $e');
      return [];
    }
  }

  /// Verifica si el dispositivo tiene alguna biometría disponible
  Future<bool> hasAnyBiometric() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  /// Obtiene el estado de habilitación de un tipo específico de biometría
  Future<bool> isBiometricEnabled(BiometricType type) async {
    try {
      final biometricInfo = BiometricTypeInfo.fromType(type);
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(biometricInfo.preferenceKey) ?? false;
    } catch (e) {
      debugPrint('Error verificando biometría habilitada: $e');
      return false;
    }
  }

  /// Habilita o deshabilita un tipo específico de biometría
  Future<void> setBiometricEnabled(BiometricType type, bool enabled) async {
    try {
      final biometricInfo = BiometricTypeInfo.fromType(type);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(biometricInfo.preferenceKey, enabled);
    } catch (e) {
      debugPrint('Error guardando preferencia de biometría: $e');
    }
  }

  /// Autentica usando un tipo específico de biometría
  Future<bool> authenticateWithType(BiometricType type) async {
    final biometricInfo = BiometricTypeInfo.fromType(type);
    final authMessages = AndroidAuthMessages(
      signInTitle: 'Inicio de Sesión - Kiosko',
      signInHint: 'Usa tu ${biometricInfo.displayName}',
      cancelButton: 'Cerrar',
    );
    try {
      return await _auth.authenticate(
        localizedReason: 'Por favor, autentícate usando ${biometricInfo.displayName}',
        authMessages: [authMessages],
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
    } catch (e) {
      debugPrint('Error autenticación con ${biometricInfo.displayName}: $e');
      return false;
    }
  }

  /// Verifica si al menos una biometría está habilitada
  Future<bool> isAnyBiometricEnabled() async {
    try {
      final biometrics = await getAvailableBiometrics();
      
      // Normalizar: evitar verificar el mismo tipo dos veces
      final checkedTypes = <String>{}; // track por displayName
      
      for (final biometric in biometrics) {
        // Usar displayName como clave para evitar duplicados de huella
        final key = biometric.displayName;
        if (checkedTypes.contains(key)) continue;
        checkedTypes.add(key);
        
        if (await isBiometricEnabled(biometric.type)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error verificando biometrías habilitadas: $e');
      return false;
    }
  }

  // --- PERSISTENCIA ---

  Future<void> saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  Future<bool> verifyToken() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      // Intentar llamar a un endpoint que requiera auth
      final response = await _apiService.get('/user', headers: {
        'Authorization': 'Bearer $token',
      });

      // Si la respuesta es exitosa, el token es válido
      return response != null;
    } catch (e) {
      debugPrint('Token inválido: $e');
      return false;
    }
  }

  Future<AuthResponse?> login(String email, String password) async {
    try {
      final response = await _apiService.post('/login', body: {
        'email': email,
        'password': password,
      });

      if (response != null) {
        final authResponse = AuthResponse.fromJson(response);
        // Guardar token y estado de login
        await _saveToken(authResponse.data.auth.token);
        await saveLoginState();
        return authResponse;
      }
      return null;
    } catch (e) {
      debugPrint('Error en login: $e');
      return null;
    }
  }
}