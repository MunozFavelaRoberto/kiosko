import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

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

  // --- PREFERENCIA DE BIOMETRÍA ---

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

  // LOGIN HARDCODEADO
  Future<bool> login(String username, String password) async {
    if (username == "admin" && password == "admin") {
      await saveLoginState();
      return true;
    }
    return false;
  }
}