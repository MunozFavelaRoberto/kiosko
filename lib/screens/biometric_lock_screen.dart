import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/models/biometric_type_info.dart';

class BiometricLockScreen extends StatefulWidget {
  final bool longPause;
  final bool forceToHome;
  const BiometricLockScreen({this.longPause = false, this.forceToHome = false, super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  late final AuthService _authService;
  bool _authenticating = false;
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 5;
  
  BiometricTypeInfo? _primaryBiometric;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _loadPrimaryBiometric();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _loadPrimaryBiometric() async {
    final biometrics = await _authService.getAvailableBiometrics();
    final addedTypes = <String>{};
    
    for (final biometric in biometrics) {
      if (await _authService.isBiometricEnabled(biometric.type)) {
        if (!addedTypes.contains(biometric.displayName)) {
          if (!mounted) return;
          setState(() {
            _primaryBiometric = biometric;
          });
          return;
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);

    if (_primaryBiometric != null) {
      final success = await _authService.authenticateWithType(_primaryBiometric!.type);
      
      if (!mounted) return;
      setState(() => _authenticating = false);
      
      if (success) {
        _onAuthSuccess();
        return;
      }
    } else {
      final success = await _authService.authenticate();
      
      if (!mounted) return;
      setState(() => _authenticating = false);
      
      if (success) {
        _onAuthSuccess();
        return;
      }
    }

    if(mounted) {
      setState(() => _failedAttempts += 1);
      if (_failedAttempts >= _maxFailedAttempts) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demasiados intentos. Usa contraseña.')));
      }
    }
  }

  void _onAuthSuccess() {
    if (widget.forceToHome) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _forceLogoutAndShowLogin() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final biometricName = _primaryBiometric?.displayName ?? 'Biometría';
    final biometricIcon = _primaryBiometric?.icon ?? Icons.fingerprint;

    // Se envuelve el Scaffold con PopScope para deshabilitar el botón de "atrás"
    // en Android, forzando al usuario a autenticarse por seguridad.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.blueGrey.shade900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(biometricIcon, size: 100, color: Colors.white),
              const SizedBox(height: 30),
              const Text(
                "Kiosko Protegido",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                  widget.longPause
                      ? 'Confirma tu identidad'
                      : 'Identifícate para continuar',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _authenticating ? null : _authenticate,
                icon: Icon(biometricIcon),
                label: Text(_authenticating
                    ? 'Autenticando...'
                    : 'Usar $biometricName'),
              ),
              const SizedBox(height: 12),
              if (_failedAttempts >= _maxFailedAttempts)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    onPressed: _forceLogoutAndShowLogin,
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('Entrar con contraseña (cerrar sesión)'),
                  ),
                )
              else
                TextButton(
                  onPressed: _forceLogoutAndShowLogin,
                  child: const Text("Entrar con contraseña",
                      style: TextStyle(color: Colors.blue)),
                )
            ],
          ),
        ),
      ),
    );
  }
}
