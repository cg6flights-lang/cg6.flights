import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class FlightStatusPage extends StatelessWidget {
  const FlightStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Estados de Vuelo',
      icon: Icons.timeline_outlined,
      summary:
          'Eventos secuenciales: motor, taxeo, despegue, aterrizaje y apagado.',
      actions: ['Registrar evento', 'Validar secuencia', 'Calcular tiempos'],
    );
  }
}
