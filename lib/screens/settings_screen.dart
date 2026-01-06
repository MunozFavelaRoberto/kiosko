import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text('Versión 1.0.0'),
          ),
        ],
      ),
    );
  }
}