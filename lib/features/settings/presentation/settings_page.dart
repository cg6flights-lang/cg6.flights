import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Configuracion',
      icon: Icons.tune,
      summary:
          'Preferencias operativas, idioma y parametros gobernados por permisos.',
      actions: ['Cambiar idioma', 'Revisar parametros'],
    );
  }
}
