/// Servicio para manejar la integración con OpenPay
/// Genera el device_session_id usando WebView invisible
class OpenPayService {
  // Configuración de OpenPay (sandbox)
  static const String _openPayId = 'mvqklc5fv1rsuqrttndt';
  static const String _openPayApiKey = 'pk_53706e08f72e45c585a55809e81636df';
  static const bool _sandboxMode = true;

  /// Genera el HTML para obtener el device session ID de OpenPay
  String generateDeviceSessionHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Device Session</title>
  <script type="text/javascript" src="https://openpay.s3.amazonaws.com/openpay.v1.min.js"></script>
</head>
<body>
  <script type="text/javascript">
    // Función para esperar a que OpenPay esté listo
    function waitForOpenPay(callback, maxAttempts = 50) {
      var attempts = 0;
      var interval = setInterval(function() {
        attempts++;
        if (typeof OpenPay !== 'undefined') {
          clearInterval(interval);
          callback();
        } else if (attempts >= maxAttempts) {
          clearInterval(interval);
          if (typeof FlutterWebChannel !== 'undefined') {
            FlutterWebChannel.postMessage(JSON.stringify({
              type: 'device_session_result',
              success: false,
              error: 'OpenPay no se pudo cargar después de ' + maxAttempts + ' intentos'
            }));
          }
        }
      }, 100);
    }

    // Inicializar y obtener device session ID
    waitForOpenPay(function() {
      try {
        OpenPay.setId('$_openPayId');
        OpenPay.setApiKey('$_openPayApiKey');
        OpenPay.setSandboxMode($_sandboxMode);

        var deviceSessionId = OpenPay.deviceData.setup();

        if (typeof FlutterWebChannel !== 'undefined') {
          FlutterWebChannel.postMessage(JSON.stringify({
            type: 'device_session_result',
            success: true,
            device_session_id: deviceSessionId
          }));
        }
      } catch (error) {
        if (typeof FlutterWebChannel !== 'undefined') {
          FlutterWebChannel.postMessage(JSON.stringify({
            type: 'device_session_result',
            success: false,
            error: error.toString()
          }));
        }
      }
    });
  </script>
</body>
</html>
''';
  }

  /// Genera el HTML para crear un token de tarjeta (para agregar nuevas tarjetas)
  String generateOpenPayHtml({
    required String cardNumber,
    required String holderName,
    required String expirationMonth,
    required String expirationYear,
    required String cvv2,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OpenPay Token</title>
  <script type="text/javascript" src="https://openpay.s3.amazonaws.com/openpay.v1.min.js"></script>
  <script type="text/javascript" src="https://openpay.s3.amazonaws.com/openpay-data.v1.min.js"></script>
</head>
<body>
  <script type="text/javascript">
    // Función para esperar a que OpenPay esté listo
    function waitForOpenPay(callback, maxAttempts = 50) {
      var attempts = 0;
      var interval = setInterval(function() {
        attempts++;
        if (typeof OpenPay !== 'undefined') {
          clearInterval(interval);
          callback();
        } else if (attempts >= maxAttempts) {
          clearInterval(interval);
          if (typeof FlutterWebChannel !== 'undefined') {
            FlutterWebChannel.postMessage(JSON.stringify({
              type: 'openpay_result',
              success: false,
              error: 'OpenPay no se pudo cargar después de ' + maxAttempts + ' intentos'
            }));
          }
        }
      }, 100);
    }

    // Inicializar y crear token
    waitForOpenPay(function() {
      try {
        OpenPay.setId('$_openPayId');
        OpenPay.setApiKey('$_openPayApiKey');
        OpenPay.setSandboxMode($_sandboxMode);

        var cardData = {
          card_number: '$cardNumber',
          holder_name: '$holderName',
          expiration_year: '$expirationYear',
          expiration_month: '$expirationMonth',
          cvv2: '$cvv2'
        };

        OpenPay.token.create(cardData, function(response) {
          if (typeof FlutterWebChannel !== 'undefined') {
            FlutterWebChannel.postMessage(JSON.stringify({
              type: 'openpay_result',
              success: true,
              data: response.data
            }));
          }
        }, function(error) {
          if (typeof FlutterWebChannel !== 'undefined') {
            FlutterWebChannel.postMessage(JSON.stringify({
              type: 'openpay_result',
              success: false,
              error: error.data.description || 'Error desconocido'
            }));
          }
        });
      } catch (error) {
        if (typeof FlutterWebChannel !== 'undefined') {
          FlutterWebChannel.postMessage(JSON.stringify({
            type: 'openpay_result',
            success: false,
            error: error.toString()
          }));
        }
      }
    });
  </script>
</body>
</html>
''';
  }
}
