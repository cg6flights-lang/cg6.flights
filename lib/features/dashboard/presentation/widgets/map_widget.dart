import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/routes/data/airports_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends ConsumerWidget {
  const MapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);

    final child = flightsAsync.when(
      loading: () => const _Centered(height: 220, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const _Centered(height: 220, child: Icon(Icons.error_outline, size: 20)),
      data: (f) => _MapContent(
        flights: switch (f) { AppSuccess(data: final d) => d, _ => [] },
      ),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('map')!,
      child: child,
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({required this.flights});
  final List<FlightOrderItem> flights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routes = <({LatLng from, LatLng to, String label})>[];
    for (final f in flights) {
      for (final r in f.routes) {
        final origin = _findAirport(r.originIcao);
        final dest = _findAirport(r.destinationIcao);
        if (origin != null && dest != null) {
          routes.add((from: origin, to: dest, label: '${r.originIcao}→${r.destinationIcao}'));
        }
      }
    }

    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: routes.isNotEmpty ? routes.first.from : const LatLng(-12.0464, -77.0428),
          initialZoom: routes.isNotEmpty ? 5 : 6,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'cg6_flights'),
          MarkerLayer(markers: [
            for (final ap in _relevantAirports(routes))
              Marker(
                point: ap.$2, width: 40, height: 40,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ap.$1 == 'SPJC' ? Icons.home : Icons.location_on, color: ap.$1 == 'SPJC' ? theme.colorScheme.primary : Colors.blue, size: 18),
                  Text(ap.$1, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.black, backgroundColor: Colors.white70)),
                ]),
              ),
          ]),
          PolylineLayer(polylines: [
            for (final r in routes)
              Polyline(points: [r.from, r.to], color: theme.colorScheme.primary.withValues(alpha: 0.5), strokeWidth: 2.5),
          ]),
        ],
      ),
    );
  }

  LatLng? _findAirport(String? icao) {
    if (icao == null) return null;
    for (final ap in kAirports) {
      if (ap.icao == icao.toUpperCase()) return LatLng(ap.lat, ap.lng);
    }
    return null;
  }

  List<(String, LatLng)> _relevantAirports(List<({LatLng from, LatLng to, String label})> routes) {
    final seen = <String>{};
    final result = <(String, LatLng)>[];
    for (final r in routes) {
      for (final ap in kAirports) {
        final pt = LatLng(ap.lat, ap.lng);
        if ((pt == r.from || pt == r.to) && !seen.contains(ap.icao)) {
          seen.add(ap.icao);
          result.add((ap.icao, pt));
        }
      }
    }
    if (!seen.contains('SPJC')) {
      final lpa = kAirports.firstWhere((a) => a.icao == 'SPJC', orElse: () => kAirports.first);
      result.add((lpa.icao, LatLng(lpa.lat, lpa.lng)));
    }
    return result;
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(height: height, child: Center(child: child));
}
