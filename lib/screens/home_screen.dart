 import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kiosko/widgets/app_drawer.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/utils/app_routes.dart';
import 'package:kiosko/utils/formatters.dart';

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
        indicatorColor: Colors.grey,
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
              if (!provider.hasAttemptedFetch) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              // Usuario null Y con error de autorización confirmado (sesión expirada)
              if (provider.user == null && provider.isUnauthorized) {
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
                          'Sesión expirada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            final dataProvider = Provider.of<DataProvider>(context, listen: false);
                            dataProvider.resetUnauthorized();
                            await authService.logout();
                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                          },
                          child: const Text('Volver al login'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Usuario null pero sin error de autorización (error de red)
              if (provider.user == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.grey.shade400, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Error de conexión',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text('No se pudo cargar la información', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refreshData, child: const Text('Reintentar')),
                    ],
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
                          getAmountFormat(amount.toString()),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: status == 'Pendiente' ? () {
                            Navigator.pushNamed(context, AppRoutes.payment);
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          ),
                          child: Text('Pagar', style: TextStyle(fontSize: 24, color: Colors.white)),
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
  // Loading por documento específico (key = "{paymentId}_{fileType}")
  final Set<String> _loadingDocuments = {};
  
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

  Future<void> _viewFile(String fileType, int paymentId, String uiid) async {
    // Marcar solo este botón como cargando
    setState(() {
      _loadingDocuments.add('${paymentId}_$fileType');
    });
    
    final provider = context.read<DataProvider>();
    
    try {
      String base64String;
      String extension;
      String title;

      if (fileType == 'pdf') {
        base64String = await provider.downloadInvoice(paymentId, 'pdf');
        extension = 'pdf';
        title = 'Factura PDF';
      } else if (fileType == 'xml') {
        base64String = await provider.downloadInvoice(paymentId, 'xml');
        extension = 'xml';
        title = 'Factura XML';
      } else {
        base64String = await provider.downloadTicket(paymentId);
        extension = 'pdf';
        title = 'Ticket de Pago';
      }

      if (!mounted) return;

      // Navegar al visualizador
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            base64String: base64String,
            fileName: '$uiid.$extension',
            title: title,
            fileType: fileType == 'xml' ? 'xml' : 'pdf',
          ),
        ),
      ).then((_) {
        // Regresar de la pantalla del visualizador
        if (mounted) {
          setState(() {
            _loadingDocuments.remove('${paymentId}_$fileType');
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDocuments.remove('${paymentId}_$fileType');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener documento: $e')),
      );
    }
  }

  bool _isLoading(String fileType, int paymentId) {
    return _loadingDocuments.contains('${paymentId}_$fileType');
  }

  bool _isAnyLoading() {
    return _loadingDocuments.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final payments = provider.paymentHistory;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: theme.colorScheme.primary,
      child: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: () {
              // Mientras está cargando inicialmente, mostrar indicador
              if (provider.isLoading && !provider.hasAttemptedFetch) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              // Usuario null Y con error de autorización confirmado (sesión expirada)
              if (provider.user == null && provider.isUnauthorized) {
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
                          'Sesión expirada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            final dataProvider = Provider.of<DataProvider>(context, listen: false);
                            dataProvider.resetUnauthorized();
                            await authService.logout();
                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                          },
                          child: const Text('Volver al login'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Usuario null pero sin error de autorización (error de red)
              if (provider.user == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, color: Colors.grey.shade400, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Error de conexión',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text('No se pudo cargar la información', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refreshData, child: const Text('Reintentar')),
                    ],
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
                                    getAmountFormat(payment.amount.toString()),
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
                                      icon: _isLoading('pdf', payment.id)
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.red,
                                              ),
                                            )
                                          : Icon(
                                              Icons.picture_as_pdf,
                                              color: _isAnyLoading() 
                                                  ? Colors.grey 
                                                  : Colors.red.shade700,
                                              size: 24,
                                            ),
                                      style: IconButton.styleFrom(
                                        foregroundColor: _isAnyLoading() 
                                            ? Colors.grey 
                                            : Colors.red.shade700,
                                        side: BorderSide(
                                          color: _isAnyLoading() 
                                              ? Colors.grey 
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                      tooltip: 'Ver factura en PDF',
                                      onPressed: _isAnyLoading()
                                          ? null
                                          : () {
                                              _viewFile('pdf', payment.id, payment.uiid);
                                            },
                                    ),
                                  ],
                                  // Botón XML - solo si tiene invoice_id
                                  if (payment.invoiceId != null) ...[
                                    IconButton.outlined(
                                      icon: _isLoading('xml', payment.id)
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.green,
                                              ),
                                            )
                                          : Icon(
                                              Icons.code,
                                              color: _isAnyLoading() 
                                                  ? Colors.grey 
                                                  : Colors.green.shade700,
                                              size: 24,
                                            ),
                                      style: IconButton.styleFrom(
                                        foregroundColor: _isAnyLoading() 
                                            ? Colors.grey 
                                            : Colors.green.shade700,
                                        side: BorderSide(
                                          color: _isAnyLoading() 
                                              ? Colors.grey 
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                      tooltip: 'Ver factura en XML',
                                      onPressed: _isAnyLoading()
                                          ? null
                                          : () {
                                              _viewFile('xml', payment.id, payment.uiid);
                                            },
                                    ),
                                  ],
                                  // Botón Ticket - solo si tiene transaction_id
                                  if (payment.transactionId != null) ...[
                                    IconButton.outlined(
                                      icon: _isLoading('ticket', payment.id)
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.blue,
                                              ),
                                            )
                                          : Icon(
                                              Icons.receipt_long,
                                              color: _isAnyLoading() 
                                                  ? Colors.grey 
                                                  : Colors.blue.shade700,
                                              size: 24,
                                            ),
                                      style: IconButton.styleFrom(
                                        foregroundColor: _isAnyLoading() 
                                            ? Colors.grey 
                                            : Colors.blue.shade700,
                                        side: BorderSide(
                                          color: _isAnyLoading() 
                                              ? Colors.grey 
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                      tooltip: 'Ver ticket de pago',
                                      onPressed: _isAnyLoading()
                                          ? null
                                          : () {
                                              _viewFile('ticket', payment.id, payment.uiid);
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

// Pantalla visualizadora de documentos (PDF y XML)
class DocumentViewerScreen extends StatefulWidget {
  final String base64String;
  final String fileName;
  final String title;
  final String fileType;

  const DocumentViewerScreen({
    super.key,
    required this.base64String,
    required this.fileName,
    required this.title,
    required this.fileType,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  String? _error;
  String? _filePath;
  String? _xmlContent;

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    try {
      final bytes = base64Decode(widget.base64String);
      
      // Si es XML, convertir a string para mostrar como texto
      if (widget.fileType == 'xml') {
        _xmlContent = utf8.decode(bytes);
      }
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.fileName}');
      await file.writeAsBytes(bytes);
      
      setState(() {
        _filePath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile() async {
    if (_filePath == null) return;
    
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_filePath!)],
          text: widget.title,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartir',
              onPressed: _shareFile,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando documento...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
            const SizedBox(height: 16),
            Text(
              'Error al cargar documento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.fileType == 'xml' && _xmlContent != null) {
      // Mostrar XML como texto con formato
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _xmlContent!,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      );
    }

    // Mostrar PDF
    return PDFView(
      filePath: _filePath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        debugPrint('Documento renderizado con $pages páginas');
      },
      onError: (error) {
        debugPrint('Error al renderizar PDF: $error');
      },
      onPageError: (page, error) {
        debugPrint('Error en página $page: $error');
      },
    );
  }
}
