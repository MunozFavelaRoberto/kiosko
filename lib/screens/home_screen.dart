import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/app_drawer.dart';
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
      dataProvider.fetchCategories();
      dataProvider.fetchServices();
      dataProvider.fetchPayments();
    });
  }

  // Vistas para las pestañas principales
  late final List<Widget> _pages = <Widget>[
    Consumer<DataProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: provider.categories.length,
          itemBuilder: (context, index) {
            final category = provider.categories[index];
            return ListTile(
              title: Text(category.name),
              subtitle: Text(category.description),
              onTap: () {
                // Mostrar servicios de la categoría
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Servicios de ${category.name}')),
                );
              },
            );
          },
        );
      },
    ),
    Consumer<DataProvider>(
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
        title: const Text('Kiosko'),
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