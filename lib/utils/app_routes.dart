class AppRoutes {
  // Rutas de autenticación
  static const String login = '/login';
  static const String biometricLock = '/biometric-lock';

  // Rutas principales
  static const String home = '/home';
  static const String profile = '/profile';
  static const String payment = '/payment';
  static const String paymentSuccess = '/payment-success';

  // Rutas de tarjetas
  static const String cards = '/cards';
  static const String addCard = '/add-card';

  // Rutas de facturación
  static const String billing = '/billing';
  static const String editBilling = '/edit-billing';

  // Rutas de OpenPay
  static const String openpayDeviceSession = '/openpay-device-session';
  static const String openpayWebview = '/openpay-webview';

  // Constructor privado para evitar instanciación
  AppRoutes._();
}
