import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/app_drawer.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.fetchUser();
      dataProvider.fetchCategories();
      dataProvider.fetchServices();
      dataProvider.fetchPayments();
    });
  }

  // Vistas para las pestañas principales
  late final List<Widget> _pages = <Widget>[
    Column(
      children: [
        const ClientNumberHeader(),
        Expanded(
          child: Consumer<DataProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading || provider.user == null) return const Center(child: CircularProgressIndicator());
              final user = provider.user!;
              final status = user.balance == 0 ? 'Pagado' : 'Pendiente';
              final statusColor = status == 'Pagado' ? Colors.green : Colors.yellow.shade800;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Estatus:', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 28,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Saldo:', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('\$${user.balance}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: status == 'Pendiente' ? () {
                          // Lógica para pagar
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pago procesado')),
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                        ),
                        child: const Text('Pagar', style: TextStyle(fontSize: 24)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
    Column(
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
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade700,
        title: Image.asset('assets/images/svr_logo.png', height: 40),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Menú',
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment),
            label: 'Pagos',
          ),
        ],
      ),
    );
  }
}