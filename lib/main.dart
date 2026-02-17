import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/theme_provider.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/services/api_service.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/screens/login_screen.dart';
import 'package:kiosko/screens/billing_screen.dart';
import 'package:kiosko/screens/edit_billing_screen.dart';
import 'package:kiosko/screens/cards_screen.dart';
import 'package:kiosko/screens/add_card_screen.dart';
import 'package:kiosko/screens/home_screen.dart';
import 'package:kiosko/screens/profile_screen.dart';
import 'package:kiosko/screens/biometric_lock_screen.dart';
import 'package:kiosko/screens/payment_screen.dart';
import 'package:kiosko/screens/openpay_webview_screen.dart';
import 'package:kiosko/screens/payment_success_screen.dart';
import 'package:kiosko/utils/app_routes.dart';

Future<void> main() async {
  // Necesario para que SharedPreferences funcione antes del runApp
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<DataProvider>(
          create: (context) => DataProvider(
            authService: Provider.of<AuthService>(context, listen: false),
            apiService: Provider.of<ApiService>(context, listen: false),
          ),
        ),
      ],
      child: const KioskoApp(),
    ),
  );
}

// Navegador global para empujar rutas desde Widgets fuera del árbol
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
const MethodChannel _screenChannel = MethodChannel('com.example.kiosko/screen');

class KioskoApp extends StatelessWidget {
  const KioskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return MaterialApp(
      title: 'Kiosko',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return LockWrapper(child: child ?? const SizedBox.shrink());
      },
      home: const CheckAuthScreen(),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.cards: (context) => const CardsScreen(),
        AppRoutes.addCard: (context) => const AddCardScreen(),
        AppRoutes.billing: (context) => const BillingScreen(),
        AppRoutes.editBilling: (context) => const EditBillingScreen(),
        AppRoutes.payment: (context) => const PaymentScreen(),
        AppRoutes.openpayDeviceSession: (context) => const OpenPayDeviceSessionScreen(),
        AppRoutes.openpayWebview: (context) => const OpenPayWebViewScreen(
          cardNumber: '',
          holderName: '',
          expirationMonth: '',
          expirationYear: '',
          cvv2: '',
        ),
        AppRoutes.paymentSuccess: (context) => const PaymentSuccessScreen(),
      },
    );
  }
}

class LockWrapper extends StatefulWidget {
  final Widget child;
  const LockWrapper({required this.child, super.key});

  @override
  State<LockWrapper> createState() => _LockWrapperState();
}

class _LockWrapperState extends State<LockWrapper> with WidgetsBindingObserver {
  late final AuthService _authService;
  bool _wasPaused = false;
  DateTime? _pausedAt;
  bool _screenWasLocked = false;
  bool _isLockScreenActive = false;
  static const Duration _maxIdleForQuickUnlock = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _screenChannel.setMethodCallHandler((call) async {
      if (call.method == 'screenEvent') {
        final String event = call.arguments as String? ?? '';
        if (event == 'off') {
          _pausedAt = DateTime.now();
          _wasPaused = true;
          _screenWasLocked = true;
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      _pausedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      if (_wasPaused) {
        final now = DateTime.now();
        final diff = _pausedAt == null ? Duration.zero : now.difference(_pausedAt!);
        final longPause = diff > _maxIdleForQuickUnlock;
        if (longPause || _screenWasLocked) {
          _tryLockIfNeeded(true);
        }
        _screenWasLocked = false;
      }
      _wasPaused = false;
    }
  }

  Future<void> _tryLockIfNeeded(bool longPause) async {
    if (_isLockScreenActive) return;
    
    final use = await _authService.isAnyBiometricEnabled();
    if (!use) return;

    _isLockScreenActive = true;
    
    if (!mounted) return;

    await appNavigatorKey.currentState?.push(MaterialPageRoute(
      builder: (context) => BiometricLockScreen(longPause: longPause, forceToHome: false),
      fullscreenDialog: true,
    ));
    
    if (!mounted) return;
    _isLockScreenActive = false;
  }

  @override
  Widget build(BuildContext context) {
    // Verificar estado de autorización
    final dataProvider = context.watch<DataProvider>();
    
    // Solo mostrar pantalla de "No Autorizado" después de que:
    // 1. Se haya intentado obtener los datos del usuario (hasAttemptedFetch)
    // 2. Y el servidor haya rechazado la solicitud explícitamente
    if (dataProvider.hasAttemptedFetch && dataProvider.isUnauthorized) {
      return _buildUnauthorizedScreen(context, dataProvider);
    }
    
    return widget.child;
  }

  Widget _buildUnauthorizedScreen(BuildContext context, DataProvider dataProvider) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Text(
          'NO AUTORIZADO',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class CheckAuthScreen extends StatefulWidget {
  const CheckAuthScreen({super.key});

  @override
  State<CheckAuthScreen> createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends State<CheckAuthScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final bool loggedIn = await authService.isLoggedIn();
    final bool bioEnabled = await authService.isAnyBiometricEnabled();
    
    if (!mounted) return;

    if (loggedIn) {
      if (bioEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BiometricLockScreen(forceToHome: true)),
        );
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
