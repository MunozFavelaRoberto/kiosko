import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/auth_service.dart';
import '../models/biometric_type_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;
  List<BiometricTypeInfo> _availableBiometrics = [];
  Map<String, bool> _biometricStates = {};

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEnabledBiometric = _biometricStates.values.any((v) => v);
    final isDark = context.select<ThemeProvider, bool>((p) => p.isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          
          // Sección: Apariencia
          _buildSectionHeader("Apariencia"),
          
          Card(
            elevation: 0,
            color: isDark 
                ? theme.colorScheme.surface.withAlpha(230)
                : theme.colorScheme.surface,
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
          
          const SizedBox(height: 24),
          
          // Sección: Seguridad
          _buildSectionHeader("Seguridad biométrica"),
          
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
          else ...[
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
                          Divider(height: 1, indent: 72, endIndent: 16),
                      ],
                    );
                  }).toList(),
                  
                  // Estado de biometría
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
          
          const SizedBox(height: 32),
          
          // Sección: Acerca de
          _buildSectionHeader("Acerca de"),
          
          Card(
            elevation: 0,
            color: theme.colorScheme.surface.withAlpha(230),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("Versión"),
              subtitle: Text("1.0.0"),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }
}
