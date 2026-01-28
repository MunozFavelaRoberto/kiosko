import 'package:flutter/material.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/edit_billing_screen.dart';

class BillingScreen extends StatelessWidget {
  static const routeName = '/billing';

  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: ListView(
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
                        title: const Text('Datos fiscales'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => Navigator.pushNamed(context, EditBillingScreen.routeName),
                          tooltip: 'Editar datos fiscales',
                        ),
                      ),
                      const Divider(),
                      const ListTile(
                        title: Text('RFC'),
                        subtitle: Text('XAXX010101000'),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Razón Social'),
                        subtitle: Text('CLIENTE DE PRUEBA S.A. DE C.V.'),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Código Postal'),
                        subtitle: Text('12345'),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Régimen Fiscal'),
                        subtitle: Text('601 - General de Ley Personas Morales'),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Uso de CFDI'),
                        subtitle: Text('G01 - Adquisición de mercancías'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
