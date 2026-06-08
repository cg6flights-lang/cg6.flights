import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResumenWidget extends ConsumerWidget {
  const ResumenWidget({super.key, this.unitId, this.squadronId});
  final String? unitId;
  final String? squadronId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);
    final statsAsync = ref.watch(aircraftStatusProvider);

    final flightsCount = flightsAsync.asData?.value is AppSuccess
        ? (flightsAsync.asData!.value as AppSuccess).data.length
        : 0;

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('resumen')!,
      child: statsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, _) => const SizedBox.shrink(),
        data: (stats) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row(Icons.flight_takeoff, '$flightsCount vuelos programados', Colors.blue),
            const SizedBox(height: 4),
            _row(Icons.check_circle, '${stats.operational} aeronaves operativas', Colors.green),
            const SizedBox(height: 4),
            _row(Icons.warning_amber, '${stats.inoperative} inoperativas · ${stats.maintenance} en mantto.', Colors.orange),
          ]),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
    ]);
  }
}
