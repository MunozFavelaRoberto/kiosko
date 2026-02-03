import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/utils/error_helper.dart';

class EditBillingScreen extends StatefulWidget {
  static const routeName = '/edit-billing';

  const EditBillingScreen({super.key});

  @override
  State<EditBillingScreen> createState() => _EditBillingScreenState();
}

class _EditBillingScreenState extends State<EditBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rfcController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  String? _selectedRegimen;
  String? _selectedUsoCFDI;

  final ApiService _apiService = ApiService(); // Singleton
  late final AuthService _authService;
  List<Map<String, dynamic>> _regimenes = [];
  List<Map<String, dynamic>> _usosCFDI = [];
  Map<String, dynamic>? _currentFiscalData;
  bool _loadingCatalogs = true;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
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

        final fiscalResponse = await _apiService.get('/client/fiscal_data', headers: {'Authorization': 'Bearer $token'});
        if (fiscalResponse != null && fiscalResponse['data'] != null) {
          _currentFiscalData = fiscalResponse['data']['item'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      // Prefill with current data
      if (_currentFiscalData != null) {
        _rfcController.text = _currentFiscalData!['code'] ?? '';
        _razonSocialController.text = _currentFiscalData!['name'] ?? '';
        _codigoPostalController.text = _currentFiscalData!['zip'] ?? '';
      }

      setState(() {
        _loadingCatalogs = false;
        // Set selected values
        if (_currentFiscalData != null && _regimenes.isNotEmpty) {
          final regimen = _regimenes.firstWhere(
            (reg) => reg['id'] == _currentFiscalData!['fiscal_regime_id'],
            orElse: () => _regimenes[0],
          );
          final name = regimen['name'].length > 30 ? regimen['name'].substring(0, 30) + '...' : regimen['name'];
          _selectedRegimen = '${regimen['code']} - $name';
        } else if (_regimenes.isNotEmpty) {
          final name = _regimenes[0]['name'].length > 30 ? _regimenes[0]['name'].substring(0, 30) + '...' : _regimenes[0]['name'];
          _selectedRegimen = '${_regimenes[0]['code']} - $name';
        }

        if (_currentFiscalData != null && _usosCFDI.isNotEmpty) {
          final uso = _usosCFDI.firstWhere(
            (u) => u['id'] == _currentFiscalData!['cfdi_usage_id'],
            orElse: () => _usosCFDI[0],
          );
          final name = uso['name'].length > 30 ? uso['name'].substring(0, 30) + '...' : uso['name'];
          _selectedUsoCFDI = '${uso['code']} - $name';
        } else if (_usosCFDI.isNotEmpty) {
          final name = _usosCFDI[0]['name'].length > 30 ? _usosCFDI[0]['name'].substring(0, 30) + '...' : _usosCFDI[0]['name'];
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


  void _saveBillingInfo() async {
    if (_formKey.currentState!.validate()) {
      final token = await _authService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No hay token de autenticación')),
          );
        }
        return;
      }

      // Find ids from selected values
      int? fiscalRegimeId;
      int? cfdiUsageId;

      if (_selectedRegimen != null && _regimenes.isNotEmpty) {
        final selectedParts = _selectedRegimen!.split(' - ');
        if (selectedParts.length >= 2) {
          final code = selectedParts[0];
          final regimen = _regimenes.firstWhere(
            (reg) => reg['code'] == code,
            orElse: () => {},
          );
          fiscalRegimeId = regimen['id'];
        }
      }

      if (_selectedUsoCFDI != null && _usosCFDI.isNotEmpty) {
        final selectedParts = _selectedUsoCFDI!.split(' - ');
        if (selectedParts.length >= 2) {
          final code = selectedParts[0];
          final uso = _usosCFDI.firstWhere(
            (u) => u['code'] == code,
            orElse: () => {},
          );
          cfdiUsageId = uso['id'];
        }
      }

      if (fiscalRegimeId == null || cfdiUsageId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No se pudieron determinar los IDs')),
          );
        }
        return;
      }

      try {
        final response = await _apiService.post('/client/fiscal_data', headers: {
          'Authorization': 'Bearer $token',
        }, body: {
          'code': _rfcController.text.trim(),
          'name': _razonSocialController.text.trim(),
          'zip': _codigoPostalController.text.trim(),
          'fiscal_regime_id': fiscalRegimeId,
          'cfdi_usage_id': cfdiUsageId,
        });

        if (response != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['msg'] ?? 'Operación completada')),
            );
            if (response['msg'] == 'Registro editado correctamente') {
              Navigator.pop(context);
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al actualizar la información fiscal')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHelper.parseError(e.toString()))),
          );
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
        title: const Text('Editar datos fiscales'),
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
                'Información fiscal',
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
                  initialValue: _selectedRegimen,
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
                  initialValue: _selectedUsoCFDI,
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