import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/edit_billing_screen.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/data_provider.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late final ApiService _apiService;
  late final AuthService _authService;
  Map<String, dynamic>? _fiscalData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Los servicios se obtienen en didChangeDependencies para asegurar que están disponibles
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = context.read<ApiService>();
    _authService = context.read<AuthService>();
    // Solo cargar datos fiscales si hay un usuario autenticado
    final dataProvider = context.read<DataProvider>();
    if (dataProvider.user != null) {
      _loadFiscalData();
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadFiscalData() async {
    setState(() => _loading = true);

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final response = await _apiService.get('/client/fiscal_data', headers: {'Authorization': 'Bearer $token'});
        if (response != null && response['data'] != null) {
          _fiscalData = response['data']['item'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error loading fiscal data: $e');
    }

    if (mounted) {
      // Delay obligatorio de 1 segundo para mostrar indicador de carga
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadFiscalData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: colorScheme.primary,
        child: Column(
          children: [
            const ClientNumberHeader(),
            Expanded(
              child: Consumer<DataProvider>(
                builder: (context, dataProvider, child) {
                  // Usuario null después de carga completa - mostrar "No autorizado"
                  if (!dataProvider.isLoading && dataProvider.user == null) {
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

                  // Mostrar indicador de carga
                  if (_loading) {
                    return const SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Cargando facturación...'),
                          ],
                        ),
                      ),
                    );
                  }

                  // Sin datos fiscales
                  if (_fiscalData == null) {
                    return const Center(child: Text('No hay datos fiscales disponibles'));
                  }

                  // Mostrar datos fiscales
                  return ListView(
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
                              trailing: IconButton.outlined(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () async {
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (context) => const EditBillingScreen()),
                                  );
                                  if (result == true) {
                                    _refreshData();
                                  }
                                },
                                tooltip: 'Editar datos fiscales',
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('RFC'),
                              subtitle: Text(_fiscalData!['code'] ?? 'N/A'),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Razón Social'),
                              subtitle: Text(_fiscalData!['name'] ?? 'N/A'),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Código Postal'),
                              subtitle: Text(_fiscalData!['zip'] ?? 'N/A'),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Régimen Fiscal'),
                              subtitle: Text(_fiscalData!['fiscal_regime'] != null
                                  ? '${_fiscalData!['fiscal_regime']['code']} - ${_fiscalData!['fiscal_regime']['name']}'
                                  : 'N/A'),
                            ),
                            const Divider(),
                            ListTile(
                              title: const Text('Uso de CFDI'),
                              subtitle: Text(_fiscalData!['cfdi_usage'] != null
                                  ? '${_fiscalData!['cfdi_usage']['code']} - ${_fiscalData!['cfdi_usage']['name']}'
                                  : 'N/A'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
