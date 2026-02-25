import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosko/models/card.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/utils/error_helper.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AddCardScreen extends StatefulWidget {
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
  bool _showSuccess = false;
  bool _isCvvVisible = false;
  String _detectedBrand = '';
  String _cardNumberHint = '1234 5678 9012 3456';
  bool _initialLoading = true;

  late List<String> _months;
  late List<String> _years;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeDates();
    
    _cardNumberController.addListener(_detectCardBrand);
    
    // Delay obligatorio de 1 segundo para mostrar indicador de carga inicial
    _initialLoadDelay();
  }

  Future<void> _initialLoadDelay() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _initialLoading = false;
      });
    }
  }

  void _initializeDates() {
    final now = DateTime.now();
    final currentYear = now.year;

    _months = List.generate(12, (index) => (index + 1).toString().padLeft(2, '0'));
    
    _years = List.generate(11, (index) => (currentYear + index).toString());
    
    _selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedYear = currentYear.toString();
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_detectCardBrand);
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _detectCardBrand() {
    final text = _cardNumberController.text.replaceAll(' ', '');
    if (text.length >= 2) {
      final brand = CardModel.detectBrand(text);
      if (brand != _detectedBrand) {
        setState(() {
          _detectedBrand = brand;
          
          if (brand == 'amex') {
            _cardNumberHint = '3456 789012 34567';
          } else {
            _cardNumberHint = '1234 5678 9012 3456';
          }
          
          final cvvLength = CardModel.getCvvLength(brand);
          if (_cvvController.text.length != cvvLength) {
            _cvvController.clear();
          }
        });
      }
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el número de tarjeta';
    }
    
    final cleanValue = value.replaceAll(' ', '');
    final brand = CardModel.detectBrand(cleanValue);
    final expectedLength = CardModel.getCardNumberLength(brand);
    
    if (cleanValue.length != expectedLength) {
      return 'Número de tarjeta inválido para $brand';
    }
    
    if (!CardModel.validateLuhn(cleanValue)) {
      return 'Número de tarjeta inválido';
    }
    
    return null;
  }

  String? _validateHolderName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el nombre del titular';
    }
    if (value.length > 50) {
      return 'Máximo 50 caracteres';
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
    
    final now = DateTime.now();
    final currentYear = now.year;
    final selectedYear = int.tryParse(value) ?? 0;
    final selectedMonth = int.tryParse(_selectedMonth ?? '0') ?? 0;
    
    if (selectedYear < currentYear) {
      return 'La tarjeta está vencida';
    }
    if (selectedYear == currentYear && selectedMonth < now.month) {
      return 'La tarjeta está vencida';
    }
    
    return null;
  }

  String? _validateCvv(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el CVV';
    }
    
    final brand = _detectedBrand.isNotEmpty ? _detectedBrand : CardModel.detectBrand(_cardNumberController.text);
    final expectedLength = CardModel.getCvvLength(brand);
    
    if (value.length != expectedLength) {
      return 'CVV debe tener $expectedLength dígitos';
    }
    
    if (!RegExp(r'^\d+$').hasMatch(value)) {
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
      final token = await authService.getToken();
      final headers = {'Authorization': 'Bearer $token'};

      final body = {
        'holder_name': _holderNameController.text.trim().toUpperCase(),
        'card_number': _cardNumberController.text.replaceAll(' ', ''),
        'cvv2': _cvvController.text,
        'expiration_month': _selectedMonth!,
        'expiration_year': _selectedYear!.substring(2),
        'is_favorite': _isFavorite ? 1 : 0,
      };

      try {
        await _apiService.post('/client/cards', headers: headers, body: body);
        if (mounted) {
          setState(() {
            _showSuccess = true;
          });
          
          await Future.delayed(const Duration(milliseconds: 1500));
          
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHelper.parseError(e.toString(), defaultMsg: 'Error al agregar tarjeta'))),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showSuccess = false;
          });
        }
      }
    }
  }

  Widget _buildCardPrefixIcon() {
    final logoPath = CardModel.getBrandLogo(_detectedBrand);
    
    if (logoPath.isEmpty) {
      return const Icon(Icons.credit_card);
    }
    
    if (logoPath.endsWith('.png')) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          logoPath,
          height: 24,
          width: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.credit_card);
          },
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(
          logoPath,
          height: 24,
          width: 36,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => const Icon(Icons.credit_card),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBlocked = _isLoading || _showSuccess;

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
          title: const Text('Agregar Tarjeta'),
          elevation: 0,
        ),
      body: Consumer<DataProvider>(
        builder: (context, dataProvider, child) {
          if (dataProvider.user == null) {
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _initialLoading
                ? const SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 16),
                          Text('Cargando formulario de tarjeta...'),
                        ],
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AbsorbPointer(
                          absorbing: isBlocked,
                          child: Opacity(
                            opacity: isBlocked ? 0.5 : 1.0,
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
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _cardNumberController,
                                  decoration: InputDecoration(
                                    labelText: 'Número de Tarjeta',
                                    hintText: _cardNumberHint,
                                    prefixIcon: const Icon(Icons.credit_card),
                                    suffixIcon: _buildCardPrefixIcon(),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
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
                                          final monthAbbrev = [
                                            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                                            'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
                                          ];
                                          final monthIndex = int.parse(month) - 1;
                                          return DropdownMenuItem(
                                            value: month,
                                            child: Text('$month - ${monthAbbrev[monthIndex]}'),
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
                                            child: Text(year),
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
                                    hintText: _detectedBrand == 'amex' ? '1234' : '123',
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isCvvVisible ? Icons.visibility_off : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isCvvVisible = !_isCvvVisible;
                                        });
                                      },
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
                                    LengthLimitingTextInputFormatter(_detectedBrand == 'amex' ? 4 : 3),
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
                                      activeThumbColor: Colors.green,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_isLoading || _showSuccess)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _showSuccess 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showSuccess ? Colors.green : Colors.blue,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_showSuccess)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                else
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.green,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                Text(
                                  _showSuccess 
                                      ? '¡Tarjeta agregada exitosamente!' 
                                      : 'Procesando...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _showSuccess ? Colors.green : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: double.infinity),
                            child: ElevatedButton.icon(
                              onPressed: _saveCard,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar Tarjeta'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          );
        },
      ),
    ), // CIERRE DEL POPSCOPE
  );
}
} // CIERRE DE _AddCardScreenState

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    
    final brand = CardModel.detectBrand(text);
    final isAmex = brand == 'amex';
    
    final maxDigits = isAmex ? 15 : 16;
    final limitedText = text.length > maxDigits ? text.substring(0, maxDigits) : text;
    
    final buffer = StringBuffer();
    for (int i = 0; i < limitedText.length; i++) {
      if (isAmex) {
        if (i == 4 || i == 10) {
          buffer.write(' ');
        }
      } else {
        if (i > 0 && i % 4 == 0) {
          buffer.write(' ');
        }
      }
      buffer.write(limitedText[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
