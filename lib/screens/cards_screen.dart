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
  view,
  select,
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
  final ApiService _apiService = ApiService();

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

  Future<void> _refreshCards() async {
    await _loadCards();
  }

  Future<void> _toggleFavorite(int cardId, CardModel card) async {
    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    final body = {'user_card_id': cardId};

    try {
      await _apiService.post('/client/cards/favorite', headers: headers, body: body);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta establecida como principal')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al establecer favorita'))),
        );
      }
    }
  }

  Future<void> _deleteCard(int cardId, CardModel card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('¿Estás seguro de eliminar la tarjeta terminada en ${card.cardNumber}?'),
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
      await _apiService.delete('/client/cards/$cardId', headers: headers);
      await _loadCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta eliminada exitosamente')),
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

  void _addCard() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddCardScreen()),
    );
    // Recargar tarjetas si se agregó una nueva
    if (result == true) {
      _refreshCards();
    }
  }

  Widget _buildCardWidget(CardModel card) {
    final logoUrl = CardModel.getBrandLogo(card.brand);
    final colors = CardModel.getBrandColors(card.brand);
    final isDarkColor = card.brand.toLowerCase() != 'unknown';
    final textColor = isDarkColor ? Colors.white : Colors.black;
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors['primary']!, colors['secondary']!],
      stops: const [0.2, 1.0],
    );

    return Container(
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
            child: logoUrl.isNotEmpty
                ? SvgPicture.network(
                    logoUrl,
                    height: 30,
                    width: 45,
                    fit: BoxFit.contain,
                  )
                : Text(
                    card.brand.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
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
                      card.cardNumber,
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
                          card.holderName,
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
                          card.getFormattedExpiry(),
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
          Positioned(
            bottom: 8,
            right: 8,
            child: widget.selectionMode == CardsSelectionMode.view
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          card.isFavorite == 1 
                              ? Icons.star 
                              : Icons.star_border,
                          color: card.isFavorite == 1 
                              ? Colors.amber 
                              : textColor.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        onPressed: () => _toggleFavorite(card.id, card),
                        tooltip: card.isFavorite == 1 
                            ? 'Principal' 
                            : 'Establecer como principal',
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _deleteCard(card.id, card),
                        tooltip: 'Eliminar',
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: widget.onSelect != null 
                        ? () => widget.onSelect!(card) 
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        widget.selectedCard?.id == card.id
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: widget.selectedCard?.id == card.id
                            ? Colors.green
                            : textColor.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode == CardsSelectionMode.select 
            ? 'Seleccionar Tarjeta' 
            : 'Tarjetas'),
        elevation: 4,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCards,
        color: theme.colorScheme.primary,
        child: Column(
          children: [
            const ClientNumberHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _cards.isEmpty
                      ? Center(
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
                                  'No hay tarjetas registradas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Agrega una tarjeta para realizar pagos más rápido',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 1;
                            double childAspectRatio = 1.8;
                            
                            if (constraints.maxWidth >= 600) {
                              crossAxisCount = 2;
                              childAspectRatio = 1.7;
                            }
                            if (constraints.maxWidth >= 900) {
                              crossAxisCount = 3;
                              childAspectRatio = 1.5;
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _cards.length,
                              itemBuilder: (context, index) {
                                final card = _cards[index];
                                return _buildCardWidget(card);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _addCard,
          icon: const Icon(Icons.add),
          label: Text(
            widget.selectionMode == CardsSelectionMode.select 
                ? 'Agregar Nueva Tarjeta' 
                : 'Agregar Tarjeta',
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}
