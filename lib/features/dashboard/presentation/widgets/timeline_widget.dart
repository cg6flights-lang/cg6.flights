import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
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
    final tz = ref.watch(timezoneProvider);

    final child = flightsAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (f) => _TimelineContent(
        flights: switch (f) { AppSuccess(data: final d) => d, _ => [] },
        tz: tz,
      ),
    );

    return DashboardWidgetWrapper(config: DashboardWidgetConfig.byId('timeline')!, child: child);
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.flights, required this.tz});
  final List<FlightOrderItem> flights;
  final int tz;

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // Hour scale
        SizedBox(
          height: 18,
          child: LayoutBuilder(builder: (ctx, c) {
            return Stack(children: [
              for (int h = 0; h <= 24; h += 3)
                Positioned(
                  left: (h / 24) * c.maxWidth - 10,
                  child: Text('${h.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant))),
            ]);
          }),
        ),
        const SizedBox(height: 4),
        // Gantt rows
        for (final f in sorted) _ganttRow(f, theme),
      ]),
    );
  }

  Widget _ganttRow(FlightOrderItem f, ThemeData theme) {
    final dept = f.scheduledDeparture != null
        ? toLocalTime(f.scheduledDeparture!, tz)
        : DateTime.now();
    final statusColor = StatusColors.of(f.status);
    final label = f.aircraftRegistration?.isNotEmpty == true
        ? f.aircraftRegistration!
        : (f.aircraftModel?.isNotEmpty == true ? f.aircraftModel! : '?');
    final routeLabel = f.routes.isNotEmpty
        ? '${f.routes.first.originIcao}→${f.routes.first.destinationIcao}'
        : '--';
    final timeLabel = formatTimeWithOffset(f.scheduledDeparture, tz);
    final eteMinutes = f.eteMinutes ?? 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(builder: (ctx, c) {
        final barW = c.maxWidth - 72;
        final left = ((dept.hour + dept.minute / 60.0) / 24 * barW).clamp(0.0, barW - 4);
        final w = ((eteMinutes / (24.0 * 60.0)) * barW).clamp(4.0, barW - left);

        return SizedBox(
          height: 26,
          child: Row(children: [
            SizedBox(
              width: 72,
              child: Row(children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                Text(timeLabel, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
            Expanded(
              child: Stack(children: [
                for (int h = 6; h < 24; h += 6)
                  Positioned(
                    left: (h / 24) * barW,
                    top: 0, bottom: 0,
                    child: Container(width: 0.5, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                  ),
                Positioned(
                  left: left, top: 3, bottom: 3, width: w,
                  child: Tooltip(
                    message: '$label — $routeLabel — $eteMinutes min',
                    child: Container(
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                        border: Border(left: BorderSide(color: statusColor, width: 2)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Center(child: child));
}
