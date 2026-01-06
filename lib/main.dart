import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';

void main() {
  // Necesario para que SharedPreferences funcione antes del runApp
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KioskoApp());
}

class KioskoApp extends StatelessWidget {
  const KioskoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosko',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const CheckAuthScreen(), // Aquí es donde tu test busca el CircularProgressIndicator
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
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
        // Este es el widget que tu test de Flutter está buscando
        child: CircularProgressIndicator(),
      ),
    );
  }
}