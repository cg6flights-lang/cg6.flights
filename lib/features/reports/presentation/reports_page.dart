import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Reportes',
      icon: Icons.picture_as_pdf_outlined,
      summary:
          'Modulo unico para PDF y Excel con permisos, filtros y auditoria.',
      actions: ['Generar PDF', 'Exportar Excel', 'Ver exportaciones'],
    );
  }
}
