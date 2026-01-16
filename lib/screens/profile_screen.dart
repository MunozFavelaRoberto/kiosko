import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/services/theme_provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/models/biometric_type_info.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService;
  bool _loading = true;
  List<BiometricTypeInfo> _availableBiometrics = [];
  Map<String, bool> _biometricStates = {};

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    setState(() => _loading = true);

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
    final user = Provider.of<DataProvider>(context, listen: false).user;
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
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
      // Aquí podrías llamar a una API para actualizar el email
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Correo actualizado a: $newEmail')),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading || provider.user == null) {
                  return const Center(child: CircularProgressIndicator());
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
                            subtitle: Text(user.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: _editEmail,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32),
                    Card(
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
                    const Divider(height: 32),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_availableBiometrics.isEmpty)
                      Card(
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
                    else
                      Card(
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}