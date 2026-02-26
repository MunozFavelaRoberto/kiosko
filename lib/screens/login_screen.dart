import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/data_provider.dart';
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

  // Form key para validación
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar texto de los campos
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Focus nodes para detectar cuando el campo pierde el foco
  final FocusNode _userFocusNode = FocusNode();
  final FocusNode _passFocusNode = FocusNode();

  // Variable indicador de carga
  bool _isLoading = false;
  bool _showBiometricButton = false;
  bool _obscurePassword = true;
  List<BiometricTypeInfo> _enabledBiometrics = [];

  // Validación de usuario
  String? _validateUser(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese su correo';
    }
    return null;
  }

  // Validación de contraseña
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese su contraseña';
    }
    return null;
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocusNode.dispose();
    _passFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _initBiometricVisibility();
    
    // Agregar listeners para detectar cuando el campo pierde el foco
    _userFocusNode.addListener(() {
      if (!_userFocusNode.hasFocus && _userController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
      }
    });
    
    _passFocusNode.addListener(() {
      if (!_passFocusNode.hasFocus && _passController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }
  
  // Función que centraliza el éxito del login
  Future<void> _handleLoginSuccess() async {
    await _authService.saveLoginState(); // Guardamos sesión en disco
    
    // Resetear estado de autorización en DataProvider
    if (!mounted) return;
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    dataProvider.resetUnauthorized();
    
    if (!mounted) return;
    
    // Navegamos al Home y eliminamos la pantalla de login del historial
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  // Login por botón
  void _loginWithPassword() async {
    // Validar el formulario
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    final email = _userController.text.trim();
    final pass = _passController.text.trim();

    if (email.isNotEmpty && pass.isNotEmpty) {
      final response = await _authService.login(email, pass);
      
      // Delay obligatorio de 1 segundo para mostrar al usuario que su petición está siendo procesada
      await Future.delayed(const Duration(seconds: 1));
      
      if (response != null) {
        // Guardar credenciales de forma segura para reactivación con biometría
        await _authService.saveCredentials(email, pass);
        await _handleLoginSuccess();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos'),
          backgroundColor: Colors.red,
        ),
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
        const SnackBar(
          content: Text('Esta biometría ha sido deshabilitada'),
          backgroundColor: Colors.green,
        ),
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
            const SnackBar(
              content: Text('Sesión expirada. Por favor inicia sesión con email y contraseña.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autenticación con ${biometric.displayName} fallida'),
          backgroundColor: Colors.green,
        ),
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
    final isBlocked = _isLoading;

    return PopScope(
      canPop: !isBlocked,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Image.asset('assets/images/cmapa_logo.png', height: 100, width: 100),
                          const SizedBox(height: 40),

                          // Campo Email
                          AbsorbPointer(
                            absorbing: isBlocked,
                            child: Opacity(
                              opacity: isBlocked ? 0.5 : 1.0,
                              child: TextFormField(
                                controller: _userController,
                                focusNode: _userFocusNode,
                                style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Correo',
                                  hintStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                                  prefixIcon: Icon(Icons.email_outlined, color: theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.primary),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateUser,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Campo Contraseña
                          AbsorbPointer(
                            absorbing: isBlocked,
                            child: Opacity(
                              opacity: isBlocked ? 0.5 : 1.0,
                              child: TextFormField(
                                controller: _passController,
                                focusNode: _passFocusNode,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  hintStyle: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                                  prefixIcon: Icon(Icons.lock_outline, color: theme.brightness == Brightness.dark ? Colors.white : Colors.black),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                                    ),
                                    onPressed: isBlocked ? null : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colorScheme.primary),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                ),
                                validator: _validatePassword,
                              ),
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
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? CircularProgressIndicator(color: Colors.green)
                                  : Text("Iniciar sesión", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
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
                    AbsorbPointer(
                      absorbing: isBlocked,
                      child: Opacity(
                        opacity: isBlocked ? 0.5 : 1.0,
                        child: Wrap(
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
