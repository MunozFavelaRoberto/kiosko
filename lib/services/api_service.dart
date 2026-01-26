import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  // URL de la API real
  static const String baseUrlApi = 'https://apipagoselectronicos.svr.com.mx/api';

  ApiService({this.baseUrl = baseUrlApi, http.Client? client})
      : _client = client ?? _createHttpClient();

  static http.Client _createHttpClient() {
    // Ignorar errores de certificado SSL
    // Esto permite probar con certificados autofirmados o inválidos:

    // ❌ para DESARROLLO:
    final ioClient = HttpClient();
    ioClient.badCertificateCallback = (cert, host, port) => true;
    return IOClient(ioClient);

    // ✅  Para PRODUCCION: descomentar esta línea y eliminar el código de arriba
    // return http.Client();
  }

  // Método GET
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    // Simulación para '/user' sin hacer petición real (fallback para desarrollo)
    if (endpoint == '/user') {
      await Future.delayed(const Duration(seconds: 1)); // Simular delay
      return {
        'clientNumber': '1234987',
        'status': 'Activo',
        'balance': 250.0,
        'fullName': 'CLIENTE DE PRUEBA',
        'email': 'cliente123@prueba.com',
      };
    }

    // Simulación para '/payments'
    if (endpoint == '/payments') {
      await Future.delayed(const Duration(seconds: 1));
      return [
        {
          'id': 1,
          'service_id': 1,
          'service_name': 'Luz',
          'amount': 200.0,
          'reference': 'REF001',
          'date': '2023-10-01T00:00:00Z',
          'status': 'Pagado',
          'folio': 'FOL001',
        },
        {
          'id': 2,
          'service_id': 2,
          'service_name': 'Agua',
          'amount': 150.0,
          'reference': 'REF002',
          'date': '2023-10-15T00:00:00Z',
          'status': 'Pendiente',
          'folio': 'FOL002',
        },
        {
          'id': 3,
          'service_id': 3,
          'service_name': 'Teléfono',
          'amount': 100.0,
          'reference': 'REF003',
          'date': '2023-09-20T00:00:00Z',
          'status': 'Pagado',
          'folio': 'FOL003',
        },
        {
          'id': 4,
          'service_id': 4,
          'service_name': 'Internet',
          'amount': 250.0,
          'reference': 'REF004',
          'date': '2023-11-05T00:00:00Z',
          'status': 'Pendiente',
          'folio': null,
        },
      ];
    }

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
    } else {
      throw Exception('Error HTTP $statusCode: $body');
    }
  }

  // Cerrar cliente
  void dispose() {
    _client.close();
  }
}