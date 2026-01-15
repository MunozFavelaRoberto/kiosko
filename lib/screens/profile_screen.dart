import 'package:flutter/material.dart';
import 'package:kiosko/widgets/client_number_header.dart';

class ProfileScreen extends StatelessWidget {
  static const routeName = '/profile';

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: Column(
        children: [
          const ClientNumberHeader(),
          const Expanded(
            child: Center(
              child: Text('Esta es la pantalla de perfil.'),
            ),
          ),
        ],
      ),
    );
  }
}