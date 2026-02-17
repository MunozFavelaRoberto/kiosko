import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosko/models/category.dart';
import 'package:kiosko/models/service.dart';
import 'package:kiosko/models/payment.dart';
import 'package:kiosko/models/payment_history.dart';
import 'package:kiosko/models/payment_response.dart';
import 'package:kiosko/models/user.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AuthService? _authService;

  // Clave para SharedPreferences
  static const String _userDataKey = 'cached_user_data';

  DataProvider({AuthService? authService, ApiService? apiService})
      : _authService = authService,
        _apiService = apiService ?? ApiService() {
    // Cargar datos de usuario desde cache al iniciar
    _loadCachedUser();
  }

  List<Category> _categories = [];
  List<Service> _services = [];
  List<Payment> _payments = [];
  List<PaymentHistory> _paymentHistory = [];
  User? _user;
  double _outstandingAmount = 0.0;
  bool _isLoading = false;
  bool _isUnauthorized = false;
  bool _isInitialLoading = true;
  bool _hasAttemptedFetch = false; // Track si ya intentamos obtener datos

  List<Category> get categories => _categories;
  List<Service> get services => _services;
  List<Payment> get payments => _payments;
  List<PaymentHistory> get paymentHistory => _paymentHistory;
  User? get user => _user;
  double get outstandingAmount => _outstandingAmount;
  bool get isLoading => _isLoading;
  bool get isUnauthorized => _isUnauthorized;
  bool get isInitialLoading => _isInitialLoading;
  bool get hasAttemptedFetch => _hasAttemptedFetch;

  // Cargar usuario desde cache local
  Future<void> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userDataKey);
      if (userJson != null) {
        final Map<String, dynamic> userMap = json.decode(userJson) as Map<String, dynamic>;
        _user = User.fromJson(userMap);
        _isInitialLoading = false;
        debugPrint('Usuario cargado desde cache: ${_user?.fullName}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando usuario desde cache: $e');
    }
  }

  // Guardar usuario en cache local
  Future<void> _cacheUser() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = _user!.toJson();
      await prefs.setString(_userDataKey, json.encode(userJson));
      debugPrint('Usuario guardado en cache');
    } catch (e) {
      debugPrint('Error guardando usuario en cache: $e');
    }
  }

  // Limpiar cache de usuario (logout)
  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      debugPrint('Cache de usuario limpiada');
    } catch (e) {
      debugPrint('Error limpiando cache: $e');
    }
  }

  Future<void> fetchCategories() async {
    _isLoading = true;

    try {
      final data = await _apiService.get('/categories');
      _categories = (data as List<dynamic>).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchServices() async {
    _isLoading = true;

    try {
      final data = await _apiService.get('/services');
      _services = (data as List<dynamic>).map((json) => Service.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching services: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchPayments() async {
    _isLoading = true;

    try {
      final data = await _apiService.get('/payments');
      _payments = (data as List<dynamic>).map((json) => Payment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchOutstandingPayments() async {
    _isLoading = true;

    try {
      final token = await _authService?.getToken();
      if (token != null) {
        final data = await _apiService.get('/client/payments/outstanding', headers: {
          'Authorization': 'Bearer $token',
        });
        debugPrint('Outstanding payments API response: $data');
        // Verificar estructura de la respuesta
        if (data != null && data['data'] != null) {
          final paymentsData = data['data'];
          if (paymentsData['total'] != null) {
            _outstandingAmount = (paymentsData['total'] as num?)?.toDouble() ?? 0.0;
          } else {
            debugPrint('No se encontró campo total en respuesta: $paymentsData');
            _outstandingAmount = 0.0;
          }
        } else {
          debugPrint('Estructura de respuesta inesperada: $data');
          _outstandingAmount = 0.0;
        }
      } else {
        throw Exception('No hay token disponible');
      }
    } catch (e) {
      debugPrint('Error fetching outstanding payments: $e');
      _outstandingAmount = 0.0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPaymentHistory() async {
    _isLoading = true;

    try {
      final token = await _authService?.getToken();
      if (token != null) {
        _paymentHistory = await _apiService.getPaymentHistory(headers: {
          'Authorization': 'Bearer $token',
        });
      } else {
        throw Exception('No hay token disponible');
      }
    } catch (e) {
      debugPrint('Error fetching payment history: $e');
      _paymentHistory = [];
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchUser() async {
    _isLoading = true;
    _hasAttemptedFetch = true;
    // No llamar notifyListeners() aquí para evitar error de build durante la construcción del widget

    try {
      final token = await _authService?.getToken();
      if (token != null) {
        // Obtener datos del perfil desde la API
        final data = await _apiService.get('/client/profile', headers: {
          'Authorization': 'Bearer $token',
        });
        debugPrint('Profile API response: $data');
        
        // Verificar estructura de la respuesta
        if (data == null) {
          debugPrint('Profile API returned null');
          _isLoading = false;
          notifyListeners();
          return;
        }
        
        // Obtener los datos del perfil directamente de la respuesta API
        final profileData = data['data']?['item'];
        if (profileData == null) {
          debugPrint('Profile data structure unexpected: $data');
          _isLoading = false;
          notifyListeners();
          return;
        }
        
        // La estructura es: data['data']['item']['user'] con full_name y email
        final userData = profileData['user'];
        if (userData == null) {
          debugPrint('User data not found in profile: $data');
          _isLoading = false;
          notifyListeners();
          return;
        }
        
        _user = User(
          clientNumber: profileData['client_number'] as String? ?? 'N/A',
          status: 'Activo',
          balance: 0.0,
          fullName: userData['full_name'] as String? ?? 'Usuario',
          email: userData['email'] as String? ?? 'email@desconocido.com',
        );
        _isInitialLoading = false;
        // Éxito - usuario válido
        _isUnauthorized = false;
        debugPrint('Usuario obtenido de perfil: ${_user!.fullName} - Cliente: ${_user!.clientNumber}');
        
        // Guardar en cache para persistencia
        await _cacheUser();
      } else {
        _isInitialLoading = false;
        // Token null - no hay sesión
        _isUnauthorized = true;
        _user = null;
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _isInitialLoading = false;
      
      // Solo marcar como no autorizado si es error explícito de autenticación
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('no autorizado') || errorMsg.contains('401') || errorMsg.contains('unauthorized')) {
        _isUnauthorized = true;
        _user = null;
      } else {
        // Error de red u otro tipo - no marcar como no autorizado
        // Mantener el estado actual pero asegurar que se intentó
        _isUnauthorized = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPayment(int serviceId, double amount, String reference) async {
    try {
      final response = await _apiService.post('/payments', body: {
        'service_id': serviceId,
        'amount': amount,
        'reference': reference,
      });

      if (response != null) {
        // Recargar pagos después de crear
        await fetchPayments();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating payment: $e');
      return false;
    }
  }

  // Método para obtener servicios por categoría
  List<Service> getServicesByCategory(int categoryId) {
    return _services.where((service) => service.categoryId == categoryId).toList();
  }

  // Método para actualizar el usuario
  void updateUser(User newUser) {
    _user = newUser;
    notifyListeners();
  }

  // Resetear estado de autorización (para cuando usuario hace logout o inicia sesión)
  void resetUnauthorized() {
    _isUnauthorized = false;
    _user = null;
    _hasAttemptedFetch = false;
    _clearUserCache(); // Limpiar cache al hacer logout
    notifyListeners();
  }

  // Método para establecer usuario manualmente (después de login exitoso)
  void setUser(User user) {
    _user = user;
    _isUnauthorized = false;
    _isInitialLoading = false;
    notifyListeners();
  }

  // Descargar factura (PDF o XML)
  Future<String> downloadInvoice(int paymentId, String fileExtension) async {
    final token = await _authService?.getToken();
    if (token == null) throw Exception('No hay token disponible');
    
    return await _apiService.downloadInvoice(
      headers: 'Bearer $token',
      paymentId: paymentId,
      fileExtension: fileExtension,
    );
  }

  // Descargar ticket
  Future<String> downloadTicket(int paymentId) async {
    final token = await _authService?.getToken();
    if (token == null) throw Exception('No hay token disponible');
    
    return await _apiService.downloadTicket(
      headers: 'Bearer $token',
      paymentId: paymentId,
    );
  }

  // Procesar pago
  Future<PaymentResponse> processPayment({
    required List<Map<String, int>> payments,
    required double total,
    required String tokenId,
    required String deviceSessionId,
    required bool isInvoiceRequired,
  }) async {
    final token = await _authService?.getToken();
    if (token == null) throw Exception('No hay token disponible');

    return await _apiService.processPayment(
      headers: 'Bearer $token',
      payments: payments,
      total: total,
      tokenId: tokenId,
      deviceSessionId: deviceSessionId,
      isInvoiceRequired: isInvoiceRequired,
    );
  }

  // Refresh completo para pull-to-refresh (usa notifyListeners)
  Future<void> refreshAllData() async {
    _isInitialLoading = false;
    
    await Future.wait([
      fetchUser(),
      fetchOutstandingPayments(),
      fetchPaymentHistory(),
      fetchCategories(),
      fetchServices(),
    ]);
    
    // Solo hacer notifyListeners() después de que todo termine
    notifyListeners();
  }
}
