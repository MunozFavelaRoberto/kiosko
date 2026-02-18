import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Pantalla Session ID de OpenPay
// Se muestra como un diálogo simple mientras carga
class OpenPayDeviceSessionScreen extends StatefulWidget {
  const OpenPayDeviceSessionScreen({super.key});

  @override
  State<OpenPayDeviceSessionScreen> createState() => _OpenPayDeviceSessionScreenState();
}

class _OpenPayDeviceSessionScreenState extends State<OpenPayDeviceSessionScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    debugPrint('OpenPayDeviceSessionScreen: Inicializando...');
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..addJavaScriptChannel(
        'FlutterWebChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('OpenPayDeviceSessionScreen: Mensaje recibido: ${message.message}');
          
          if (_hasResult) return;
          _hasResult = true;
          
          try {
            final data = json.decode(message.message) as Map<String, dynamic>;
            debugPrint('OpenPayDeviceSessionScreen: Data parseada: $data');
            
            if (data['type'] == 'device_session_result') {
              if (data['success'] == true) {
                final deviceSessionId = data['device_session_id'] as String?;
                debugPrint('OpenPayDeviceSessionScreen: Device session ID obtenido: $deviceSessionId');
                if (deviceSessionId != null && deviceSessionId.isNotEmpty) {
                  Navigator.pop(context, {'device_session_id': deviceSessionId});
                } else {
                  debugPrint('OpenPayDeviceSessionScreen: Error - Device session ID vacío');
                  Navigator.pop(context, {'error': 'Device session ID vacío'});
                }
              } else {
                final error = data['error'] as String? ?? 'Error desconocido';
                debugPrint('OpenPayDeviceSessionScreen: Error de OpenPay: $error');
                Navigator.pop(context, {'error': error});
              }
            }
          } catch (e) {
            debugPrint('OpenPayDeviceSessionScreen: Error parseando mensaje: $e');
            Navigator.pop(context, {'error': 'Error parsing message: $e'});
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('OpenPayDeviceSessionScreen: Page started: $url');
          },
          onPageFinished: (String url) {
            debugPrint('OpenPayDeviceSessionScreen: Page finished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('OpenPayDeviceSessionScreen: Web resource error: ${error.description}');
            if (!mounted || _hasResult) return;
            setState(() {
              _isLoading = false;
              _error = 'Error de conexión: ${error.description}';
            });
          },
        ),
      );

    // Cargar HTML básico que carga OpenPay dinámicamente
    final html = _generateHtml();
    debugPrint('OpenPayDeviceSessionScreen: Cargando HTML...');
    debugPrint('HTML length: ${html.length} characters');
    _controller.loadHtmlString(html);
  }

  String _generateHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Device Session</title>
  <style>
    body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f5f5f5; }
    .container { text-align: center; padding: 20px; }
    .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="container">
    <div id="spinner" class="spinner"></div>
    <div id="status">Cargando OpenPay...</div>
  </div>
  
  <script type="text/javascript">
    console.log('=== HTML Cargado ===');
    
    function sendToFlutter(type, success, data, error) {
      var message = JSON.stringify({ type: type, success: success, device_session_id: data, error: error });
      console.log('=== Enviando a Flutter: ' + message + ' ===');
      try {
        FlutterWebChannel.postMessage(message);
      } catch(e) {
        console.error('Error enviando a Flutter: ' + e);
      }
    }
    
    function loadScript(src, callback) {
      console.log('Cargando script: ' + src);
      var script = document.createElement('script');
      script.src = src;
      script.onload = function() {
        console.log('Script cargado: ' + src);
        callback(true);
      };
      script.onerror = function() {
        console.error('Error cargando: ' + src);
        callback(false);
      };
      document.head.appendChild(script);
    }
    
    function initOpenPay() {
      console.log('=== Iniciando OpenPay ===');
      console.log('typeof OpenPay: ' + typeof OpenPay);
      
      if (typeof OpenPay === 'undefined') {
        console.error('OpenPay NO está definido');
        document.getElementById('status').innerHTML = 'Error: OpenPay no se pudo cargar';
        sendToFlutter('device_session_result', false, null, 'OpenPay no se pudo cargar');
        return;
      }
      
      console.log('OpenPay SÍ está definido');
      document.getElementById('status').innerHTML = 'OpenPay cargado. Obteniendo Device Session ID...';
      
      try {
        OpenPay.setId('mvqklc5fv1rsuqrttndt');
        OpenPay.setApiKey('pk_53706e08f72e45c585a55809e81636df');
        OpenPay.setSandboxMode(true);
        
        console.log('=== Configuración completada ===');
        console.log('Intentando deviceData.setup()...');
        
        var deviceSessionId = OpenPay.deviceData.setup();
        console.log('deviceData.setup() result: ' + deviceSessionId);
        console.log('typeof result: ' + typeof deviceSessionId);
        
        if (deviceSessionId && deviceSessionId.length > 0) {
          document.getElementById('spinner').className = '';
          document.getElementById('status').innerHTML = '✓ Device Session ID obtenido';
          document.getElementById('status').style.color = 'green';
          sendToFlutter('device_session_result', true, deviceSessionId, null);
        } else {
          console.error('Device session ID vacío');
          document.getElementById('status').innerHTML = 'Error: Device Session ID vacío';
          sendToFlutter('device_session_result', false, null, 'Device Session ID vacío');
        }
      } catch (error) {
        console.error('Error en initOpenPay: ' + error);
        document.getElementById('status').innerHTML = 'Error: ' + error;
        sendToFlutter('device_session_result', false, null, error.toString());
      }
    }
    
    // Cargar scripts de OpenPay
    console.log('=== Iniciando carga de scripts ===');
    loadScript('https://openpay.s3.amazonaws.com/openpay.v1.min.js', function(success1) {
      if (!success1) {
        sendToFlutter('device_session_result', false, null, 'Error cargando openpay.v1.min.js');
        return;
      }
      
      loadScript('https://openpay.s3.amazonaws.com/openpay-data.v1.min.js', function(success2) {
        if (!success2) {
          sendToFlutter('device_session_result', false, null, 'Error cargando openpay-data.v1.min.js');
          return;
        }
        
        // Ambos scripts cargados, inicializar OpenPay
        initOpenPay();
      });
    });
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    // Ocultar la barra de estado para un pengalaman más fluido
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 52,
                )
              else
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              const SizedBox(height: 24),
              Text(
                _error ?? 'Procesando...',
                style: TextStyle(
                  fontSize: 15,
                  color: _error != null ? Colors.red : Colors.grey[700],
                  fontWeight: _error != null ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isLoading && _error == null) ...[
                const SizedBox(height: 20),
                const SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Pantalla para crear token de OpenPay usando WebView
// Se usa cuando se agrega una tarjeta nueva
class OpenPayWebViewScreen extends StatefulWidget {
  final String cardNumber;
  final String holderName;
  final String expirationMonth;
  final String expirationYear;
  final String cvv2;

  const OpenPayWebViewScreen({
    super.key,
    required this.cardNumber,
    required this.holderName,
    required this.expirationMonth,
    required this.expirationYear,
    required this.cvv2,
  });

  @override
  State<OpenPayWebViewScreen> createState() => _OpenPayWebViewScreenState();
}

class _OpenPayWebViewScreenState extends State<OpenPayWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasResult = false;

  @override
  void initState() {
    super.initState();
    debugPrint('OpenPayWebViewScreen: Inicializando para tokenizar tarjeta...');
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..addJavaScriptChannel(
        'FlutterWebChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('OpenPayWebViewScreen: Mensaje recibido: ${message.message}');
          
          if (_hasResult) return;
          _hasResult = true;
          
          try {
            final data = json.decode(message.message) as Map<String, dynamic>;
            debugPrint('OpenPayWebViewScreen: Data parseada: $data');
            
            if (data['type'] == 'openpay_result') {
              if (data['success'] == true) {
                final result = data['data'] as Map<String, dynamic>?;
                debugPrint('OpenPayWebViewScreen: Token obtenido: $result');
                if (result != null) {
                  Navigator.pop(context, result);
                } else {
                  debugPrint('OpenPayWebViewScreen: Error - Token es null');
                  Navigator.pop(context, {'error': 'Token no disponible'});
                }
              } else {
                final error = data['error'] as String? ?? 'Error desconocido';
                debugPrint('OpenPayWebViewScreen: Error de OpenPay: $error');
                Navigator.pop(context, {'error': error});
              }
            }
          } catch (e) {
            debugPrint('OpenPayWebViewScreen: Error parseando mensaje: $e');
            Navigator.pop(context, {'error': 'Error parsing message: $e'});
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('OpenPayWebViewScreen: Page started: $url');
          },
          onPageFinished: (String url) {
            debugPrint('OpenPayWebViewScreen: Page finished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('OpenPayWebViewScreen: Web resource error: ${error.description}');
            if (_hasResult) return;
            _hasResult = true;
            Navigator.pop(context, {'error': 'Error de conexión: ${error.description}'});
          },
        ),
      );

    final html = _generateHtml();
    debugPrint('OpenPayWebViewScreen: Cargando HTML...');
    _controller.loadHtmlString(html);
  }

  String _generateHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Token</title>
  <style>
    body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f5f5f5; }
    .container { text-align: center; padding: 20px; }
    .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="container">
    <div id="spinner" class="spinner"></div>
    <div id="status">Creando token...</div>
  </div>
  
  <script type="text/javascript">
    console.log('=== HTML Cargado para Token ===');
    
    function sendToFlutter(type, success, data, error) {
      var message = JSON.stringify({ type: type, success: success, data: data, error: error });
      console.log('=== Enviando a Flutter: ' + message + ' ===');
      try {
        FlutterWebChannel.postMessage(message);
      } catch(e) {
        console.error('Error enviando a Flutter: ' + e);
      }
    }
    
    function loadScript(src, callback) {
      console.log('Cargando script: ' + src);
      var script = document.createElement('script');
      script.src = src;
      script.onload = function() {
        console.log('Script cargado: ' + src);
        callback(true);
      };
      script.onerror = function() {
        console.error('Error cargando: ' + src);
        callback(false);
      };
      document.head.appendChild(script);
    }
    
    function createToken() {
      console.log('=== Creando Token ===');
      console.log('typeof OpenPay: ' + typeof OpenPay);
      
      if (typeof OpenPay === 'undefined') {
        console.error('OpenPay NO está definido');
        sendToFlutter('openpay_result', false, null, 'OpenPay no se pudo cargar');
        return;
      }
      
      console.log('OpenPay SÍ está definido');
      document.getElementById('status').innerHTML = 'Creando token con tarjeta...';
      
      try {
        OpenPay.setId('mvqklc5fv1rsuqrttndt');
        OpenPay.setApiKey('pk_53706e08f72e45c585a55809e81636df');
        OpenPay.setSandboxMode(true);
        
        var cardData = {
          card_number: '${widget.cardNumber}',
          holder_name: '${widget.holderName}',
          expiration_year: '${widget.expirationYear}',
          expiration_month: '${widget.expirationMonth}',
          cvv2: '${widget.cvv2}'
        };
        
        console.log('Intentando crear token...');
        
        OpenPay.token.create(cardData, function(response) {
          console.log('Token creado exitosamente: ' + JSON.stringify(response));
          document.getElementById('spinner').className = '';
          document.getElementById('status').innerHTML = '✓ Token creado';
          document.getElementById('status').style.color = 'green';
          sendToFlutter('openpay_result', true, response.data, null);
        }, function(error) {
          console.error('Error creando token: ' + JSON.stringify(error));
          document.getElementById('status').innerHTML = 'Error: ' + (error.data?.description || 'Error desconocido');
          document.getElementById('status').style.color = 'red';
          sendToFlutter('openpay_result', false, null, error.data?.description || 'Error desconocido');
        });
      } catch (error) {
        console.error('Error en createToken: ' + error);
        document.getElementById('status').innerHTML = 'Error: ' + error;
        sendToFlutter('openpay_result', false, null, error.toString());
      }
    }
    
    // Cargar scripts de OpenPay
    console.log('=== Iniciando carga de scripts ===');
    loadScript('https://openpay.s3.amazonaws.com/openpay.v1.min.js', function(success1) {
      if (!success1) {
        sendToFlutter('openpay_result', false, null, 'Error cargando openpay.v1.min.js');
        return;
      }
      
      loadScript('https://openpay.s3.amazonaws.com/openpay-data.v1.min.js', function(success2) {
        if (!success2) {
          sendToFlutter('openpay_result', false, null, 'Error cargando openpay-data.v1.min.js');
          return;
        }
        
        // Ambos scripts cargados, crear token
        createToken();
      });
    });
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.credit_card,
                  color: Colors.blue,
                  size: 64,
                ),
              const SizedBox(height: 24),
              const Text(
                'Procesando tarjeta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Creando token con OpenPay...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
