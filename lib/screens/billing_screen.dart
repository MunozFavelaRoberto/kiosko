import 'package:flutter/material.dart';

class BillingScreen extends StatelessWidget {
  static const routeName = '/billing';

  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
      ),
      body: const Center(
        child: Text('Pantalla de Facturación'),
      ),
    );
  }
}
