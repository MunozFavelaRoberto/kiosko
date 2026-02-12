import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kiosko/models/biometric_type_info.dart';
import 'package:kiosko/models/auth_response.dart';
import 'package:kiosko/services/api_service.dart';

/// Servicio de autenticación que gestiona login, logout, biometría y persistencia de sesión
class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  UserData? _currentUser;

  UserData? get currentUser => _currentUser;

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
      return await _auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a Kiosko',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Inicio de Sesión - Kiosko',
            signInHint: 'Toca el sensor de huellas',
            cancelButton: 'Cerrar',
          ),
        ],
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Error autenticación: $e');
      return false;
    }
  }

  // Biometry Preferences (Legacy - Mantenido por compatibilidad)
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
      final checkedTypes = <String>{};
      
      for (final biometric in biometrics) {
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

  // Session Persistence

  Future<void> saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  // Secure Credentials (Biometric Re-authentication)

  /// Guarda las credenciales de forma encriptada para uso con biometría
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: 'biometric_email', value: email);
      await _secureStorage.write(key: 'biometric_password', value: password);
    } catch (e) {
      debugPrint('Error guardando credenciales: $e');
    }
  }

  /// Recupera el email guardado de forma encriptada
  Future<String?> getSavedEmail() async {
    try {
      return await _secureStorage.read(key: 'biometric_email');
    } catch (e) {
      debugPrint('Error recuperando email: $e');
      return null;
    }
  }

  /// Recupera la contraseña guardada de forma encriptada
  Future<String?> getSavedPassword() async {
    try {
      return await _secureStorage.read(key: 'biometric_password');
    } catch (e) {
      debugPrint('Error recuperando contraseña: $e');
      return null;
    }
  }

  /// Verifica si hay credenciales guardadas
  Future<bool> hasSavedCredentials() async {
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    return email != null && password != null;
  }

  /// Elimina las credenciales guardadas
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: 'biometric_email');
      await _secureStorage.delete(key: 'biometric_password');
    } catch (e) {
      debugPrint('Error eliminando credenciales: $e');
    }
  }

  /// Login automático usando credenciales guardadas (para biometría)
  Future<bool> loginWithSavedCredentials() async {
    try {
      final email = await getSavedEmail();
      final password = await getSavedPassword();
      
      if (email == null || password == null) {
        return false;
      }
      
      final response = await login(email, password);
      return response != null;
    } catch (e) {
      debugPrint('Error login con credenciales guardadas: $e');
      return false;
    }
  }

  // Authentication Methods

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('authToken');
    await clearCredentials();
    _currentUser = null;
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

      final response = await _apiService.get('/user', headers: {
        'Authorization': 'Bearer $token',
      });

      return response != null;
    } catch (e) {
      debugPrint('Error verificando token: $e');
      if (e is SocketException || e is http.ClientException) {
        return true;
      }
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
        await _saveToken(authResponse.data.auth.token);
        _currentUser = authResponse.data.auth.user;
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