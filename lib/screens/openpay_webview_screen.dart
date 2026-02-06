import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:kiosko/services/openpay_service.dart';

/// Pantalla para crear token de OpenPay usando WebView
/// Se usa cuando se agrega una tarjeta nueva
class OpenPayWebViewScreen extends StatefulWidget {
  static const routeName = '/openpay-webview';

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

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterWebChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = json.decode(message.message) as Map<String, dynamic>;
            
            if (data['type'] == 'openpay_result') {
              if (data['success'] == true) {
                final result = data['data'] as Map<String, dynamic>?;
                if (result != null) {
                  Navigator.pop(context, result);
                } else {
                  Navigator.pop(context, {'error': 'Token no disponible'});
                }
              } else {
                Navigator.pop(context, {'error': data['error'] as String? ?? 'Error desconocido'});
              }
            }
          } catch (e) {
            Navigator.pop(context, {'error': 'Error parsing message: $e'});
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            Navigator.pop(context, {'error': 'Error de conexión: ${error.description}'});
          },
        ),
      );

    // Generar el HTML con los datos de la tarjeta
    final html = OpenPayService().generateOpenPayHtml(
      cardNumber: widget.cardNumber,
      holderName: widget.holderName,
      expirationMonth: widget.expirationMonth,
      expirationYear: widget.expirationYear,
      cvv2: widget.cvv2,
    );

    _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
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
      ),
    );
  }
}

/// Pantalla para obtener el Device Session ID de OpenPay
/// Se usa para pagos con tarjetas guardadas
/// Muestra solo un indicador de progreso simple
class OpenPayDeviceSessionScreen extends StatefulWidget {
  static const routeName = '/openpay-device-session';

  const OpenPayDeviceSessionScreen({super.key});

  @override
  State<OpenPayDeviceSessionScreen> createState() => _OpenPayDeviceSessionScreenState();
}

class _OpenPayDeviceSessionScreenState extends State<OpenPayDeviceSessionScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterWebChannel',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = json.decode(message.message) as Map<String, dynamic>;
            
            if (data['type'] == 'device_session_result') {
              if (data['success'] == true) {
                final deviceSessionId = data['device_session_id'] as String?;
                if (deviceSessionId != null) {
                  Navigator.pop(context, {'device_session_id': deviceSessionId});
                } else {
                  Navigator.pop(context, {'error': 'Device session ID no disponible'});
                }
              } else {
                Navigator.pop(context, {'error': data['error'] as String? ?? 'Error desconocido'});
              }
            }
          } catch (e) {
            Navigator.pop(context, {'error': 'Error parsing message: $e'});
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _error = null;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _error = 'Error: ${error.description}';
              _hasError = true;
            });
            // Cerrar después de mostrar el error brevemente
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                Navigator.pop(context, {'error': _error});
              }
            });
          },
        ),
      );

    // Generar el HTML para obtener device session
    final html = OpenPayService().generateDeviceSessionHtml();
    _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // WebView invisible pero funcional
          Positioned.fill(
            child: Visibility(
              visible: false,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          // Diálogo de progreso
          Center(
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasError)
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    )
                  else if (_isLoading)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.security,
                      color: Colors.blue,
                      size: 40,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Inicializando sistema de pagos...',
                    style: TextStyle(
                      fontSize: 14,
                      color: _hasError ? Colors.red : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isLoading && !_hasError) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
