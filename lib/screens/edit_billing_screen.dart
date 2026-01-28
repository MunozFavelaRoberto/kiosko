import 'package:flutter/material.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/api_service.dart';

class EditBillingScreen extends StatefulWidget {
  static const routeName = '/edit-billing';

  const EditBillingScreen({super.key});

  @override
  State<EditBillingScreen> createState() => _EditBillingScreenState();
}

class _EditBillingScreenState extends State<EditBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rfcController = TextEditingController(text: 'XAXX010101000');
  final _razonSocialController = TextEditingController(text: 'CLIENTE DE PRUEBA S.A. DE C.V.');
  final _codigoPostalController = TextEditingController(text: '12345');
  String? _selectedRegimen;
  String? _selectedUsoCFDI;

  late final AuthService _authService;
  late final ApiService _apiService;
  List<Map<String, dynamic>> _regimenes = [];
  List<Map<String, dynamic>> _usosCFDI = [];
  bool _loadingCatalogs = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _apiService = ApiService();
    _loadCatalogs();
  }

  @override
  void dispose() {
    _rfcController.dispose();
    _razonSocialController.dispose();
    _codigoPostalController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    setState(() => _loadingCatalogs = true);

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final regimenResponse = await _apiService.get('/client/catalogs/fiscal_regimes', headers: {'Authorization': 'Bearer $token'});
        if (regimenResponse != null && regimenResponse['data'] != null) {
          _regimenes = List<Map<String, dynamic>>.from(regimenResponse['data']['items']);
        }

        final usoResponse = await _apiService.get('/client/catalogs/cfdi_usage', headers: {'Authorization': 'Bearer $token'});
        if (usoResponse != null && usoResponse['data'] != null) {
          _usosCFDI = List<Map<String, dynamic>>.from(usoResponse['data']['items']);
        }
      }
    } catch (e) {
      debugPrint('Error loading catalogs: $e');
    }

    if (mounted) {
      setState(() {
        _loadingCatalogs = false;
        if (_regimenes.isNotEmpty) {
          final name = _regimenes[0]['name'].length > 40 ? _regimenes[0]['name'].substring(0, 40) + '...' : _regimenes[0]['name'];
          _selectedRegimen = '${_regimenes[0]['code']} - $name';
        }
        if (_usosCFDI.isNotEmpty) {
          final name = _usosCFDI[0]['name'].length > 40 ? _usosCFDI[0]['name'].substring(0, 40) + '...' : _usosCFDI[0]['name'];
          _selectedUsoCFDI = '${_usosCFDI[0]['code']} - $name';
        }
      });
    }
  }

  String? _validateRFC(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el RFC';
    }
    if (value.length < 12 || value.length > 13) {
      return 'RFC inválido';
    }
    return null;
  }

  String? _validateRazonSocial(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese la Razón Social';
    }
    return null;
  }

  String? _validateCodigoPostal(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingrese el Código Postal';
    }
    if (value.length != 5 || !RegExp(r'^\d+$').hasMatch(value)) {
      return 'Código Postal inválido';
    }
    return null;
  }

  void _saveBillingInfo() {
    if (_formKey.currentState!.validate()) {
      // Aquí iría la lógica para guardar la información
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información fiscal actualizada')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Datos Fiscales'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Información Fiscal',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rfcController,
                decoration: InputDecoration(
                  labelText: 'RFC',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                validator: _validateRFC,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _razonSocialController,
                decoration: InputDecoration(
                  labelText: 'Razón Social',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                validator: _validateRazonSocial,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigoPostalController,
                decoration: InputDecoration(
                  labelText: 'Código Postal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                keyboardType: TextInputType.number,
                validator: _validateCodigoPostal,
              ),
              const SizedBox(height: 16),
              if (_loadingCatalogs)
                const Center(child: CircularProgressIndicator())
              else
                FormField<String>(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Seleccione un Régimen Fiscal';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return DropdownMenu<String>(
                      label: const Text('Régimen Fiscal'),
                      initialSelection: _selectedRegimen,
                      dropdownMenuEntries: _regimenes.map((reg) {
                        final name = reg['name'].length > 30 ? reg['name'].substring(0, 30) + '...' : reg['name'];
                        final value = '${reg['code']} - $name';
                        return DropdownMenuEntry(value: value, label: value);
                      }).toList(),
                      onSelected: (value) {
                        state.didChange(value);
                        setState(() {
                          _selectedRegimen = value;
                        });
                      },
                      width: MediaQuery.of(context).size.width - 32,
                      menuHeight: 200.0,
                      errorText: state.errorText,
                    );
                  },
                ),
              const SizedBox(height: 16),
              if (_loadingCatalogs)
                const Center(child: CircularProgressIndicator())
              else
                FormField<String>(
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Seleccione un Uso de CFDI';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return DropdownMenu<String>(
                      label: const Text('Uso de CFDI'),
                      initialSelection: _selectedUsoCFDI,
                      dropdownMenuEntries: _usosCFDI.map((uso) {
                        final name = uso['name'].length > 30 ? uso['name'].substring(0, 30) + '...' : uso['name'];
                        final value = '${uso['code']} - $name';
                        return DropdownMenuEntry(value: value, label: value);
                      }).toList(),
                      onSelected: (value) {
                        state.didChange(value);
                        setState(() {
                          _selectedUsoCFDI = value;
                        });
                      },
                      width: MediaQuery.of(context).size.width - 32,
                      menuHeight: 200.0,
                      errorText: state.errorText,
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _saveBillingInfo,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}