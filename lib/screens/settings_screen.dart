import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: const Center(child: Icon(Icons.settings, size: 100, color: Colors.grey)),
    );
  }
}