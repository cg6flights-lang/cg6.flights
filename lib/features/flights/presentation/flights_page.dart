import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class FlightsPage extends StatelessWidget {
  const FlightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Vuelos',
      icon: Icons.flight_takeoff,
      summary:
          'Vuelos individuales asociados a ficha diaria, aeronave, ruta y tripulacion.',
      actions: ['Crear vuelo', 'Editar vuelo', 'Consultar estado'],
    );
  }
}
