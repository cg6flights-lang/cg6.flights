import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:cg6_flights/features/flights/presentation/metar_widget.dart'
    as metar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MetarDashboardWidget extends ConsumerWidget {
  const MetarDashboardWidget({super.key});

  static const _icaoCodes = [
    'SPJC',
    'SPQU',
    'SPQT',
    'SPRU',
    'SPZO',
    'SPCL',
    'SPST',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('metar')!,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: metar.MetarWidget(icaoCodes: _icaoCodes),
      ),
    );
  }
}
