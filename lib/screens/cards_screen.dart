import 'package:flutter/material.dart';
import 'package:kiosko/widgets/client_number_header.dart';

class CardsScreen extends StatefulWidget {
  static const routeName = '/cards';

  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  // Datos hardcodeados de tarjetas
  final List<Map<String, dynamic>> _cards = [
    {
      'bank': 'Banco Nacional',
      'number': '**** **** **** 1234',
      'holder': 'Juan Pérez García',
      'expiry': '12/25',
      'isPreferred': true,
    },
    {
      'bank': 'Banco Internacional',
      'number': '**** **** **** 5678',
      'holder': 'Juan Pérez García',
      'expiry': '06/24',
      'isPreferred': false,
    },
  ];

  void _togglePreferred(int index) {
    setState(() {
      // Si se marca como preferida, se desmarcan las otras
      if (!_cards[index]['isPreferred']) {
        for (int i = 0; i < _cards.length; i++) {
          _cards[i]['isPreferred'] = false;
        }
      }
      _cards[index]['isPreferred'] = !_cards[index]['isPreferred'];
    });
  }

  void _deleteCard(int index) async {
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

    if (confirmed == true) {
      setState(() {
        _cards.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarjeta eliminada')),
        );
      }
    }
  }

  void _addCard() {
    // Simulación de agregar tarjeta
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad para agregar tarjeta próximamente')),
    );
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
            child: _cards.isEmpty
                ? const Center(child: Text('No hay tarjetas registradas'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    card['bank'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteCard(index),
                                    tooltip: 'Eliminar tarjeta',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card['number'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('${card['holder']}'),
                              const SizedBox(height: 8),
                              Text('${card['expiry']}'),
                              const SizedBox(height: 12),
                              IconButton(
                                icon: Icon(
                                  card['isPreferred'] ? Icons.star : Icons.star_border,
                                  color: card['isPreferred'] ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () => _togglePreferred(index),
                                tooltip: 'Marcar como preferida',
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
