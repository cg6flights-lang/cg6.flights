import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class ClosuresPage extends StatelessWidget {
  const ClosuresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return ModulePage(
      title: t('nav.closures'),
      icon: Icons.task_alt,
      summary:
          'Cierre protegido de ficha diaria con aprobacion, observacion o reapertura autorizada.',
      actions: ['Solicitar cierre', 'Aprobar cierre', 'Observar cierre'],
    );
  }
}
