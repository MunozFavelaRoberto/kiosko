import 'package:flutter/material.dart';
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

  DataProvider({AuthService? authService, ApiService? apiService})
      : _authService = authService,
        _apiService = apiService ?? ApiService();

  List<Category> _categories = [];
  List<Service> _services = [];
  List<Payment> _payments = [];
  List<PaymentHistory> _paymentHistory = [];
  User? _user;
  double _outstandingAmount = 0.0;
  bool _isLoading = false;
  bool _isUnauthorized = false;

  List<Category> get categories => _categories;
  List<Service> get services => _services;
  List<Payment> get payments => _payments;
  List<PaymentHistory> get paymentHistory => _paymentHistory;
  User? get user => _user;
  double get outstandingAmount => _outstandingAmount;
  bool get isLoading => _isLoading;
  bool get isUnauthorized => _isUnauthorized;

  Future<void> fetchCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/categories');
      _categories = (data as List<dynamic>).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      // Puedes mostrar un snackbar o manejar el error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/services');
      _services = (data as List<dynamic>).map((json) => Service.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching services: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.get('/payments');
      _payments = (data as List<dynamic>).map((json) => Payment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOutstandingPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService?.getToken();
      if (token != null) {
        final data = await _apiService.get('/client/payments/outstanding', headers: {
          'Authorization': 'Bearer $token',
        });
        final paymentsData = data['data'];
        _outstandingAmount = (paymentsData['total'] as num?)?.toDouble() ?? 0.0;
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
    notifyListeners();

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
      notifyListeners();
    }
  }

  Future<void> fetchUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Llamar a la API para obtener datos del perfil del cliente
      final token = await _authService?.getToken();
      if (token != null) {
        final data = await _apiService.get('/client/profile', headers: {
          'Authorization': 'Bearer $token',
        });
        debugPrint('Profile data: $data');
        // Usar datos del login como base, pero clientNumber del perfil
        final currentUser = _authService?.currentUser;
        if (currentUser != null) {
          final profileData = data['data']['item'];
          _user = User(
            clientNumber: profileData['client_number'] as String? ?? 'N/A',
            status: 'Activo',
            balance: 0.0,
            fullName: currentUser.fullName,
            email: currentUser.email,
          );
          debugPrint('Usuario obtenido de perfil: ${_user!.fullName} - Cliente: ${_user!.clientNumber}');
        } else {
          throw Exception('No hay datos de usuario disponibles');
        }
      } else {
        throw Exception('No hay token disponible');
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      // Verificar si es error de autorización (401)
      if (e.toString().contains('No autorizado')) {
        _isUnauthorized = true;
      } else {
        _isUnauthorized = false;
      }
      // Sin datos disponibles
      _user = null;
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
}