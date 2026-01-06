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