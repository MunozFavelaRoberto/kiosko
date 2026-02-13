import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/models/biometric_type_info.dart';
import 'package:kiosko/utils/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Instancia de autenticación
  late final AuthService _authService;

  // Controladores para capturar texto de los campos
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // Variable indicador de carga
  bool _isLoading = false;
  bool _showBiometricButton = false;
  bool _obscurePassword = true;
  List<BiometricTypeInfo> _enabledBiometrics = [];

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _initBiometricVisibility();
  }
  
  // Función que centraliza el éxito del login
  Future<void> _handleLoginSuccess() async {
    await _authService.saveLoginState(); // Guardamos sesión en disco
    
    if (!mounted) return;
    
    // Navegamos al Home y eliminamos la pantalla de login del historial
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  // Login por botón
  void _loginWithPassword() async {
    setState(() => _isLoading = true);
    final email = _userController.text.trim();
    final pass = _passController.text.trim();

    if (email.isNotEmpty && pass.isNotEmpty) {
      final response = await _authService.login(email, pass);
      if (response != null) {
        // Guardar credenciales de forma segura para reactivación con biometría
        await _authService.saveCredentials(email, pass);
        await _handleLoginSuccess();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Login por biometría específica
  Future<void> _loginWithBiometrics(BiometricTypeInfo biometric) async {
    setState(() => _isLoading = true);

    // Verificar que la biometría sigue habilitada
    final isEnabled = await _authService.isBiometricEnabled(biometric.type);

    if (!isEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta biometría ha sido deshabilitada')),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Autenticar con biometría
    bool authenticated = await _authService.authenticateWithType(biometric.type);
    
    if (authenticated) {
      // Verificar si hay token válido
      final tokenValid = await _authService.verifyToken();
      
      if (tokenValid) {
        // Token válido, solo restaurar estado
        await _authService.saveLoginState();
        await _handleLoginSuccess();
      } else {
        // Token expiró, usar credenciales guardadas para hacer login
        final loginSuccess = await _authService.loginWithSavedCredentials();
        
        if (loginSuccess) {
          await _handleLoginSuccess();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesión expirada. Por favor inicia sesión con email y contraseña.')),
          );
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Autenticación con ${biometric.displayName} fallida')),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initBiometricVisibility() async {
    // Verificar si hay credenciales guardadas (para reactivación de sesión)
    final hasCredentials = await _authService.hasSavedCredentials();
    
    // Verificar si hay biometría disponible
    final canCheck = await _authService.canCheckBiometrics;
    
    List<BiometricTypeInfo> enabledBiometrics = [];
    
    // Mostrar biometría si:
    // 1. Hay credenciales guardadas (para reactivación de sesión), O
    // 2. Hay token válido (sesión activa previamente)
    final tokenValid = await _authService.verifyToken();
    
    if ((hasCredentials || tokenValid) && canCheck) {
      final available = await _authService.getAvailableBiometrics();
      
      // Normalizar: eliminar duplicados de strong/weak
      final addedTypes = <String>{}; // track por displayName
      
      for (final biometric in available) {
        // Verificar si está habilitada
        final isEnabled = await _authService.isBiometricEnabled(biometric.type);
        if (!isEnabled) continue;
        
        // Evitar duplicados
        if (addedTypes.contains(biometric.displayName)) continue;
        
        enabledBiometrics.add(biometric);
        addedTypes.add(biometric.displayName);
      }
    }
    
    if (!mounted) return;
    setState(() {
      _showBiometricButton = enabledBiometrics.isNotEmpty;
      _enabledBiometrics = enabledBiometrics;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color blueish = Color.lerp(colorScheme.primary, Colors.lightBlueAccent, 0.7) ?? colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Image.asset('assets/images/svr_logo.png', height: 100, width: 100),
                      const SizedBox(height: 40),

                      // Campo Email
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Campo Contraseña
                      TextField(
                        controller: _passController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Botón Ingresar
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueish,
                            foregroundColor: (blueish.computeLuminance() > 0.6) ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: (blueish.computeLuminance() > 0.6) ? Colors.black : Colors.white)
                              : Text("INICIAR SESIÓN", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Mostrar bloque biométrico completo sólo si corresponde
                if (_showBiometricButton) ...[
                  const SizedBox(height: 40),

                  // Divisor visual
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("O ingresa con", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).round()))),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Botón Biométrico dinámico (muestra los métodos habilitados)
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _enabledBiometrics.map((biometric) {
                      return GestureDetector(
                        onTap: _isLoading ? null : () => _loginWithBiometrics(biometric),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          decoration: BoxDecoration(
                            color: blueish.withAlpha((0.08 * 255).round()),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: blueish.withAlpha((0.5 * 255).round())),
                          ),
                          child: Column(
                            children: [
                              Icon(biometric.icon, size: 40, color: blueish),
                              const SizedBox(height: 6),
                              Text(
                                biometric.displayName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: blueish, 
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
