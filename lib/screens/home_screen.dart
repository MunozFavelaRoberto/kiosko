import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
      dataProvider.fetchPaymentHistory();
    });
  }

  // Vistas para las pestañas principales
  late final List<Widget> _pages = <Widget>[
    const HomeTab(),
    const PaymentsTab(),
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

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    
    return Column(
      children: [
        const ClientNumberHeader(),
        Expanded(
          child: () {
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
          }(),
        ),
      ],
    );
  }
}

class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  String _formatDate(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _getPaymentDescription(dynamic payment) {
    if (payment.paymentItems != null && payment.paymentItems.isNotEmpty) {
      return payment.paymentItems[0].payment?.description ?? 'Sin descripción';
    }
    return 'Sin descripción';
  }

  Future<void> _downloadFile(String fileType, int paymentId, String uiid) async {
    final provider = context.read<DataProvider>();
    
    try {
      String base64String;
      String extension;

      if (fileType == 'pdf') {
        base64String = await provider.downloadInvoice(paymentId, 'pdf');
        extension = 'pdf';
      } else if (fileType == 'xml') {
        base64String = await provider.downloadInvoice(paymentId, 'xml');
        extension = 'xml';
      } else {
        base64String = await provider.downloadTicket(paymentId);
        extension = 'pdf';
      }

      // Decodificar base64 y guardar archivo
      final bytes = base64Decode(base64String);
      
      // Obtener nombre de la app dinámicamente
      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName;
      
      final directory = await getApplicationDocumentsDirectory();
      
      // Generar nombre único para evitar sobrescribir
      String finalFilePath = '${directory.path}/$uiid.$extension';
      int counter = 1;
      while (await File(finalFilePath).exists()) {
        finalFilePath = '${directory.path}/$uiid ($counter).$extension';
        counter++;
      }
      
      final file = File(finalFilePath);
      await file.writeAsBytes(bytes);

      // Mostrar ubicación del archivo
      if (mounted) {
        final snackBar = SnackBar(
          content: Text('${fileType.toUpperCase()} descargado'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Ver ubicación',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('${fileType.toUpperCase()} descargado'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Archivo guardado en:'),
                      const SizedBox(height: 8),
                      SelectableText(
                        finalFilePath,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Para ver el archivo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('1. Abre la app Archivos'),
                      Text('2. Busca los archivos $appName en la lista'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        
        // Cerrar automáticamente después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final payments = provider.paymentHistory;
    final isLoading = provider.isLoading;
    final isUnauthorized = provider.isUnauthorized;

    return Column(
      children: [
        const ClientNumberHeader(),
        Expanded(
          child: () {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (isUnauthorized) {
              return const Center(
                child: Text(
                  'No autorizado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              );
            }

            // Estado vacío
            if (payments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_off,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay pagos registrados',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No se encontraron pagos para este cliente',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Grid de pagos
            return LayoutBuilder(
              builder: (context, constraints) {
                // Determinar número de columnas según el ancho
                int crossAxisCount = 1;
                if (constraints.maxWidth >= 600) crossAxisCount = 2;
                if (constraints.maxWidth >= 900) crossAxisCount = 3;
                if (constraints.maxWidth >= 1200) crossAxisCount = 4;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.10,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return Card(
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Folio y estatus
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Folio',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        payment.uiid,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Pagado',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      textBaseline: TextBaseline.alphabetic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            // Descripción
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Descripción',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getPaymentDescription(payment),
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Fecha
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fecha',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(payment.createdAt),
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Monto
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${payment.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                             const SizedBox(height: 8),
                            // Botones de acción
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Botón PDF - solo si tiene invoice_id
                                if (payment.invoiceId != null) ...[
                                  IconButton.outlined(
                                    icon: Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red.shade700,
                                      size: 24,
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(color: Colors.red.shade700),
                                    ),
                                    tooltip: 'Descargar factura en PDF',
                                    onPressed: () {
                                      _downloadFile('pdf', payment.id, payment.uiid);
                                    },
                                  ),
                                ],
                                // Botón XML - solo si tiene invoice_id
                                if (payment.invoiceId != null) ...[
                                  IconButton.outlined(
                                    icon: Icon(
                                      Icons.code,
                                      color: Colors.green.shade700,
                                      size: 24,
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      side: BorderSide(color: Colors.green.shade700),
                                    ),
                                    tooltip: 'Descargar factura en XML',
                                    onPressed: () {
                                      _downloadFile('xml', payment.id, payment.uiid);
                                    },
                                  ),
                                ],
                                // Botón Ticket - solo si tiene transaction_id
                                if (payment.transactionId != null) ...[
                                  IconButton.outlined(
                                    icon: Icon(
                                      Icons.receipt_long,
                                      color: Colors.blue.shade700,
                                      size: 24,
                                    ),
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.blue.shade700,
                                      side: BorderSide(color: Colors.blue.shade700),
                                    ),
                                    tooltip: 'Descargar ticket de pago',
                                    onPressed: () {
                                      _downloadFile('ticket', payment.id, payment.uiid);
                                    },
                                  ),
                                ],
                                // Mensaje si no tiene documentos
                                if (payment.invoiceId == null && payment.transactionId == null) ...[
                                  Text(
                                    'Sin documentos disponibles',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }(),
        ),
      ],
    );
  }
}
