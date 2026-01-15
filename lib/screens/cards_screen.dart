import 'package:flutter/material.dart';

class CardsScreen extends StatelessWidget {
  static const routeName = '/cards';

  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarjetas'),
      ),
      body: const Center(
        child: Text('Pantalla de Tarjetas'),
      ),
    );
  }
}
