import 'package:flutter/material.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/edit_billing_screen.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/api_service.dart';

class BillingScreen extends StatefulWidget {
  static const routeName = '/billing';

  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late final AuthService _authService;
  late final ApiService _apiService;
  Map<String, dynamic>? _fiscalData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _apiService = ApiService();
    _loadFiscalData();
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
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _fiscalData == null
                    ? const Center(child: Text('No hay datos fiscales disponibles'))
                    : ListView(
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
                                    onPressed: () => Navigator.pushNamed(context, EditBillingScreen.routeName),
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
                      ),
          ),
        ],
      ),
    );
  }
}
