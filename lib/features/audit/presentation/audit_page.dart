import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Auditoria',
      icon: Icons.fact_check_outlined,
      summary:
          'Trazabilidad transversal de acciones criticas y denegaciones autenticadas.',
      actions: ['Consultar eventos', 'Filtrar actor', 'Filtrar recurso'],
    );
  }
}
