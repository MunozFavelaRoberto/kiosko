import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
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
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    }

    if (state == AppLifecycleState.resumed) {
      // Volvió al frente; si antes se pausó, activamos bloqueo inteligente
      if (_wasPaused) {
        _tryLockIfNeeded();
      }
      _wasPaused = false;
    }
  }

  Future<void> _tryLockIfNeeded() async {
    final use = await _authService.getUseBiometrics();
    if (!use) return;

    // Mostrar pantalla bloqueada y pedir autenticación
    if (!mounted) return;
    setState(() => _locked = true);

    bool ok = false;

    ok = await _authService.authenticate();

    if (ok && mounted) {
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          // Pantalla bloqueada
          Positioned.fill(
            child: Container(
              color: Colors.indigo.shade900,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 80, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'Aplicación Bloqueada',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Por favor, autentícate con tu huella para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _authService.authenticate();
                        if (ok && mounted) setState(() => _locked = false);
                      },
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
    final authService = AuthService();
    final bool loggedIn = await authService.isLoggedIn();
    
    if (!mounted) return;

    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
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