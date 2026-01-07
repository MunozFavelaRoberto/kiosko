import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final bool longPause;
  final bool forceToHome; // si true, en éxito navega a /home; si false, hace pop
  const BiometricLockScreen({this.longPause = false, this.forceToHome = false, super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final AuthService _authService = AuthService();
  bool _authenticating = false;
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 3;

  @override
  void initState() {
    super.initState();
    // Intentar autenticar al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    final success = await _authService.authenticate();

    if (!mounted) return;
    setState(() => _authenticating = false);
    if (success) {
      if (widget.forceToHome) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pop(context);
      }
      return;
    }

    // Cuenta intentos fallidos
    setState(() => _failedAttempts += 1);
    if (_failedAttempts >= _maxFailedAttempts) {
      // después de varios intentos fallidos, recomendamos entrar con contraseña
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demasiados intentos. Usa contraseña.')));
    }
  }

  Future<void> _forceLogoutAndShowLogin() async {
    await _authService.logout();
    if (!mounted) return;
    // En caso de forzar salida, siempre vamos al login y limpiamos la pila
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 100, color: Colors.white),
            const SizedBox(height: 30),
            const Text(
              "Kiosko Protegido",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(widget.longPause ? 'Sesión inactiva — confirma tu identidad' : 'Identifícate para continuar',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _authenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: Text(_authenticating ? 'Autenticando...' : 'Usar Biometría'),
            ),
            const SizedBox(height: 12),
            if (_failedAttempts >= _maxFailedAttempts)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton(
                  onPressed: _forceLogoutAndShowLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('Entrar con contraseña (cerrar sesión)'),
                ),
              )
            else
              TextButton(
                onPressed: _forceLogoutAndShowLogin,
                child: const Text("Entrar con contraseña", style: TextStyle(color: Colors.blue)),
              )
          ],
        ),
      ),
    );
  }
}
