import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';

/// Configuración de OpenPay
/// Basado en la implementación de Vue 3
class _OpenPayConfig {
  static const String openpayId = 'mvqklc5fv1rsuqrttndt';
  static const String openpayApikey = 'pk_53706e08f72e45c585a55809e81636df';
  static const bool sandboxMode = true;
}

/// Servicio para manejar pagos con OpenPay usando WebView
/// Basado en la implementación de Vue 3 proporcionada
class OpenPayService {
  static const String _openpayId = _OpenPayConfig.openpayId;
  static const String _openpayApikey = _OpenPayConfig.openpayApikey;
  static const bool _sandboxMode = _OpenPayConfig.sandboxMode;

  String? _deviceSessionId;
  bool _isInitialized = false;

  String? get deviceSessionId => _deviceSessionId;
  bool get isInitialized => _isInitialized;

  /// Inicializa OpenPay y obtiene el device session ID
  Future<String?> initializeOpenPay() async {
    if (_isInitialized && _deviceSessionId != null) {
      return _deviceSessionId;
    }

    // El device session ID se obtendrá desde el WebView
    _isInitialized = true;
    return _deviceSessionId;
  }

  /// Genera el HTML para el WebView de OpenPay
  String generateOpenPayHtml({
    required String cardNumber,
    required String holderName,
    required String expirationMonth,
    required String expirationYear,
    required String cvv2,
  }) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Token</title>
  <script
    type="text/javascript"
    src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"
  ></script>
  <script
    type="text/javascript"
    src="https://openpay.s3.amazonaws.com/openpay.v1.min.js"
  ></script>
  <script
    type="text/javascript"
    src="https://openpay.s3.amazonaws.com/openpay-data.v1.min.js"
  ></script>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      margin: 0;
      padding: 20px;
      background-color: #f5f5f5;
    }
    .container {
      max-width: 400px;
      margin: 0 auto;
      background: white;
      padding: 24px;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .info {
      background: #e3f2fd;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 16px;
      font-size: 14px;
      color: #1565c0;
    }
    .success {
      background: #e8f5e9;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 16px;
      color: #2e7d32;
    }
    .error {
      background: #ffebee;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 16px;
      color: #c62828;
    }
    .loading {
      text-align: center;
      padding: 24px;
    }
    .spinner {
      border: 3px solid #f3f3f3;
      border-top: 3px solid #3498db;
      border-radius: 50%;
      width: 30px;
      height: 30px;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="container">
    <div id="status" class="loading">
      <div class="spinner"></div>
      <div>Procesando tarjeta...</div>
    </div>
  </div>

  <script type="text/javascript">
    let deviceSessionId = null;
    let tokenId = null;
    let errorMsg = null;

    // Configuración de OpenPay
    OpenPay.setId('$_openpayId');
    OpenPay.setApiKey('$_openpayApikey');
    OpenPay.setSandboxMode($_sandboxMode);

    // Obtener device session ID
    function getDeviceSessionId() {
      try {
        deviceSessionId = OpenPay.deviceData.setup();
        return deviceSessionId;
      } catch (e) {
        errorMsg = 'Error al obtener device session ID: ' + e.message;
        return null;
      }
    }

    // Crear token de la tarjeta
    function createToken(cardData) {
      return new Promise((resolve, reject) => {
        OpenPay.token.create(
          cardData,
          (response) => {
            tokenId = response.data.id;
            resolve(tokenId);
          },
          (error) => {
            errorMsg = error.data.description || 'Error al crear token';
            reject(errorMsg);
          }
        );
      });
    }

    // Enviar resultado a Flutter
    function sendResultToFlutter(success, data) {
      if (window.flutterWebChannel) {
        window.flutterWebChannel.postMessage(JSON.stringify({
          type: 'openpay_result',
          success: success,
          data: data,
          error: errorMsg
        }));
      }
    }

    // Función principal
    async function init() {
      try {
        // 1. Obtener device session ID
        const deviceId = getDeviceSessionId();
        if (!deviceId) {
          throw new Error(errorMsg || 'No se pudo obtener device session ID');
        }

        // 2. Datos de la tarjeta
        const cardData = {
          card_number: '$cardNumber',
          holder_name: '$holderName',
          expiration_year: '$expirationYear',
          expiration_month: '$expirationMonth',
          cvv2: '$cvv2'
        };

        // 3. Crear token
        const token = await createToken(cardData);

        // 4. Enviar resultado exitoso
        document.getElementById('status').innerHTML = 
          '<div class="success">Tarjeta procesada correctamente</div>';
        
        sendResultToFlutter(true, {
          token_id: token,
          device_session_id: deviceId
        });

      } catch (e) {
        document.getElementById('status').innerHTML = 
          '<div class="error">Error: ' + (errorMsg || e.message) + '</div>';
        
        sendResultToFlutter(false, {
          error: errorMsg || e.message
        });
      }
    }

    // Escuchar mensajes de Flutter
    window.addEventListener('message', function(event) {
      if (event.data && event.data.type === 'start_token_creation') {
        init();
      }
    });

    // Iniciar automáticamente cuando cargue
    window.onload = function() {
      // Pequeño delay para asegurar que OpenPay esté cargado
      setTimeout(init, 500);
    };
  </script>
</body>
</html>
''';
  }

  /// Genera el HTML para obtener el device session ID
  String generateDeviceSessionHtml() {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Device Session</title>
  <script
    type="text/javascript"
    src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"
  ></script>
  <script
    type="text/javascript"
    src="https://openpay.s3.amazonaws.com/openpay.v1.min.js"
  ></script>
  <script
    type="text/javascript"
    src="https://openpay.s3.amazonaws.com/openpay-data.v1.min.js"
  ></script>
</head>
<body>
  <script type="text/javascript">
    let deviceSessionId = null;
    let errorMsg = null;

    OpenPay.setId('$_openpayId');
    OpenPay.setApiKey('$_openpayApikey');
    OpenPay.setSandboxMode($_sandboxMode);

    try {
      deviceSessionId = OpenPay.deviceData.setup();
    } catch (e) {
      errorMsg = e.message;
    }

    if (window.flutterWebChannel) {
      window.flutterWebChannel.postMessage(JSON.stringify({
        type: 'device_session_result',
        success: errorMsg === null,
        device_session_id: deviceSessionId,
        error: errorMsg
      }));
    }
  </script>
</body>
</html>
''';
  }
}

/// Controlador de WebView para OpenPay
class OpenPayWebViewController {
  final WebViewController _controller;
  final Completer<String> _deviceSessionCompleter = Completer<String>();
  final Completer<Map<String, dynamic>> _tokenCompleter = Completer<Map<String, dynamic>>();

  OpenPayWebViewController(this._controller) {
    _setupJavaScriptChannel();
  }

  void _setupJavaScriptChannel() {
    _controller.addJavaScriptChannel(
      'FlutterWebChannel',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = json.decode(message.message) as Map<String, dynamic>;
          
          switch (data['type']) {
            case 'device_session_result':
              if (data['success'] == true) {
                _deviceSessionCompleter.complete(data['device_session_id'] as String?);
              } else {
                _deviceSessionCompleter.completeError(data['error'] as String? ?? 'Error desconocido');
              }
              break;
            case 'openpay_result':
              if (data['success'] == true) {
                _tokenCompleter.complete(data['data'] as Map<String, dynamic>);
              } else {
                _tokenCompleter.completeError(data['data']['error'] as String? ?? 'Error desconocido');
              }
              break;
          }
        } catch (e) {
          _tokenCompleter.completeError('Error parsing message: $e');
        }
      },
    );
  }

  Future<String> getDeviceSessionId() {
    _controller.runJavaScript('window.flutterWebChannel.postMessage(JSON.stringify({type: "get_device_session"}));');
    return _deviceSessionCompleter.future;
  }

  Future<Map<String, dynamic>> createToken({
    required String cardNumber,
    required String holderName,
    required String expirationMonth,
    required String expirationYear,
    required String cvv2,
  }) {
    final html = OpenPayService().generateOpenPayHtml(
      cardNumber: cardNumber,
      holderName: holderName,
      expirationMonth: expirationMonth,
      expirationYear: expirationYear,
      cvv2: cvv2,
    );
    _controller.loadHtmlString(html);
    return _tokenCompleter.future;
  }

  Future<String> initializeAndGetDeviceSession() {
    final html = OpenPayService().generateDeviceSessionHtml();
    _controller.loadHtmlString(html);
    return _deviceSessionCompleter.future;
  }
}
