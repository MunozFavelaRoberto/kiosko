import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:kiosko/models/card.dart';
import 'package:kiosko/models/payment_detail.dart' as payment_detail;
import 'package:kiosko/models/payment_history.dart' as payment_history;
import 'package:kiosko/models/payment_response.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = _createHttpClient();

  // URL de la API real
  static const String baseUrlApi = 'https://apipagoselectronicos.svr.com.mx/api';
  String get baseUrl => baseUrlApi;

  static http.Client _createHttpClient() {
    return http.Client();
  }

  // Método GET
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Exception('No hay conexión a internet');
    } on http.ClientException {
      throw Exception('Error de conexión');
    } catch (e) {
      throw Exception('Error desconocido: $e');
    }
  }

  // Método POST
  Future<dynamic> post(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final defaultHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };
      final response = await _client.post(
        uri,
        headers: defaultHeaders,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Exception('No hay conexión a internet');
    } on http.ClientException {
      throw Exception('Error de conexión');
    } catch (e) {
      throw Exception('Error desconocido: $e');
    }
  }

  // Método PUT
  Future<dynamic> put(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Exception('No hay conexión a internet');
    } on http.ClientException {
      throw Exception('Error de conexión');
    } catch (e) {
      throw Exception('Error desconocido: $e');
    }
  }

  // Método DELETE
  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on SocketException {
      throw Exception('No hay conexión a internet');
    } on http.ClientException {
      throw Exception('Error de conexión');
    } catch (e) {
      throw Exception('Error desconocido: $e');
    }
  }

  // Manejar respuesta HTTP
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      if (body.isNotEmpty) {
        try {
          return jsonDecode(body);
        } catch (e) {
          throw Exception('Error al parsear JSON: $e');
        }
      }
      return null;
    } else if (statusCode == 401) {
      throw Exception('No autorizado');
    } else {
      throw Exception('Error HTTP $statusCode: $body');
    }
  }

  // Obtener tarjetas del cliente
  Future<List<CardModel>> getCards({Map<String, String>? headers}) async {
    final response = await get('/client/cards', headers: headers);
    final data = response['data'];
    final items = data['items'] as List;
    return items.map((item) => CardModel.fromJson(item)).toList();
  }

  // Obtener detalles de pagos pendientes
  Future<List<payment_detail.PaymentDetail>> getOutstandingPayments({Map<String, String>? headers}) async {
    final response = await get('/client/payments/outstanding', headers: headers);
    final data = response['data'];
    final payments = data['payments'] as List;
    return payments.map((item) => payment_detail.PaymentDetail.fromJson(item)).toList();
  }

  // Obtener historial de pagos
  Future<List<payment_history.PaymentHistory>> getPaymentHistory({Map<String, String>? headers}) async {
    final response = await get('/client/payments/history', headers: headers);
    final data = response['data'];
    final items = data['items'] as List;
    return items.map((item) => payment_history.PaymentHistory.fromJson(item)).toList();
  }

  // Descargar factura en PDF o XML
  Future<String> downloadInvoice({required String headers, required int paymentId, required String fileExtension}) async {
    final response = await post(
      '/client/payments/invoice/file',
      headers: {'Authorization': headers},
      body: {
        'id': paymentId,
        'file_extention': fileExtension,
      },
    );
    final data = response['data'];
    return data['file'] as String;
  }

  // Descargar ticket de pago
  Future<String> downloadTicket({required String headers, required int paymentId}) async {
    final response = await post(
      '/client/payments/ticket',
      headers: {'Authorization': headers},
      body: {
        'id': paymentId,
      },
    );
    final data = response['data'];
    return data['file'] as String;
  }

  // Procesar pago
  Future<PaymentResponse> processPayment({
    required String headers,
    required List<Map<String, int>> payments,
    required double total,
    required String tokenId,
    required String deviceSessionId,
    required bool isInvoiceRequired,
  }) async {
    final response = await post(
      '/client/payments/pay',
      headers: {'Authorization': headers},
      body: {
        'payments': payments,
        'total': total,
        'token_id': tokenId,
        'device_session_id': deviceSessionId,
        'use_card_points': null,
        'is_invoice_required': isInvoiceRequired,
      },
    );
    return PaymentResponse.fromJson(response['data']);
  }

  // Cerrar cliente (llamar al salir de la app)
  void dispose() {
    _client.close();
  }
}
