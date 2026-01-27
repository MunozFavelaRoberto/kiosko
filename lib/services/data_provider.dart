import 'package:flutter/material.dart';
import 'package:kiosko/models/category.dart';
import 'package:kiosko/models/service.dart';
import 'package:kiosko/models/payment.dart';
import 'package:kiosko/models/user.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService? _authService;

  DataProvider({AuthService? authService}) : _authService = authService;

  List<Category> _categories = [];
  List<Service> _services = [];
  List<Payment> _payments = [];
  User? _user;
  bool _isLoading = false;

  List<Category> get categories => _categories;
  List<Service> get services => _services;
  List<Payment> get payments => _payments;
  User? get user => _user;
  bool get isLoading => _isLoading;

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

  Future<void> fetchUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Llamar a la API para obtener datos actualizados del usuario
      final token = await _authService?.getToken();
      if (token != null) {
        final data = await _apiService.get('/user', headers: {
          'Authorization': 'Bearer $token',
        });
        _user = User.fromJson(data);
        debugPrint('Usuario obtenido de API: ${_user!.fullName} - ${_user!.email}');
      } else {
        throw Exception('No hay token disponible');
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      // Si falla, intentar usar datos del login si están disponibles
      final currentUser = _authService?.currentUser;
      if (currentUser != null) {
        _user = User(
          clientNumber: currentUser.uiid,
          status: 'Activo',
          balance: 0.0,
          fullName: currentUser.fullName,
          email: currentUser.email,
        );
        debugPrint('Usando datos del login como fallback: ${_user!.fullName}');
      } else {
        // Sin datos disponibles
        _user = null;
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
}