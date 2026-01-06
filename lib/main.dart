import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para procesos async antes de iniciar
  runApp(const KioskoApp());
}

class KioskoApp extends StatelessWidget {
  const KioskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosko App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // En lugar de home: LoginScreen(), usamos nuestro "CheckAuthScreen"
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

// Widget que decide a dónde ir
class CheckAuthScreen extends StatefulWidget {
  const CheckAuthScreen({super.key});

  @override
  State<CheckAuthScreen> createState() => _CheckAuthScreenState();
}

class _CheckAuthScreenState extends State<CheckAuthScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authService = AuthService();
    final bool isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Si está logueado, vamos directo al Home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Si no, vamos al Login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras verifica, mostramos un spinner de carga
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}