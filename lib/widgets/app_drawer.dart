import 'package:flutter/material.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/data_provider.dart';
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
          Container(
            height: 103,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/svr_logo.png',
                width: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text("Mi perfil"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
                                ListTile(
                  leading: Icon(Icons.credit_card, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text("Tarjetas"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.cards);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text("Facturación"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.billing);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.onSurface),
                  title: const Text(
                    "Cerrar Sesión",
                  ),
                  onTap: () async {
                    // 1. diálogo de confirmación
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Cerrar sesión"),
                          content: const Text("¿Estás seguro de que deseas salir?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancelar"),
                            ),
                            TextButton(
                              onPressed: () async {
                                // 2. Obtener referencia al DataProvider
                                final dataProvider = Provider.of<DataProvider>(context, listen: false);
                                
                                // 3. Resetear estado de autorización
                                dataProvider.resetUnauthorized();
                                
                                // 4. Borrar estado de login
                                await authService.logout();

                                if (!context.mounted) return;

                                // 5. Volver al Login eliminando todas las rutas previas
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
