import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class FlightStatusPage extends StatelessWidget {
  const FlightStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return ModulePage(
      title: t('nav.flightStatus'),
      icon: Icons.timeline_outlined,
      summary:
          'Eventos secuenciales: motor, taxeo, despegue, aterrizaje y apagado.',
      actions: ['Registrar evento', 'Validar secuencia', 'Calcular tiempos'],
    );
  }
}
