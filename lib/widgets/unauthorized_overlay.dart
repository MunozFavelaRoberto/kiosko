import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kiosko/services/data_provider.dart';
import 'package:kiosko/services/auth_service.dart';
import 'package:kiosko/utils/app_routes.dart';

/// Widget que muestra una pantalla de "No Autorizado" cuando el token expiró
/// Se superpone al contenido actual y bloquea la interacción
class UnauthorizedOverlay extends StatelessWidget {
  final Widget child;
  const UnauthorizedOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();

    if (!provider.isUnauthorized) {
      return child;
    }

    // Stack para superponer la pantalla de "no autorizado"
    return Stack(
      children: [
        // Contenido original (oscurecido y bloqueado)
        AbsorbPointer(
          absorbing: true,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.grey.shade300.withValues(alpha: 0.3),
                Colors.grey.shade300.withValues(alpha: 0.3),
              ],
            ).createShader(bounds),
            child: child,
          ),
        ),
        // Pantalla de "No Autorizado" centrada
        Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  color: Colors.red.shade700,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sesión Expirada',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu sesión ha expirado o fue revocada.\nPor favor inicia sesión nuevamente.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Cerrar sesión y navegar al login
                    final authService = context.read<AuthService>();
                    await authService.logout();
                    // Resetear estado de unauthorized
                    provider.resetUnauthorized();
                    // Navegar al login
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
