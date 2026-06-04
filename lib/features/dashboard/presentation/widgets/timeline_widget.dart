import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimelineWidget extends ConsumerWidget {
  const TimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);

    final child = flightsAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (f) => _TimelineContent(
        flights: switch (f) { AppSuccess(data: final d) => d, _ => [] },
      ),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('timeline')!,
      child: child,
    );
  }
}

double _maxd(double a, double b) => a > b ? a : b;

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.flights});
  final List<FlightOrderItem> flights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...flights]
      ..sort((a, b) => (a.scheduledDeparture ?? DateTime.now()).compareTo(b.scheduledDeparture ?? DateTime.now()));

    if (sorted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sin vuelos programados hoy', style: TextStyle(fontSize: 12))),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 16,
          child: LayoutBuilder(builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            return Stack(
              children: List.generate(24, (h) {
                return Positioned(
                  left: (h / 24) * totalWidth,
                  child: Text(h.toString().padLeft(2, '0'), style: theme.textTheme.labelSmall?.copyWith(fontSize: 8, color: theme.colorScheme.onSurfaceVariant)),
                );
              }),
            );
          }),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: LayoutBuilder(builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            return Stack(
              children: [
                ...List.generate(23, (h) {
                  final left = ((h + 1) / 24) * totalWidth;
                  return Positioned(left: left, top: 0, bottom: 0, child: Container(width: 0.5, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)));
                }),
                ...sorted.map((f) {
                  final dept = f.scheduledDeparture ?? DateTime.now();
                  final hourFraction = dept.hour + dept.minute / 60.0;
                  final left = (hourFraction / 24) * totalWidth;
                  final eteMinutes = f.eteMinutes ?? 60;
                  final widthPx = ((eteMinutes / 60.0) / 24) * totalWidth;
                  final statusColor = StatusColors.of(f.status);
                  final label = f.aircraftRegistration?.isNotEmpty == true ? f.aircraftRegistration! : (f.aircraftModel?.isNotEmpty == true ? f.aircraftModel! : '?');
                  return Positioned(
                    left: left.clamp(0, totalWidth - 20).toDouble(),
                    top: 4,
                    child: Tooltip(
                      message: '$label — ${f.routes.isNotEmpty ? "${f.routes.first.originIcao}→${f.routes.first.destinationIcao}" : ""} — $eteMinutes min',
                      child: Container(
                        height: 40, width: _maxd(widthPx, 16),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(3), border: Border.all(color: statusColor, width: 1)),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 8, fontWeight: FontWeight.w700, color: statusColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${dept.hour.toString().padLeft(2, '0')}:${dept.minute.toString().padLeft(2, '0')}', style: theme.textTheme.labelSmall?.copyWith(fontSize: 7, color: theme.colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final entry in StatusColors.flightItem.entries.take(5))
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: entry.value)),
              const SizedBox(width: 3),
              Text(entry.key, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
            ]),
        ]),
      ]),
    );
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
