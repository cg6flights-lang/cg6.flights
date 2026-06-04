import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _statusOrder = ['waiting', 'taxi', 'takeoff', 'landing', 'engine_off'];

class UpcomingFlightsWidget extends ConsumerWidget {
  const UpcomingFlightsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);
    final tz = ref.watch(timezoneProvider);

    final child = flightsAsync.when(
      loading: () => const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (f) => _UpcomingContent(
        flights: switch (f) { AppSuccess(data: final d) => d, _ => [] },
        tz: tz,
      ),
    );

    return DashboardWidgetWrapper(config: DashboardWidgetConfig.byId('upcoming')!, child: child);
  }
}

class _UpcomingContent extends StatelessWidget {
  const _UpcomingContent({required this.flights, required this.tz});
  final List<FlightOrderItem> flights;
  final int tz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...flights]
      ..sort((a, b) => (a.scheduledDeparture ?? DateTime.now()).compareTo(b.scheduledDeparture ?? DateTime.now()));
    final upcoming = sorted.take(6).toList();

    if (upcoming.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Sin vuelos programados', style: TextStyle(fontSize: 12))),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...upcoming.map((f) => _FlightRow(flight: f, theme: theme, tz: tz)),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () => context.go('/flights'), borderRadius: BorderRadius.circular(4),
            child: Padding(padding: const EdgeInsets.all(2),
              child: Text('Ver todos →', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600))),
          ),
        ),
      ]),
    );
  }
}

class _FlightRow extends StatelessWidget {
  const _FlightRow({required this.flight, required this.theme, required this.tz});
  final FlightOrderItem flight;
  final ThemeData theme;
  final int tz;

  @override
  Widget build(BuildContext context) {
    final route = flight.routes.isNotEmpty
        ? '${flight.routes.first.originIcao}→${flight.routes.first.destinationIcao}'
        : '--';
    final time = flight.scheduledDeparture != null
        ? formatTimeWithOffset(flight.scheduledDeparture!, tz).replaceAll(':', '')
        : '--';
    final statusColor = StatusColors.of(flight.status);
    final currentStep = _statusOrder.indexOf(flight.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 32, child: Text(time, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(width: 4),
        Expanded(child: Text(route, style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Row(mainAxisSize: MainAxisSize.min,
          children: List.generate(_statusOrder.length, (i) {
            final dotColor = i <= currentStep && currentStep >= 0 ? statusColor : Colors.grey.shade300;
            return Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor));
          }),
        ),
      ]),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Center(child: child));
}
