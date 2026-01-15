import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';

class CardsScreen extends StatelessWidget {
  static const routeName = '/cards';

  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: provider.services.length,
                  itemBuilder: (context, index) {
                    final service = provider.services[index];
                    return ListTile(
                      title: Text(service.name),
                      subtitle: Text(service.description),
                      trailing: Text(service.fee != null ? '\$${service.fee}' : 'N/A'),
                      onTap: () {
                        // Acción para pagar este servicio
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pagar ${service.name}')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
