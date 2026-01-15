import 'package:flutter/material.dart';
import 'package:kiosko/models/category.dart';
import 'package:kiosko/models/service.dart';
import 'package:kiosko/models/payment.dart';
import 'package:kiosko/models/user.dart';
import 'package:kiosko/services/api_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

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
      final data = await _apiService.get('/user');
      _user = User.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching user: $e');
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