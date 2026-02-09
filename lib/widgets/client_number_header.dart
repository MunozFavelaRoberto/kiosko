import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/data_provider.dart';

class ClientNumberHeader extends StatelessWidget {
  const ClientNumberHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        String displayText;
        if (provider.isUnauthorized) {
          displayText = 'No autorizado';
        } else {
          displayText = provider.user?.clientNumber ?? 'No autorizado';
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Text(
            'No. Cliente: $displayText',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}