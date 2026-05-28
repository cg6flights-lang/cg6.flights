import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class MapsPage extends StatelessWidget {
  const MapsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Mapas',
      icon: Icons.map_outlined,
      summary:
          'Proveedor encapsulado para rutas y localidades autorizadas; geolocalizacion remota queda bloqueada.',
      actions: ['Ver ruta', 'Ver localidad', 'Validar politica'],
    );
  }
}
