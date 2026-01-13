import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Drawer(
      child: Column(
        children: [
          // info del usuario
          const UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 45, color: Colors.blueAccent),
            ),
            accountName: Text(
              "Usuario Kiosko",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text("soporte@kiosko.com"),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              image: DecorationImage(
                image: NetworkImage(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                ),
                opacity: 0.1,
              ),
            ),
          ),

          // Menú
          ListTile(
            leading: const Icon(Icons.home_outlined, color: Colors.blueAccent),
            title: const Text("Inicio"),
            onTap: () {
              // Cierra drawer y vamos a home
              Navigator.pop(context); 
            },
          ),

          ListTile(
            leading: const Icon(Icons.account_circle_outlined, color: Colors.blueAccent),
            title: const Text("Perfil"),
            onTap: () {
              Navigator.pop(context); // Cerrar menú
              Navigator.pushNamed(context, '/profile');
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.blueAccent),
            title: const Text("Configuración"),
            onTap: () {
              Navigator.pop(context); // Cerrar menú
              Navigator.pushNamed(context, '/settings');
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              "Cerrar Sesión",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              // 1. diálogo de confirmación
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Cerrar Sesión"),
                    content: const Text("¿Estás seguro de que deseas salir?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancelar"),
                      ),
                      TextButton(
                        onPressed: () async {
                          // 2. Borrar estado de login
                          await authService.logout();

                          if (!context.mounted) return;

                          // 3. Volver al Login eliminando todas las rutas previas
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                        child: const Text("Salir", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}