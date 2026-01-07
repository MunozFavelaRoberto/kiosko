import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  bool _deviceSupportsBiometrics = false;
  bool _useBiometrics = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final can = await _authService.canCheckBiometrics;
    final use = await _authService.getUseBiometrics();
    if (!mounted) return;
    setState(() {
      _deviceSupportsBiometrics = can;
      _useBiometrics = use;
      _loading = false;
    });
  }

  Future<void> _onToggleBiometrics(bool val) async {
    if (val) {
      // Al habilitar, pedimos autenticación inmediata para confirmar
      final ok = await _authService.authenticate();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo activar la biometría')));
        return;
      }
    }

    await _authService.setUseBiometrics(val);
    if (!mounted) return;
    setState(() => _useBiometrics = val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return SwitchListTile(
                title: const Text('Modo oscuro'),
                value: theme.isDark,
                onChanged: (val) async {
                  await theme.setDark(val);
                },
                secondary: const Icon(Icons.dark_mode),
              );
            },
          ),
          const Divider(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_deviceSupportsBiometrics)
              SwitchListTile(
                title: const Text('Habilitar Huella'),
                value: _useBiometrics,
                onChanged: (val) async {
                  await _onToggleBiometrics(val);
                },
                secondary: const Icon(Icons.fingerprint),
              )
            else
              const ListTile(
                leading: Icon(Icons.block),
                title: Text('Biometría no disponible'),
                subtitle: Text('Tu dispositivo no soporta huella o FaceID'),
              ),

            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Acerca de'),
              subtitle: Text('Versión 1.0.0'),
            ),
          ],
        ],
      ),
    );
  }
}