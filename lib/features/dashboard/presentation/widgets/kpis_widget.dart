import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KpisWidget extends ConsumerWidget {
  const KpisWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);
    final statsAsync = ref.watch(aircraftStatusProvider);

    final flightsResult = flightsAsync.asData?.value;
    final flightsCount = switch (flightsResult) {
      AppSuccess(data: final f) => f.length,
      _ => null,
    };

    final child = statsAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const Padding(padding: EdgeInsets.all(20), child: Center(child: Icon(Icons.error_outline, size: 20))),
      data: (stats) => _KpisContent(stats: stats, flightsCount: flightsCount),
    );

    return DashboardWidgetWrapper(config: DashboardWidgetConfig.byId('kpis')!, child: child);
  }
}

class _KpisContent extends StatelessWidget {
  const _KpisContent({required this.stats, required this.flightsCount});
  final ({int total, int operational, int inoperative, int maintenance}) stats;
  final int? flightsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final operabilityPct = stats.total > 0 ? '${(stats.operational / stats.total * 100).round()}%' : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(children: [
        Row(children: [
          Expanded(child: _kpi(flightsCount?.toString() ?? '...', 'Vuelos Hoy', Colors.green, theme)),
          const SizedBox(width: 4),
          Expanded(child: _kpi(operabilityPct, 'Operatividad', Colors.blue, theme)),
          const SizedBox(width: 4),
          Expanded(child: _kpi(stats.inoperative.toString(), 'Inoperativas', Colors.red, theme)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _kpi(stats.operational.toString(), 'Ops', Colors.green.shade700, theme)),
          const SizedBox(width: 4),
          Expanded(child: _kpi(stats.maintenance.toString(), 'Mantenim.', Colors.orange.shade700, theme)),
          const SizedBox(width: 4),
          Expanded(child: _kpi(stats.total.toString(), 'Flota Total', theme.colorScheme.primary, theme)),
        ]),
      ]),
    );
  }

  Widget _kpi(String value, String label, Color color, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero, elevation: 0,
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: color.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
