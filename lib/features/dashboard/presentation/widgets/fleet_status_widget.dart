import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FleetStatusWidget extends ConsumerWidget {
  const FleetStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(aircraftStatusProvider);

    final child = statsAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (stats) => _FleetContent(stats: stats),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('fleet')!,
      child: child,
    );
  }
}

class _FleetContent extends StatelessWidget {
  const _FleetContent({required this.stats});
  final ({int total, int operational, int inoperative, int maintenance}) stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats.total;
    final opPct = total > 0 ? (stats.operational / total * 100).round() : 0;
    final inopPct = total > 0 ? (stats.inoperative / total * 100).round() : 0;
    final mantoPct = total > 0 ? (stats.maintenance / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              Flexible(flex: opPct, child: Container(color: Colors.green)),
              Flexible(flex: inopPct, child: Container(color: Colors.orange)),
              Flexible(flex: mantoPct, child: Container(color: Colors.red.shade300)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _chip('$opPct%', 'Operativas', Colors.green, theme),
          const SizedBox(width: 8),
          _chip(stats.operational.toString(), 'Ops', Colors.green, theme),
          const SizedBox(width: 8),
          _chip(stats.inoperative.toString(), 'Inop', Colors.orange, theme),
          const SizedBox(width: 8),
          _chip(stats.maintenance.toString(), 'Manto', Colors.red.shade300, theme),
        ]),
      ]),
    );
  }

  Widget _chip(String value, String label, Color color, ThemeData theme) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(value, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(width: 2),
      Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}
