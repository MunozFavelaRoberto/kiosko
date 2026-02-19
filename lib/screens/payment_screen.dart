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
import 'package:kiosko/screens/openpay_webview_screen.dart';
import 'package:kiosko/utils/error_helper.dart';
import 'package:kiosko/utils/app_routes.dart';
import 'package:kiosko/utils/formatters.dart';
import 'package:provider/provider.dart';

class PaymentScreen extends StatefulWidget {
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
  bool _isProcessingPayment = false;
  bool _isLoadingFiscalData = false;
  String? _deviceSessionId;
  final ValueNotifier<CardModel?> _selectedCardNotifier = ValueNotifier<CardModel?>(null);

  final ApiService _apiService = ApiService();

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
      
      // Reiniciar switch cada vez que se carga la pantalla
      _requiresInvoice = false;
      
      if (_selectedCard == null) {
        try {
          _selectedCard = _cards.firstWhere((card) => card.isFavorite == 1);
        } catch (_) {
          _selectedCard = _cards.isNotEmpty ? _cards.first : null;
        }
        _selectedCardNotifier.value = _selectedCard;
      } else {
        _selectedCard = _cards.firstWhere(
          (card) => card.id == _selectedCard!.id,
          orElse: () {
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

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    // Limpiar device session ID para forzar nueva obtención
    _deviceSessionId = null;
    await _loadData();
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
    final result = await Navigator.push<bool>(
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
              Navigator.pop(context, true);
            },
          ),
        ),
      ),
    );
    // Recargar datos si volvió de seleccionar tarjeta
    if (result == true) {
      _refreshData();
    }
  }

  void _changeFiscalData() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditBillingScreen()),
    );
    // Recargar solo los datos fiscales si volvió de editar información fiscal
    if (result == true) {
      _refreshFiscalData();
    }
  }

  Future<void> _refreshFiscalData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingFiscalData = true;
    });

    final authService = context.read<AuthService>();
    final token = await authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};

    try {
      final fiscalResponse = await _apiService.get('/client/fiscal_data', headers: headers);
      if (fiscalResponse != null && fiscalResponse['data'] != null) {
        if (mounted) {
          setState(() {
            _fiscalData = fiscalResponse['data']['item'] as Map<String, dynamic>;
            // El switch ya mantiene su estado actual, no se toca
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading fiscal data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos fiscales: $e')),
        );
      }
    } finally {
      // Delay para que el usuario vea el loading
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isLoadingFiscalData = false;
        });
      }
    }
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
                                      getAmountFormat(payment.amount.toString()),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
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

  void _pay() async {
    debugPrint('PaymentScreen: _pay() iniciado');
    
    if (_selectedCard == null) {
      debugPrint('PaymentScreen: Error - No hay tarjeta seleccionada');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una tarjeta')),
      );
      return;
    }

    debugPrint('PaymentScreen: Tarjeta seleccionada: ${_selectedCard!.cardNumber}');
    debugPrint('PaymentScreen: cardId (token): ${_selectedCard!.cardId}');

    // Obtener device session ID solo si no lo tenemos
    if (_deviceSessionId == null) {
      debugPrint('PaymentScreen: Obteniendo device session ID...');
      
      // Marcar como procesando desde el inicio
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = true;
      });
      
      try {
        final deviceResult = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => const OpenPayDeviceSessionScreen(),
          ),
        );

        debugPrint('PaymentScreen: deviceResult recibido: $deviceResult');

        if (!mounted) return;

        if (deviceResult == null || deviceResult.containsKey('error')) {
          // Error en device session - restablecer estado y mostrar error
          setState(() {
            _isProcessingPayment = false;
          });
          if (deviceResult != null && deviceResult.containsKey('error')) {
            debugPrint('PaymentScreen: Error en device session: ${deviceResult["error"]}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${deviceResult["error"]}')),
            );
          }
          return;
        }

        _deviceSessionId = deviceResult['device_session_id'] as String;
        debugPrint('PaymentScreen: Device session ID obtenido: $_deviceSessionId');
      } catch (e) {
        debugPrint('PaymentScreen: Excepción al obtener device session: $e');
        if (!mounted) return;
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener device session: $e')),
        );
        return;
      }
    }

    if (!mounted) return;

    // Asegurar que está en estado de procesamiento
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      // El card_id de la tarjeta ya es el token_id de OpenPay
      final tokenId = _selectedCard!.cardId;
      debugPrint('PaymentScreen: Enviando pago con tokenId: $tokenId');

      // Enviar el pago al servidor
      final authService = context.read<AuthService>();
      final token = await authService.getToken();
      
      if (!mounted) return;
      
      final headers = {'Authorization': 'Bearer $token'};

      final dataProvider = context.read<DataProvider>();
      final outstandingPayments = await _apiService.getOutstandingPayments(headers: headers);

      debugPrint('PaymentScreen: Payments obtenidos: ${outstandingPayments.length}');

      if (!mounted) return;

      final body = {
        'name': _selectedCard!.holderName,
        'last_name': 'Cliente',
        'token_id': tokenId,
        'device_session_id': _deviceSessionId,
        'use_card_points': null,
        'is_invoice_required': _requiresInvoice,
        'total': dataProvider.outstandingAmount,
        'payments': outstandingPayments.map((p) => {
          'payment_id': p.paymentId,
        }).toList(),
      };

      debugPrint('PaymentScreen: Enviando body: $body');
      
      await _apiService.post('/client/payments/pay', headers: headers, body: body);
      
      // Delay obligatorio de 1 segundo para mostrar al usuario que su petición está siendo procesada
      await Future.delayed(const Duration(seconds: 1));
      
      debugPrint('PaymentScreen: Pago exitoso!');

      if (!mounted) return;

      // Navegar a la pantalla de éxito (removiendo todas las pantallas anteriores)
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.paymentSuccess,
        (route) => route.isFirst,
      );
    } catch (e) {
      debugPrint('PaymentScreen: Error en pago: $e');
      if (!mounted) return;

      setState(() {
        _isProcessingPayment = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHelper.parseError(e.toString(), 
            defaultMsg: 'Error al procesar el pago')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCardDisplay() {
    if (_displayCard == null) {
      return const Center(child: Text('No hay tarjeta favorita seleccionada'));
    }
    
    final logoPath = CardModel.getBrandLogo(_displayCard!.brand);
    final colors = CardModel.getBrandColors(_displayCard!.brand);
    final isDarkColor = _displayCard!.brand.toLowerCase() != 'unknown';
    final textColor = isDarkColor ? Colors.white : Colors.black;
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors['primary']!, colors['secondary']!],
      stops: const [0.2, 1.0],
    );

    // Función helper para mostrar el logo desde assets
    Widget buildLogo() {
      if (logoPath.isEmpty) {
        return Text(
          _displayCard!.brand.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        );
      }
      
      if (logoPath.endsWith('.png')) {
        return Image.asset(
          logoPath,
          height: 30,
          width: 45,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              _displayCard!.brand.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            );
          },
        );
      } else {
        return SvgPicture.asset(
          logoPath,
          height: 30,
          width: 45,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Text(
            _displayCard!.brand.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: colors['primary']!.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: buildLogo(),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 40,
                bottom: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayCard!.cardNumber,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Courier New',
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Titular',
                              style: TextStyle(
                                fontSize: 9,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              _displayCard!.holderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Válida hasta',
                              style: TextStyle(
                                fontSize: 9,
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              _displayCard!.getFormattedExpiry(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _isProcessingPayment ? null : _changeCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Cambiar Tarjeta',
              style: TextStyle(
                color: _isProcessingPayment ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ),
      ],
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
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: colorScheme.primary,
        child: Column(
          children: [
            const ClientNumberHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
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
                                  getAmountFormat(amount.toString()),
                                  style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _isProcessingPayment ? null : _showPaymentDetails,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.lightBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  child: Text(
                                    'Detalle',
                                    style: TextStyle(
                                      color: _isProcessingPayment ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Tarjeta de Pago',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildCardDisplay(),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Switch(
                                value: _requiresInvoice,
                                onChanged: (_isProcessingPayment || _isLoadingFiscalData)
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _requiresInvoice = value;
                                        });
                                      },
                                activeThumbColor: colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Necesito factura',
                                style: TextStyle(
                                  color: (_isProcessingPayment || _isLoadingFiscalData) ? Colors.grey : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          if (_requiresInvoice) ...[
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
                                  onPressed: (_isProcessingPayment || _isLoadingFiscalData) ? null : _changeFiscalData,
                                  icon: _isLoadingFiscalData
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.edit,
                                          color: (_isProcessingPayment || _isLoadingFiscalData) ? Colors.grey : Colors.orange,
                                        ),
                                  label: Text(
                                    'Cambiar',
                                    style: TextStyle(
                                      color: (_isProcessingPayment || _isLoadingFiscalData) ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isLoadingFiscalData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Cargando información fiscal...'),
                                    ],
                                  ),
                                ),
                              )
                            else if (_fiscalData != null)
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
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: _isProcessingPayment ? null : _pay,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isProcessingPayment
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Procesando...', style: TextStyle(fontSize: 18)),
                                      ],
                                    )
                                  : const Text('Pagar con tarjeta seleccionada', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
