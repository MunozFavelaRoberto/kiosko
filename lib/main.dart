import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  // Necesario para SharedPreferences funcione antes del runApp
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  runApp(ChangeNotifierProvider<ThemeProvider>.value(
    value: themeProvider,
    child: KioskoApp(),
  ));
}

// Navegador global para empujar rutas desde Widgets fuera del árbol
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
const MethodChannel _screenChannel = MethodChannel('com.example.kiosko/screen');

class KioskoApp extends StatelessWidget {
  const KioskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = false;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context);
      isDark = themeProvider.isDark;
    } catch (_) {
      isDark = false;
    }

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
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
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
  final AuthService _authService = AuthService();
  bool _wasPaused = false;
  DateTime? _pausedAt;
  bool _screenWasLocked = false;
  static const Duration _maxIdleForQuickUnlock = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for native screen on/off events
    _screenChannel.setMethodCallHandler((call) async {
      if (call.method == 'screenEvent') {
        final String event = call.arguments as String? ?? '';
        if (event == 'off') {
          // Mark that the screen was locked while app was active
          // so on resume we force the biometric lock even if short.
          _pausedAt = DateTime.now();
          // set a flag to indicate screen lock happened
          // we represent it by setting _wasPaused = true and _pausedAt now
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
      // La app fue enviada a background (posible bloqueo)
      _wasPaused = true;
      _pausedAt = DateTime.now();
    }

    if (state == AppLifecycleState.resumed) {
      // Volvió al frente; si antes se pausó, activamos bloqueo inteligente
      if (_wasPaused) {
        final now = DateTime.now();
        final diff = _pausedAt == null ? Duration.zero : now.difference(_pausedAt!);
        final longPause = diff > _maxIdleForQuickUnlock;
        // Forzar bloqueo si hubo una inactividad larga O si detectamos
        // que el teléfono fue apagado / bloqueado nativamente.
        if (longPause || _screenWasLocked) {
          _tryLockIfNeeded(true);
        }
        // reset screen-locked marker after handling
        _screenWasLocked = false;
      }
      _wasPaused = false;
    }
  }

  Future<void> _tryLockIfNeeded(bool longPause) async {
    final use = await _authService.getUseBiometrics();
    if (!use) return;

    if (!mounted) return;

    // Empujar la pantalla de bloqueo biométrica. BiometricLockScreen decide
    // si pop (resume) o navegar a /home (cold start) según 'forceToHome'.
    await appNavigatorKey.currentState?.push(MaterialPageRoute(
      builder: (context) => BiometricLockScreen(longPause: longPause, forceToHome: false),
      fullscreenDialog: true,
    ));
  }
  @override
  Widget build(BuildContext context) {
    // Ahora delegamos el bloqueo en `BiometricLockScreen` para mantener
    // comportamiento consistente entre cold start y resume.
    return widget.child;
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
    final authService = AuthService();
    final bool loggedIn = await authService.isLoggedIn();
    final bool bioEnabled = await authService.getUseBiometrics();
    
    if (!mounted) return;

    if (loggedIn) {
      if (bioEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BiometricLockScreen(forceToHome: true)),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
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