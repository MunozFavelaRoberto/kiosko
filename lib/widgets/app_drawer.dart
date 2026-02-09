import 'package:flutter/material.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/utils/app_routes.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
            ),
            child: Center(
              child: Image.asset('assets/images/svr_logo.png'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
                  title: const Text("Perfil"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card, color: Colors.blueAccent),
                  title: const Text("Tarjetas"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.cards);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: Colors.blueAccent),
                  title: const Text("Facturación"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.billing);
                  },
                ),
                const Divider(),
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
                                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
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
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}
