import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/widgets/client_number_header.dart';
import 'package:kiosko/screens/add_card_screen.dart';
import 'package:kiosko/models/card.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/utils/error_helper.dart';

enum CardsSelectionMode {
  view,
  select,
}

class CardsScreen extends StatefulWidget {
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
  // Variables para tracking de operaciones por tarjeta
  int? _favoriteLoadingCardId;
  int? _deleteLoadingCardId;
  // Variable para deshabilitar toda la vista cuando hay operación en proceso
  bool get _isProcessingCard => _favoriteLoadingCardId != null || _deleteLoadingCardId != null;
  late AuthService _authService;
  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = context.read<AuthService>();
    // Solo cargar tarjetas si hay un usuario autenticado
    final dataProvider = context.read<DataProvider>();
    if (dataProvider.user != null) {
      _loadCards();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
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
      // Delay obligatorio de 1 segundo para mostrar indicador de carga
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCards() async {
    await _loadCards();
  }

  Future<void> _toggleFavorite(int cardId, CardModel card) async {
    // Evitar múltiples llamadas simultáneas para la misma tarjeta
    if (_favoriteLoadingCardId != null) return;
    
    setState(() {
      _favoriteLoadingCardId = cardId;
    });
    
    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};
    final body = {'user_card_id': cardId};

    try {
      await _apiService.post('/client/cards/favorite', headers: headers, body: body);
      
      // Delay obligatorio de 1 segundo para mostrar al usuario que su petición está siendo procesada
      await Future.delayed(const Duration(seconds: 1));
      
      await _loadCards();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarjeta establecida como principal'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al establecer favorita'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoadingCardId = null;
        });
      }
    }
  }

  Future<void> _deleteCard(int cardId, CardModel card) async {
    // Evitar múltiples llamadas simultáneas
    if (_deleteLoadingCardId != null) return;
    
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

    setState(() {
      _deleteLoadingCardId = cardId;
    });

    final token = await _authService.getToken();
    final headers = {'Authorization': 'Bearer $token'};

    try {
      await _apiService.delete('/client/cards/$cardId', headers: headers);
      
      // Delay obligatorio de 1 segundo para mostrar al usuario que su petición está siendo procesada
      await Future.delayed(const Duration(seconds: 1));
      
      await _loadCards();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarjeta eliminada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al eliminar tarjeta'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deleteLoadingCardId = null;
        });
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
            child: CardModel.buildBrandLogo(
              brand: card.brand,
              height: CardModel.logoHeightMedium,
              width: CardModel.logoWidthMedium,
              textColor: textColor,
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
                      // Indicador de carga para favorito
                      if (_favoriteLoadingCardId == card.id)
                        Container(
                          width: 18,
                          height: 18,
                          padding: const EdgeInsets.all(2),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        )
                      else
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
                          onPressed: _favoriteLoadingCardId != null ? null : () => _toggleFavorite(card.id, card),
                          tooltip: card.isFavorite == 1 
                              ? 'Principal' 
                              : 'Establecer como principal',
                          color: Colors.white,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      // Indicador de carga para eliminación
                      if (_deleteLoadingCardId == card.id)
                        Container(
                          width: 18,
                          height: 18,
                          padding: const EdgeInsets.all(2),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: _deleteLoadingCardId != null ? null : () => _deleteCard(card.id, card),
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
    final isBlocked = _isProcessingCard;

    return PopScope(
      canPop: !isBlocked,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isBlocked
                  ? Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)
                  : null,
            ),
            onPressed: isBlocked ? null : () => Navigator.pop(context),
          ),
          title: Text(widget.selectionMode == CardsSelectionMode.select 
              ? 'Seleccionar Tarjeta' 
              : 'Tarjetas'),
          elevation: 4,
        ),
      body: RefreshIndicator(
        onRefresh: _refreshCards,
        color: Colors.green,
        child: Column(
          children: [
            const ClientNumberHeader(),
            Expanded(
              child: Consumer<DataProvider>(
                builder: (context, dataProvider, child) {
                  // Usuario null después de carga completa - mostrar "No autorizado"
                  if (!dataProvider.isLoading && dataProvider.user == null) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
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
                          ),
                        ),
                      ],
                    );
                  }

                  // Mostrar indicador de carga
                  if (_isLoading) {
                    return const SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.green),
                            SizedBox(height: 16),
                            Text('Cargando tarjetas...'),
                          ],
                        ),
                      ),
                    );
                  }

                  // Sin tarjetas
                  if (_cards.isEmpty) {
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
                    );
                  }

                  // Grid de tarjetas
                  return LayoutBuilder(
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

                      return Column(
                        children: [
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: _isProcessingCard,
                              child: Opacity(
                                opacity: _isProcessingCard ? 0.5 : 1.0,
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
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
                                ),
                              ),
                            ),
                          ),
                          // Botón de agregar tarjeta - solo visible cuando termina de cargar
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton.icon(
                              onPressed: (_isProcessingCard || dataProvider.user == null) ? null : _addCard,
                              icon: const Icon(Icons.add),
                              label: Text(
                                widget.selectionMode == CardsSelectionMode.select 
                                    ? 'Agregar Nueva Tarjeta' 
                                    : 'Agregar Tarjeta',
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ), // CIERRE DEL POPSCOPE
  );
}
}
