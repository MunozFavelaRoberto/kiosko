import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inicio Kiosko")),
      drawer: const AppDrawer(), // Aquí inyectamos el Drawer
      body: const Center(child: Text("Bienvenido al Kiosko")),
    );
  }
}