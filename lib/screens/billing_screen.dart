import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';

class BillingScreen extends StatelessWidget {
  static const routeName = '/billing';

  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: provider.payments.length,
                  itemBuilder: (context, index) {
                    final payment = provider.payments[index];
                    return ListTile(
                      title: Text('Pago ${payment.id}'),
                      subtitle: Text('Monto: \$${payment.amount} - Ref: ${payment.reference}'),
                      trailing: Text(payment.date.toLocal().toString().split(' ')[0]),
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
