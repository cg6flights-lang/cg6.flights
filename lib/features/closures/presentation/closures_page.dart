import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class ClosuresPage extends StatelessWidget {
  const ClosuresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Cierres',
      icon: Icons.task_alt,
      summary:
          'Cierre protegido de ficha diaria con aprobacion, observacion o reapertura autorizada.',
      actions: ['Solicitar cierre', 'Aprobar cierre', 'Observar cierre'],
    );
  }
}
