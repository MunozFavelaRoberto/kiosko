import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/add_card_screen.dart';
import 'package:kiosko/models/card.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:provider/provider.dart';

class CardsScreen extends StatefulWidget {
  static const routeName = '/cards';

  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  late List<CardModel> _cards;
  bool _isLoading = true;

  static const Map<String, String> brandLogos = {
    'visa': 'https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg',
    'mastercard': 'https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg',
    'amex': 'https://upload.wikimedia.org/wikipedia/commons/3/30/American_Express_logo.svg',
    'discover': 'https://upload.wikimedia.org/wikipedia/commons/5/57/Discover_Card_logo.svg',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final authService = context.read<AuthService>();
    final apiService = ApiService();
    final token = await authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    try {
      _cards = await apiService.getCards(headers: headers);
    } catch (e) {
      _cards = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tarjetas: $e')),
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
    final authService = context.read<AuthService>();
    final apiService = ApiService();
    final token = await authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    final body = {'user_card_id': card.id};

    try {
      final response = await apiService.post('/client/cards/favorite', headers: headers, body: body);
      // Reload cards to update the favorite status
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['msg'] ?? 'Tarjeta favorita actualizada')),
        );
      }
    } catch (e) {
      String errorMsg = 'Error al actualizar favorita';
      final errorStr = e.toString();
      if (errorStr.contains('Error HTTP')) {
        try {
          final startIndex = errorStr.indexOf('{');
          if (startIndex != -1) {
            final errorBody = errorStr.substring(startIndex);
            final errorJson = jsonDecode(errorBody);
            errorMsg = errorJson['msg'] ?? errorMsg;
          }
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  void _deleteCard(CardModel card) {
    _showNotImplemented('Eliminar tarjeta');
  }

  void _showNotImplemented(String action) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action: API no disponible aún')),
      );
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
                                      colors: [Color(0xFF3343a4), Color(0xFF5B6BC0)], // Azul base a azul más claro
                                      stops: [0.2, 1.0], // Extender colores fuertes
                                    )
                                  : isMastercard
                                      ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFFec7711), Color(0xFF5B6BC0)], // Naranja base a azul claro
                                          stops: [0.2, 1.0], // Extender colores fuertes
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
                                          const SizedBox(height: 24), // Ajuste para bajar los iconos
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
                                                onPressed: () => _deleteCard(card),
                                                tooltip: 'Eliminar tarjeta',
                                              ),
                                            ],
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
          ),
        ],
      ),
    );
  }
}
