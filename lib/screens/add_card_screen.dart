import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:provider/provider.dart';

class AddCardScreen extends StatefulWidget {
  static const routeName = '/add-card';

  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _cvvController = TextEditingController();

  String? _selectedMonth;
  String? _selectedYear;
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _isCvvVisible = false;

  final List<String> _months = List.generate(12, (index) => (index + 1).toString().padLeft(2, '0'));
  final List<String> _years = List.generate(11, (index) => (DateTime.now().year + index).toString());

  @override
  void dispose() {
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el número de tarjeta';
    }
    final cleanValue = value.replaceAll(' ', '');
    if (cleanValue.length != 16 || !RegExp(r'^\d+$').hasMatch(cleanValue)) {
      return 'Número de tarjeta inválido';
    }
    return null;
  }

  String? _validateHolderName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el nombre del titular';
    }
    return null;
  }

  String? _validateMonth(String? value) {
    if (value == null || value.isEmpty) {
      return 'Seleccione el mes';
    }
    return null;
  }

  String? _validateYear(String? value) {
    if (value == null || value.isEmpty) {
      return 'Seleccione el año';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el CVV';
    }
    if (value.length != 3 || !RegExp(r'^\d+$').hasMatch(value)) {
      return 'CVV inválido';
    }
    return null;
  }

  Future<void> _saveCard() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authService = context.read<AuthService>();
      final apiService = ApiService();
      final token = await authService.getToken();
      final headers = {'Authorization': 'Bearer $token'};

      final body = {
        'holder_name': _holderNameController.text.trim(),
        'card_number': _cardNumberController.text.replaceAll(' ', ''),
        'cvv2': _cvvController.text,
        'expiration_month': _selectedMonth!,
        'expiration_year': _selectedYear!.substring(2),
        'is_favorite': _isFavorite ? 1 : 0,
      };

      try {
        await apiService.post('/client/cards', headers: headers, body: body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarjeta agregada exitosamente')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        String errorMsg = 'Error al agregar tarjeta';
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
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Tarjeta'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Información de la Tarjeta',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _cardNumberController,
                decoration: InputDecoration(
                  labelText: 'Número de Tarjeta',
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: const Icon(Icons.credit_card),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Número de Tarjeta'),
                        content: const Text('Los 16 dígitos ubicados en la parte frontal de tu tarjeta de crédito o débito.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                validator: _validateCardNumber,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _holderNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Titular',
                  hintText: 'Como aparece en la tarjeta',
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Nombre del Titular'),
                        content: const Text('El nombre impreso en la parte frontal de la tarjeta, exactamente como aparece.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _validateHolderName,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedMonth,
                      decoration: InputDecoration(
                        labelText: 'Mes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      items: _months.map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(month),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMonth = value;
                        });
                      },
                      validator: _validateMonth,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      items: _years.map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text(year.substring(2)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear = value;
                        });
                      },
                      validator: _validateYear,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _cvvController,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_isCvvVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isCvvVisible = !_isCvvVisible),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('CVV'),
                            content: const Text('Los 3 dígitos de seguridad ubicados en la parte trasera de tu tarjeta.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                obscureText: !_isCvvVisible,
                validator: _validateCvv,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Switch(
                    value: _isFavorite,
                    onChanged: (value) {
                      setState(() {
                        _isFavorite = value;
                      });
                    },
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Establecer como tarjeta principal'),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Esta tarjeta se usará por defecto en tus pagos',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveCard,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Agregar Tarjeta', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}