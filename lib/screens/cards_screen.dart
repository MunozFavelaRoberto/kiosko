import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/add_card_screen.dart';
import 'package:kiosko/models/card.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/utils/error_helper.dart';
import 'package:provider/provider.dart';

enum CardsSelectionMode {
  view,    // Ver, editar, eliminar, agregar
  select,  // Seleccionar una tarjeta para pago
}

class CardsScreen extends StatefulWidget {
  static const routeName = '/cards';

  final CardsSelectionMode selectionMode;
  final CardModel? selectedCard;
  final Function(CardModel)? onSelect;

  const CardsScreen({
    super.key,
    this.selectionMode = CardsSelectionMode.view,
    this.selectedCard,
    this.onSelect,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  late List<CardModel> _cards;
  bool _isLoading = true;
  late AuthService _authService;
  final ApiService _apiService = ApiService(); // Singleton

  static const Map<String, String> brandLogos = {
    'visa': 'https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg',
    'mastercard': 'https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg',
    'amex': 'https://upload.wikimedia.org/wikipedia/commons/3/30/American_Express_logo.svg',
    'discover': 'https://upload.wikimedia.org/wikipedia/commons/5/57/Discover_Card_logo.svg',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = context.read<AuthService>();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    try {
      _cards = await _apiService.getCards(headers: headers);
    } catch (e) {
      _cards = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al cargar tarjetas'))),
        );
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePreferred(CardModel card) async {
    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    final body = {'user_card_id': card.id};

    try {
      final response = await _apiService.post('/client/cards/favorite', headers: headers, body: body);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? 'Tarjeta favorita actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al actualizar favorita'))),
        );
      }
    }
  }

  Future<void> _deleteCard(CardModel card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: const Text('¿Estás seguro de que quieres eliminar esta tarjeta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};

    try {
      final response = await _apiService.delete('/client/cards/${card.id}', headers: headers);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? 'Tarjeta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al eliminar tarjeta'))),
        );
      }
    }
  }

  void _addCard() {
    Navigator.pushNamed(context, AddCardScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarjetas'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cards.isEmpty
                    ? const Center(child: Text('No hay tarjetas registradas'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final String brand = card.brand.toLowerCase();
                          final bool isVisa = brand == 'visa';
                          final bool isMastercard = brand == 'mastercard';
                          final bool hasSpecialColor = isVisa || isMastercard;
                          final Color textColor = hasSpecialColor ? Colors.white : Colors.black;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: hasSpecialColor ? null : Colors.white,
                              gradient: isVisa
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3343a4), Color(0xFF5B6BC0)],
                                      stops: [0.2, 1.0],
                                    )
                                  : isMastercard
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
                                          card.cardNumber,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'monospace',
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      brandLogos.containsKey(card.brand.toLowerCase())
                                          ? SvgPicture.network(
                                              brandLogos[card.brand.toLowerCase()]!,
                                              height: 24,
                                              width: 48,
                                              fit: BoxFit.contain,
                                            )
                                          : Text(
                                              card.brand.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: textColor,
                                              ),
                                            ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Titular:', style: TextStyle(color: textColor)),
                                      Text(card.holderName, style: TextStyle(color: textColor)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Válida hasta:', style: TextStyle(color: textColor)),
                                            Text('${card.expirationMonth}/${card.expirationYear}', style: TextStyle(color: textColor)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          const SizedBox(height: 24),
                                          if (widget.selectionMode == CardsSelectionMode.view)
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    card.isFavorite == 1 ? Icons.star : Icons.star_border,
                                                    color: card.isFavorite == 1 ? Colors.amber : Colors.grey,
                                                  ),
                                                  onPressed: () async => await _togglePreferred(card),
                                                  tooltip: 'Marcar como preferida',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () async => await _deleteCard(card),
                                                  tooltip: 'Eliminar tarjeta',
                                                ),
                                              ],
                                            )
                                          else if (widget.selectionMode == CardsSelectionMode.select)
                                            IconButton(
                                              icon: Icon(
                                                widget.selectedCard?.id == card.id
                                                    ? Icons.check_circle
                                                    : Icons.radio_button_unchecked,
                                                color: widget.selectedCard?.id == card.id
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                              onPressed: widget.onSelect != null
                                                  ? () => widget.onSelect!(card)
                                                  : null,
                                              tooltip: 'Seleccionar esta tarjeta',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (widget.selectionMode == CardsSelectionMode.view)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _addCard,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Tarjeta'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            )
          else if (widget.selectionMode == CardsSelectionMode.select)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _addCard,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Nueva Tarjeta'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
