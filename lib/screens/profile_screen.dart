import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/services/theme_provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/models/biometric_type_info.dart';
import 'package:kiosko/models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService;
  late final ApiService _apiService;
  bool _loading = true;
  bool _isUpdatingEmail = false; // Para mostrar indicador de carga durante actualización de email
  List<BiometricTypeInfo> _availableBiometrics = [];
  Map<String, bool> _biometricStates = {};
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = ApiService();
    // Cargar biometrías siempre, sin depender del usuario
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    try {
      final biometrics = await _authService.getAvailableBiometrics();

      // Normalizar: combinar strong/weak en "Huella Digital"
      final normalizedBiometrics = <BiometricTypeInfo>[];
      final addedTypes = <String>{};

      for (final biometric in biometrics) {
        if (addedTypes.contains(biometric.displayName)) continue;

        normalizedBiometrics.add(biometric);
        addedTypes.add(biometric.displayName);
      }

      final states = <String, bool>{};
      for (final biometric in normalizedBiometrics) {
        final enabled = await _authService.isBiometricEnabled(biometric.type);
        states[biometric.displayName] = enabled;
      }

      if (!mounted) return;
      // Delay obligatorio de 1 segundo para mostrar indicador de carga
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _availableBiometrics = normalizedBiometrics;
        _biometricStates = states;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error cargando biometrías: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    // Resetear flag para permitir recargar el usuario
    if (mounted) {
      setState(() => _initialLoadComplete = false);
    }
    final dataProvider = context.read<DataProvider>();
    await dataProvider.fetchUser();
    await _loadBiometrics();
  }

  Future<void> _onToggleBiometric(BiometricTypeInfo biometric, bool value) async {
    if (value) {
      final ok = await _authService.authenticateWithType(biometric.type);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo activar ${biometric.displayName}')),
        );
        return;
      }
    }

    await _authService.setBiometricEnabled(biometric.type, value);

    if (!mounted) return;
    setState(() {
      _biometricStates[biometric.displayName] = value;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? '${biometric.displayName} activado'
            : '${biometric.displayName} desactivado'),
      ),
    );
  }

  Future<void> _editEmail() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final user = dataProvider.user;
    if (user == null) return;

    final controller = TextEditingController(text: user.email);
    String? errorText;

    final newEmail = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Editar correo electrónico',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Nuevo correo electrónico',
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (value) {
                          setState(() {
                            errorText = _validateEmail(value) ? null : 'Correo electrónico inválido';
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              final email = controller.text.trim();
                              if (_validateEmail(email) && email != user.email) {
                                Navigator.pop(context, email);
                              } else if (email == user.email) {
                                setState(() {
                                  errorText = 'El correo es el mismo';
                                });
                              } else {
                                setState(() {
                                  errorText = 'Correo electrónico inválido';
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Guardar', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (newEmail != null) {
      // Mostrar indicador de carga
      setState(() {
        _isUpdatingEmail = true;
      });
      
      // Llamar a la API para actualizar el email
      final token = await _authService.getToken();
      if (token == null) {
        setState(() {
          _isUpdatingEmail = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay token de autenticación')),
        );
        return;
      }

      try {
        final response = await _apiService.post('/client/profile', headers: {
          'Authorization': 'Bearer $token',
        }, body: {
          'email': newEmail,
        });

        if (response != null && response['msg'] == 'Registro editado correctamente') {
          // Actualizar el usuario localmente
          if (dataProvider.user != null) {
            final updatedUser = User(
              clientNumber: dataProvider.user!.clientNumber,
              status: dataProvider.user!.status,
              balance: dataProvider.user!.balance,
              fullName: dataProvider.user!.fullName,
              email: newEmail,
            );
            dataProvider.updateUser(updatedUser);
          }

          // Delay obligatorio de 1 segundo para mostrar al usuario que su petición está siendo procesada
          await Future.delayed(const Duration(seconds: 1));
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correo actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al actualizar el correo')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingEmail = false;
          });
        }
      }
    }
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEnabledBiometric = _biometricStates.values.any((v) => v);
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDark);

    return PopScope(
      canPop: !_isUpdatingEmail,
      onPopInvokedWithResult: (didPop, result) {
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: _isUpdatingEmail 
                  ? Theme.of(context).iconTheme.color?.withValues(alpha: 0.3) 
                  : null,
            ),
            onPressed: _isUpdatingEmail ? null : () => Navigator.pop(context),
          ),
          title: const Text('Mi perfil'),
        ),
        body: AbsorbPointer(
        absorbing: _isUpdatingEmail,
        child: RefreshIndicator(
          onRefresh: _isUpdatingEmail ? () async {} : _refreshData,
          color: theme.colorScheme.primary,
          child: Column(
          children: [
            const ClientNumberHeader(),
            Expanded(
              child: Consumer<DataProvider>(
                builder: (context, provider, child) {
                  // Si no está autorizado, mostrar "No autorizado"
                  if (provider.isUnauthorized) {
                    // Marcar que ya intentamos cargar
                    if (!_initialLoadComplete) {
                      _initialLoadComplete = true;
                    }
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'No autorizado',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Si el usuario es null, intentar cargarlo UNA SOLA VEZ
                  // Solo mostrar indicador de carga si isLoading es true Y user es null
                  if (_loading) {
                    // Loading general de la vista - mostrar indicador de carga completo
                    return const SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cargando perfil...'),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  if (provider.user == null) {
                    if (provider.isLoading) {
                      // Está cargando, mostrar indicador
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // No está cargando pero user es null - intentar cargar
                    if (!provider.hasAttemptedFetch) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        provider.fetchUser();
                      });
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // Ya intentamos cargar y sigue siendo null - podría ser error de red
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off, color: Colors.grey.shade400, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Error de conexión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No se pudo cargar los datos del perfil',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final dataProvider = context.read<DataProvider>();
                                await dataProvider.fetchUser();
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final user = provider.user!;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surface.withAlpha(230),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Nombre completo'),
                              subtitle: Text(user.fullName),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Correo electrónico'),
                              subtitle: _isUpdatingEmail
                                  ? const Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Actualizando...'),
                                      ],
                                    )
                                  : Text(user.email),
                              trailing: _isUpdatingEmail
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton.outlined(
                                      icon: const Icon(Icons.edit, color: Colors.orange),
                                      onPressed: _editEmail,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 32),
                      AbsorbPointer(
                        absorbing: _isUpdatingEmail,
                        child: Opacity(
                          opacity: _isUpdatingEmail ? 0.5 : 1.0,
                          child: Card(
                            elevation: 0,
                            color: theme.colorScheme.surface.withAlpha(230),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isDark ? Icons.dark_mode : Icons.light_mode,
                                color: theme.colorScheme.primary,
                              ),
                              title: const Text("Modo oscuro"),
                              trailing: Switch(
                                value: isDark,
                                onChanged: (val) async {
                                  final themeProvider = context.read<ThemeProvider>();
                                  await themeProvider.setDark(val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      AbsorbPointer(
                        absorbing: _isUpdatingEmail,
                        child: Opacity(
                          opacity: _isUpdatingEmail ? 0.5 : 1.0,
                          child: _availableBiometrics.isEmpty
                              ? Card(
                                  elevation: 0,
                                  color: theme.colorScheme.surface.withAlpha(230),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const ListTile(
                                    leading: Icon(Icons.no_flash, color: Colors.grey),
                                    title: Text("No disponible"),
                                    subtitle: Text("Tu dispositivo no admite biometría"),
                                  ),
                                )
                              : Card(
                                  elevation: 0,
                                  color: theme.colorScheme.surface.withAlpha(230),
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      ..._availableBiometrics.map((biometric) {
                                        final isEnabled = _biometricStates[biometric.displayName] ?? false;
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading: Icon(biometric.icon, color: theme.colorScheme.primary),
                                              title: Text(biometric.displayName),
                                              trailing: Switch(
                                                value: isEnabled,
                                                onChanged: (val) => _onToggleBiometric(biometric, val),
                                              ),
                                            ),
                                            if (_availableBiometrics.last != biometric)
                                              const Divider(height: 1, indent: 72, endIndent: 16),
                                          ],
                                        );
                                      }),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: hasEnabledBiometric
                                              ? Colors.green.withAlpha(20)
                                              : Colors.orange.withAlpha(20),
                                          borderRadius: const BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              hasEnabledBiometric ? Icons.check_circle : Icons.info,
                                              size: 18,
                                              color: hasEnabledBiometric ? Colors.green : Colors.orange,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              hasEnabledBiometric
                                                  ? "Seguridad activa"
                                                  : "Sin biometría activada",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: hasEnabledBiometric ? Colors.green.shade700 : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ), // closes RefreshIndicator
      ), // closes AbsorbPointer
      ), // closes Scaffold
    ); // closes PopScope
  }
}
