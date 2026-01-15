import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final http.Client _client;

  // Cambia esta URL por la de tu API
  static const String baseUrlApi = 'https://api.example.com'; // Reemplaza con tu enlace

  ApiService({this.baseUrl = baseUrlApi, http.Client? client})
      : _client = client ?? http.Client();

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
      final response = await _client.post(
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
    } else {
      throw Exception('Error HTTP $statusCode: $body');
    }
  }

  // Cerrar cliente
  void dispose() {
    _client.close();
  }
}