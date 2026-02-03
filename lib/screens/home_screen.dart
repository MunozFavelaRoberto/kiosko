import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/app_drawer.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/screens/payment_screen.dart';

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
      dataProvider.fetchOutstandingPayments();
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
              if (provider.isLoading) return const Center(child: CircularProgressIndicator());
              if (provider.isUnauthorized) return const Center(child: Text('No autorizado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)));
              if (provider.user == null) return const Center(child: Text('Error al cargar usuario'));
              final amount = provider.outstandingAmount;
              final status = amount <= 0 ? 'Pagado' : 'Pendiente';
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
                      Text('Monto:', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: status == 'Pendiente' ? () {
                          Navigator.pushNamed(context, PaymentScreen.routeName);
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
                padding: const EdgeInsets.all(16),
                itemCount: provider.payments.length,
                itemBuilder: (context, index) {
                  final payment = provider.payments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Folio: ${payment.folio ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Fecha: ${payment.date.year}-${payment.date.month.toString().padLeft(2, '0')}-${payment.date.day.toString().padLeft(2, '0')}'),
                          const SizedBox(height: 8),
                          Text('Servicio: ${payment.serviceName}'),
                          const SizedBox(height: 8),
                          Text('Monto: \$${payment.amount}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Estatus: '),
                              Text(
                                payment.status,
                                style: TextStyle(
                                  color: payment.status == 'Pagado' ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (payment.status == 'Pagado') ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descargando Factura XML'))),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset('assets/images/file_xml_box.svg', height: 24, width: 24),
                                      const SizedBox(height: 4),
                                      const Text('Factura', textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descargando Factura PDF'))),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, size: 24),
                                      const SizedBox(height: 4),
                                      const Text('Factura', textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descargando Recibo PDF'))),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, size: 24),
                                      const SizedBox(height: 4),
                                      const Text('Recibo', textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
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
          IconButton.outlined(
            icon: const Icon(Icons.menu, color: Colors.white),
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