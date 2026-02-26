import 'package:flutter/material.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/utils/app_routes.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
                'assets/images/cmapa_logo.png',
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
                    // 1. Guardar referencias antes del async
                    final navigator = Navigator.of(context);
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final dataProvider = Provider.of<DataProvider>(context, listen: false);
                    final overlayState = Overlay.of(context);
                    
                    // 2. Diálogo de confirmación
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text("Cerrar sesión"),
                          content: const Text("¿Estás seguro de que deseas salir?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text("Cancelar", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text("Salir", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                    
                    if (shouldLogout != true) return;
                    
                    // 3. Mostrar diálogo de cierre de sesión usando overlayState
                    final overlayEntry = OverlayEntry(
                      builder: (context) => PopScope(
                        canPop: false,
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: AlertDialog(
                              backgroundColor: Colors.grey.shade800,
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    'Cerrando sesión...',
                                    style: TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                    
                    overlayState.insert(overlayEntry);
                    
                    // 4. Resetear estado de autorización
                    dataProvider.resetUnauthorized();
                    
                    // 5. Borrar estado de login
                    await authService.logout();

                    // Delay obligatorio de 1 segundo para mostrar feedback al usuario
                    await Future.delayed(const Duration(seconds: 1));

                    // 6. Cerrar el diálogo de logout y volver al Login
                    overlayEntry.remove(); // Cerrar el overlay de "Cerrando sesión..."
                    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
