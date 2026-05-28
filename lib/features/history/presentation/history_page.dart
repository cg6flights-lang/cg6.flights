import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Historicos',
      icon: Icons.history,
      summary:
          'Consulta diaria, semanal, mensual y anual con filtros operativos.',
      actions: [
        'Filtrar por unidad',
        'Filtrar por aeronave',
        'Filtrar por ruta',
      ],
    );
  }
}
