import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:external_path/external_path.dart';
import 'package:kiosko/widgets/app_drawer.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/utils/app_routes.dart';

class InitialLoadingScreen extends StatelessWidget {
  const InitialLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/svr_logo.png', height: 80),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando información...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final Future<void> _initialDataFuture;

  @override
  void initState() {
    super.initState();
    // Iniciar carga de datos inmediatamente al crear el widget
    _initialDataFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final dataProvider = context.read<DataProvider>();
    await dataProvider.refreshAllData();
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
    return FutureBuilder<void>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        // Mientras carga, mostrar pantalla de carga completa
        if (snapshot.connectionState != ConnectionState.done) {
          return const InitialLoadingScreen();
        }

        // Si hay error, mostrar pantalla de error
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.grey.shade700,
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Error al cargar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          _initialDataFuture = _loadInitialData();
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Datos cargados, mostrar pantalla principal
        return _buildMainScreen();
      },
    );
  }

  Widget _buildMainScreen() {
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

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Future<void> _refreshData() async {
    final dataProvider = context.read<DataProvider>();
    await dataProvider.refreshAllData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: theme.colorScheme.primary,
      child: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: () {
              // Error de autorización
              if (provider.isUnauthorized) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No autorizado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await provider.refreshAllData();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Usuario null después de carga completa
              if (provider.user == null) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No autorizado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              final amount = provider.outstandingAmount;
              final status = amount <= 0 ? 'Pagado' : 'Pendiente';
              final statusColor = status == 'Pagado' ? Colors.green : Colors.yellow.shade800;
              
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Estatus:', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 28,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Monto:', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: status == 'Pendiente' ? () {
                            Navigator.pushNamed(context, AppRoutes.payment);
                          } : null,
                          icon: Icon(status == 'Pendiente' ? Icons.lock_open : Icons.lock),
                          iconAlignment: IconAlignment.end,
                          label: const Text('Pagar', style: TextStyle(fontSize: 24)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ),
        ],
      ),
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

  Future<void> _refreshData() async {
    final dataProvider = context.read<DataProvider>();
    await dataProvider.refreshAllData();
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

      // Decodificar base64
      final bytes = base64Decode(base64String);
      
      // Generar nombre del archivo
      final fileName = '$uiid.$extension';
      
      String finalFilePath;
      String message;
      
      if (Platform.isIOS) {
        // iOS: Guardar en Documents usando path_provider
        final documentsDir = await getApplicationDocumentsDirectory();
        final iosDir = Directory('${documentsDir.path}/Documents');
        
        // Crear directorio Documents si no existe
        if (!await iosDir.exists()) {
          await iosDir.create(recursive: true);
        }
        
        // Generar nombre único
        finalFilePath = '${iosDir.path}/$fileName';
        int counter = 1;
        while (await File(finalFilePath).exists()) {
          finalFilePath = '${iosDir.path}/$uiid ($counter).$extension';
          counter++;
        }
        
        message = '${fileType.toUpperCase()} guardado en Archivos';
      } else {
        // Android: Guardar en Downloads usando external_path
        String downloadsPath = await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD,
        );
        
        finalFilePath = '$downloadsPath/$fileName';
        int counter = 1;
        while (await File(finalFilePath).exists()) {
          finalFilePath = '$downloadsPath/$uiid ($counter).$extension';
          counter++;
        }
        
        message = '${fileType.toUpperCase()} guardado en Downloads';
      }
      
      // Guardar el archivo
      final file = File(finalFilePath);
      await file.writeAsBytes(bytes);
      
      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Archivo guardado'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubicación: $finalFilePath'),
                        const SizedBox(height: 8),
                        if (Platform.isIOS) ...[
                          const Text('Para ver el archivo:'),
                          const Text('1. Abre la app Archivos'),
                          const Text('2. Ve a Mi iPhone > Documentos'),
                          Text('3. Busca el archivo $fileName'),
                        ] else ...[
                          const Text('Para ver el archivo:'),
                          const Text('1. Abre la app Archivos'),
                          const Text('2. Ve a Almacenamiento > Download'),
                        ],
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
          ),
        );
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
    final isUnauthorized = provider.isUnauthorized;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: theme.colorScheme.primary,
      child: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: () {
              // Error de autorización después de carga completa
              if (isUnauthorized) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No autorizado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await _refreshData();
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Estado vacío
              if (payments.isEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 60,
                          color: Colors.grey.shade400,
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
                          'Tu historial de pagos aparecerá aquí',
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
      ),
    );
  }
}
