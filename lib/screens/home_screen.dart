import 'package:flutter/material.dart';
import 'package:kiosko/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Vistas para las pestañas principales
  static const List<Widget> _pages = <Widget>[
    Center(child: Text('Pantalla de Inicio', style: TextStyle(fontSize: 18))),
    Center(child: Text('Pantalla de Pagos', style: TextStyle(fontSize: 18))),
  ];

  void _onDestinationSelected(int index) {
    if (index == 2) {
      // Si el índice es 2 (Menú), abrimos el Drawer y no cambiamos la pestaña
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Kiosko'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      drawer: const AppDrawer(),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.payment_outlined),
            selectedIcon: Icon(Icons.payment),
            label: 'Pagos',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Menú',
          ),
        ],
      ),
    );
  }
}