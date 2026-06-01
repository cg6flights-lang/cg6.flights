import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class FlightDetailPanel extends ConsumerWidget {
  const FlightDetailPanel({
    super.key,
    required this.item,
    required this.onChanged,
  });

  final FlightOrderItem item;
  final VoidCallback onChanged;

  static const _states = ['waiting', 'taxi', 'takeoff', 'landing', 'engine_off'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tz = ref.watch(timezoneProvider);
    final isCancelled = item.cancelled;
    final theme = Theme.of(context);
    final hasCoords = item.routes.any(
      (r) => r.originLat != null && r.destinationLat != null,
    );

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.flight, size: 22,
                    color: StatusColors.of(item.status)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_aircraftLabel(l10n),
                          style: theme.textTheme.titleMedium),
                      if (item.orderNumber != null)
                        Text(
                          '${item.orderNumber} — ${item.unitName ?? "--"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusChip.fromStatus(
                    isCancelled ? 'cancelled' : item.status),
              ],
            ),
            const SizedBox(height: 16),

            // ── Mission ─────────────────────────────────────────
            if (item.mission != null && item.mission!.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.mission')),
              Text(item.mission!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],

            // ── Flight data chips ───────────────────────────────
            _sectionLabel(context, l10n.t('flightOrders.flightData')),
            Wrap(spacing: 16, runSpacing: 6, children: [
              if (item.eteMinutes != null)
                _chip(Icons.timer_outlined, 'ETE: ${item.eteMinutes} min'),
              if (item.flightLevelMin != null)
                _chip(Icons.height, item.flightLevelDisplay),
              if (item.fuelAmount != null)
                _chip(Icons.local_gas_station_outlined,
                    '${item.fuelAmount} lbs${item.fuelType != null ? " (${item.fuelType})" : ""}'),
              if (item.scheduledDeparture != null)
                _chip(Icons.schedule_outlined,
                    '${l10n.t("flightOrders.departure")}: ${_fmt(item.scheduledDeparture!, tz)}'),
            ]),
            const SizedBox(height: 12),

            // ── Crew ────────────────────────────────────────────
            if (item.crew.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.crew')),
              ...item.crew.map((c) => _row(
                    '${c.roleCode}: ${c.crewMemberName ?? "--"}${c.functionCode != null ? " [${c.functionCode}]" : ""}',
                  )),
              const SizedBox(height: 12),
            ],

            // ── Routes ──────────────────────────────────────────
            if (item.routes.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.routes')),
              ...item.routes.map((r) => _row(
                    '${r.segmentType == "return" ? "↩" : "↪"} ${r.displayLabel}',
                  )),
              const SizedBox(height: 12),
            ],

            // ── Stepper with times ──────────────────────────────
            _sectionLabel(context, l10n.t('flightOrders.status')),
            const SizedBox(height: 8),
            _stepperWithTimes(item, tz),
            const SizedBox(height: 12),

            // ── Time chips (centered) ───────────────────────────
            if (_evtTime('taxi') != null && _evtTime('engine_off') != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeChip(l10n.t('flightOrders.totalTime'),
                      _duration('taxi', 'engine_off'), theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  _timeChip(l10n.t('flightOrders.airTime'),
                      _duration('takeoff', 'landing'), theme.colorScheme.tertiary),
                ],
              ),

            // ── Mini route map ──────────────────────────────────
            if (hasCoords) ...[
              const SizedBox(height: 12),
              _miniMap(theme),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _aircraftLabel(AppLocalizations l10n) {
    final reg = item.aircraftRegistration ?? l10n.t('flightOrders.aircraft');
    final model = item.aircraftModel;
    return model != null && model.isNotEmpty ? '$reg — $model' : reg;
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _row(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _timeChip(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  String _fmt(DateTime utc, int tzOffset) =>
      formatTimeWithOffset(utc, tzOffset);

  DateTime? _evtTime(String status) => item.stateEvents
      .where((e) => e.status == status)
      .map((e) => e.occurredAt)
      .firstOrNull;

  String _duration(String from, String to) {
    final s = _evtTime(from);
    final e = _evtTime(to);
    if (s == null || e == null) return '--';
    final d = e.difference(s);
    return d.inHours > 0
        ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
        : '${d.inMinutes}m';
  }

  // ── Stepper with times under each dot ──────────────────────────────

  Widget _stepperWithTimes(FlightOrderItem item, int tz) {
    final idx = _states.indexOf(item.status);
    final cancelled = item.cancelled;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _states.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 7),
                color: i <= idx && !cancelled
                    ? StatusColors.of(_states[i])
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
          _stepperColumn(_states[i], i < idx, i == idx, item, tz),
        ],
      ],
    );
  }

  Widget _stepperColumn(
      String s, bool done, bool active, FlightOrderItem item, int tz) {
    final color = item.cancelled ? Colors.red : StatusColors.of(s);
    final event = item.stateEvents.where((e) => e.status == s).firstOrNull;
    final hasEvt = event != null;

    return SizedBox(
      width: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot
          Tooltip(
            message: _stepperLabel(s),
            child: Container(
              width: active ? 16 : 12,
              height: active ? 16 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || hasEvt
                    ? color
                    : active
                        ? color.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.08),
                border: Border.all(
                  color: active || done || hasEvt
                      ? color
                      : Colors.grey.withValues(alpha: 0.3),
                  width: active ? 2 : 1,
                ),
              ),
              child: done || hasEvt
                  ? const Icon(Icons.check, size: 8, color: Colors.white)
                  : active
                      ? Icon(Icons.circle, size: 6, color: color)
                      : null,
            ),
          ),
          const SizedBox(height: 4),
          // Time (if event exists)
          if (event != null && !item.cancelled)
            Text(
              _fmt(event.occurredAt, tz),
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  String _stepperLabel(String s) => switch (s) {
        'waiting' => 'Espera',
        'taxi' => 'Taxeo',
        'takeoff' => 'Despegue',
        'landing' => 'Aterrizaje',
        'engine_off' => 'Motor Apagado',
        _ => s,
      };

  Widget _airportMarker({
    required String? icao,
    required String? fallback,
    required Color color,
  }) {
    final code = (icao != null && icao.isNotEmpty)
        ? icao
        : (fallback ?? '--');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            code.toUpperCase().length > 6
                ? code.toUpperCase().substring(0, 6)
                : code.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── Mini route map ─────────────────────────────────────────────────

  Widget _miniMap(ThemeData theme) {
    // Collect all route points with coordinates
    final points = <LatLng>[];
    for (final r in item.routes) {
      if (r.originLat != null && r.originLng != null) {
        points.add(LatLng(r.originLat!, r.originLng!));
      }
      if (r.destinationLat != null && r.destinationLng != null) {
        points.add(LatLng(r.destinationLat!, r.destinationLng!));
      }
    }
    if (points.length < 2) return const SizedBox.shrink();

    // Calculate bounds with padding
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Build polyline segments
    final polylines = <Polyline>[];
    for (int i = 0; i < points.length - 1; i += 2) {
      if (i + 1 < points.length) {
        polylines.add(Polyline(
          points: [points[i], points[i + 1]],
          color: StatusColors.of(item.status),
          strokeWidth: 3,
        ));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 340,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 6.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'cg6_flights',
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: [
              for (final r in item.routes)
                if (r.originLat != null && r.originLng != null)
                  Marker(
                    point: LatLng(r.originLat!, r.originLng!),
                    width: 70,
                    height: 44,
                    child: _airportMarker(
                      icao: r.originIcao,
                      fallback: r.originLabel ?? r.originRouteName,
                      color: Colors.red,
                    ),
                  ),
              for (final r in item.routes)
                if (r.destinationLat != null && r.destinationLng != null)
                  Marker(
                    point: LatLng(r.destinationLat!, r.destinationLng!),
                    width: 70,
                    height: 44,
                    child: _airportMarker(
                      icao: r.destinationIcao,
                      fallback: r.destinationLabel ?? r.destinationRouteName,
                      color: Colors.blue,
                    ),
                  ),
            ]),
            // Zoom buttons
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomButton(
                        icon: Icons.add, onTap: () {}), // handled via map controller
                    const SizedBox(height: 4),
                    _ZoomButton(
                        icon: Icons.remove, onTap: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
