import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Instanciamos el servicio para usar la función logout()
    final AuthService authService = AuthService();

    return Drawer(
      child: Column(
        children: [
          // Cabecera del Drawer (Donde suele ir la info del usuario)
          UserAccountsDrawerHeader(
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 45, color: Colors.blueAccent),
            ),
            accountName: const Text(
              "Usuario Kiosko",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text("soporte@kiosko.com"),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              image: DecorationImage(
                image: NetworkImage(
                  "https://www.transparenttextures.com/patterns/cubes.png",
                ),
                opacity: 0.1,
              ),
            ),
          ),

          // Opción Inicio
          ListTile(
            leading: const Icon(Icons.home_outlined, color: Colors.blueAccent),
            title: const Text("Inicio"),
            onTap: () {
              // Cerramos el drawer y vamos a home (si no estamos ya ahí)
              Navigator.pop(context); 
            },
          ),

          // Opción Perfil
          ListTile(
            leading: const Icon(Icons.account_circle_outlined, color: Colors.blueAccent),
            title: const Text("Perfil"),
            onTap: () {
              Navigator.pop(context); // Cerrar menú
              Navigator.pushNamed(context, '/profile');
            },
          ),

          // Opción Configuración
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.blueAccent),
            title: const Text("Configuración"),
            onTap: () {
              Navigator.pop(context); // Cerrar menú
              Navigator.pushNamed(context, '/settings');
            },
          ),

          // Espaciador para empujar el botón de cerrar sesión al final
          const Spacer(),

          const Divider(),

          // Opción Cerrar Sesión
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              "Cerrar Sesión",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              // 1. Mostrar diálogo de confirmación (Mejora la UX)
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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text("Salir", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}