import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/models/card.dart';
import 'package:kiosko/models/payment_detail.dart' as payment_detail;
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/screens/cards_screen.dart';
import 'package:kiosko/screens/edit_billing_screen.dart';
import 'package:kiosko/utils/error_helper.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatefulWidget {
  static const routeName = '/payment';

  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late List<CardModel> _cards;
  CardModel? _selectedCard;
  Map<String, dynamic>? _fiscalData;
  bool _isLoading = true;
  bool _requiresInvoice = false;
  // ValueNotifier para compartir el estado de tarjeta seleccionada con CardsScreen
  final ValueNotifier<CardModel?> _selectedCardNotifier = ValueNotifier<CardModel?>(null);

  final ApiService _apiService = ApiService();

  static const Map<String, String> brandLogos = {
    'visa': 'https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg',
    'mastercard': 'https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg',
    'amex': 'https://upload.wikimedia.org/wikipedia/commons/3/30/American_Express_logo.svg',
    'discover': 'https://upload.wikimedia.org/wikipedia/commons/5/57/Discover_Card_logo.svg',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      if (dataProvider.user == null) {
        dataProvider.fetchUser();
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final authService = context.read<AuthService>();
    final token = await authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};

    try {
      _cards = await _apiService.getCards(headers: headers);
      final fiscalResponse = await _apiService.get('/client/fiscal_data', headers: headers);
      if (fiscalResponse != null && fiscalResponse['data'] != null) {
        _fiscalData = fiscalResponse['data']['item'] as Map<String, dynamic>;
      }
      // Si ya tenemos una tarjeta seleccionada por el usuario, mantenerla
      if (_selectedCard == null) {
        // Primera vez: seleccionar la favorita o la primera tarjeta
        try {
          _selectedCard = _cards.firstWhere((card) => card.isFavorite == 1);
        } catch (_) {
          _selectedCard = _cards.isNotEmpty ? _cards.first : null;
        }
        // Actualizar el notifier
        _selectedCardNotifier.value = _selectedCard;
      } else {
        // Verificar que la tarjeta seleccionada aún existe en la lista
        _selectedCard = _cards.firstWhere(
          (card) => card.id == _selectedCard!.id,
          orElse: () {
            // Si la tarjeta ya no existe, seleccionar la favorita o la primera
            try {
              return _cards.firstWhere((card) => card.isFavorite == 1);
            } catch (_) {
              return _cards.isNotEmpty ? _cards.first : _selectedCard!;
            }
          },
        );
      }
    } catch (e) {
      _cards = [];
      debugPrint('Error loading payment data: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _selectedCardNotifier.dispose();
    super.dispose();
  }

  CardModel? get _displayCard {
    if (_selectedCard != null) return _selectedCard;
    if (_cards.isEmpty) return null;
    try {
      return _cards.firstWhere((card) => card.isFavorite == 1);
    } catch (_) {
      return _cards.first;
    }
  }

  void _changeCard() async {
    final selectedCard = await Navigator.push<CardModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ValueListenableBuilder<CardModel?>(
          valueListenable: _selectedCardNotifier,
          builder: (context, currentCard, child) => CardsScreen(
            selectionMode: CardsSelectionMode.select,
            selectedCard: currentCard,
            onSelect: (card) {
              _selectedCard = card;
              _selectedCardNotifier.value = card;
              Navigator.pop(context, card);
            },
          ),
        ),
      ),
    );
    if (selectedCard != null) {
      setState(() {
        _selectedCard = selectedCard;
      });
    }
  }

  void _changeFiscalData() {
    Navigator.pushNamed(context, EditBillingScreen.routeName);
  }

  Future<void> _showPaymentDetails() async {
    final authService = context.read<AuthService>();
    final token = await authService.getToken();
    
    if (!mounted) return;
    
    final headers = {'Authorization': 'Bearer $token'};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Detalle de pagos'),
        content: FutureBuilder<List<payment_detail.PaymentDetail>>(
          future: _apiService.getOutstandingPayments(headers: headers),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                heightFactor: 1.0,
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                heightFactor: 1.0,
                child: Text(
                  ErrorHelper.parseError(snapshot.error.toString(), 
                    defaultMsg: 'Error al cargar detalles'),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return const Center(
                heightFactor: 1.0,
                child: Text('No hay pagos pendientes'),
              );
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Folio:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      payment.uiid,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Monto:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '\$${payment.amount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Descripción:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            payment.description,
                            style: const TextStyle(fontSize: 14),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _pay() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pago no implementado aún')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dataProvider = context.watch<DataProvider>();
    final amount = dataProvider.outstandingAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // Monto
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Total',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${amount.toStringAsFixed(2)}',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _showPaymentDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                ),
                                child: const Text('Detalle'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Tarjeta favorita
                        Text(
                          'Tarjeta de Pago',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_displayCard != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _displayCard!.brand.toLowerCase() == 'visa' ? const Color(0xFF3343a4) : null,
                              gradient: _displayCard!.brand.toLowerCase() == 'visa'
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3343a4), Color(0xFF5B6BC0)],
                                      stops: [0.2, 1.0],
                                    )
                                  : _displayCard!.brand.toLowerCase() == 'mastercard'
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFFec7711), Color(0xFF5B6BC0)],
                                          stops: [0.2, 1.0],
                                        )
                                      : null,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _displayCard!.cardNumber,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'monospace',
                                            color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      brandLogos.containsKey(_displayCard!.brand.toLowerCase())
                                          ? SvgPicture.network(
                                              brandLogos[_displayCard!.brand.toLowerCase()]!,
                                              height: 24,
                                              width: 48,
                                              fit: BoxFit.contain,
                                            )
                                          : Text(
                                              _displayCard!.brand.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black,
                                              ),
                                            ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Titular:', style: TextStyle(color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black)),
                                      Text(_displayCard!.holderName, style: TextStyle(color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Válida hasta:', style: TextStyle(color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black)),
                                      Text('${_displayCard!.expirationMonth}/${_displayCard!.expirationYear}', style: TextStyle(color: _displayCard!.brand.toLowerCase() == 'visa' || _displayCard!.brand.toLowerCase() == 'mastercard' ? Colors.white : Colors.black)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: ElevatedButton(
                              onPressed: _changeCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Cambiar Tarjeta'),
                            ),
                          ),
                        ] else ...[
                          const Center(child: Text('No hay tarjeta favorita seleccionada')),
                        ],
                        const SizedBox(height: 32),
                        // Switch para factura
                        Row(
                          children: [
                            Switch(
                              value: _requiresInvoice,
                              onChanged: (value) {
                                setState(() {
                                  _requiresInvoice = value;
                                });
                              },
                              activeThumbColor: colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            const Text('Necesito factura'),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Datos fiscales (solo si necesita factura)
                        if (_requiresInvoice) ...[
                          // Datos fiscales
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Información fiscal',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _changeFiscalData,
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                label: const Text('Cambiar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_fiscalData != null)
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
                            )
                          else
                            const Center(child: Text('No hay datos fiscales disponibles')),
                          const SizedBox(height: 32),
                        ],
                        // Botón de pagar (siempre visible)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _pay,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Pagar', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
