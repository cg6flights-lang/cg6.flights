import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final isCancelled = item.cancelled;
    final theme = Theme.of(context);

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
            // Header
            Row(
              children: [
                Icon(Icons.flight, size: 22, color: StatusColors.of(item.status)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aircraftLabel(l10n),
                        style: theme.textTheme.titleMedium,
                      ),
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
                StatusChip.fromStatus(isCancelled ? 'cancelled' : item.status),
              ],
            ),
            const SizedBox(height: 16),

            // Mission
            if (item.mission != null && item.mission!.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.mission')),
              Text(item.mission!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],

            // Flight data chips
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
                    '${l10n.t("flightOrders.departure")}: ${_fmt(item.scheduledDeparture!)}'),
            ]),
            const SizedBox(height: 12),

            // Crew
            if (item.crew.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.crew')),
              ...item.crew.map((c) => _row(
                    '${c.roleCode}: ${c.crewMemberName ?? "--"}${c.functionCode != null ? " [${c.functionCode}]" : ""}',
                  )),
              const SizedBox(height: 12),
            ],

            // Routes
            if (item.routes.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.routes')),
              ...item.routes.map((r) => _row(
                    '${r.segmentType == "return" ? "↩" : "↪"} ${r.displayLabel}',
                  )),
              const SizedBox(height: 12),
            ],

            // Mini Stepper
            _sectionLabel(context, l10n.t('flightOrders.status')),
            const SizedBox(height: 8),
            _miniStepper(item),
            const SizedBox(height: 16),

            // Timeline
            if (item.stateEvents.isNotEmpty) ...[
              _sectionLabel(context, l10n.t('flightOrders.stateEvents')),
              const SizedBox(height: 6),
              ...item.stateEvents.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      StatusChip.fromStatus(e.status, size: StatusChipSize.small),
                      const SizedBox(width: 8),
                      Text(_fmt(e.occurredAt), style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                    ]),
                  )),
              if (_evtTime('taxi') != null && _evtTime('engine_off') != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  _timeChip(l10n.t('flightOrders.totalTime'),
                      _duration('taxi', 'engine_off'), theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  _timeChip(l10n.t('flightOrders.airTime'),
                      _duration('takeoff', 'landing'), theme.colorScheme.tertiary),
                ]),
              ],
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

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';

  DateTime? _evtTime(String status) => item.stateEvents
      .where((e) => e.status == status)
      .map((e) => e.occurredAt)
      .firstOrNull;

  String _duration(String from, String to) {
    final s = _evtTime(from);
    final e = _evtTime(to);
    if (s == null || e == null) return '--';
    final d = e.difference(s);
    return d.inHours > 0 ? '${d.inHours}h ${d.inMinutes.remainder(60)}m' : '${d.inMinutes}m';
  }

  // ── Mini Stepper ───────────────────────────────────────────────────

  Widget _miniStepper(FlightOrderItem item) {
    final idx = _states.indexOf(item.status);
    final cancelled = item.cancelled;
    return Row(children: [
      for (int i = 0; i < _states.length; i++) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: i <= idx && !cancelled
                  ? _stepperColor(_states[i])
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        _dot(_states[i], i < idx, i == idx, item),
      ],
    ]);
  }

  Color _stepperColor(String s) => StatusColors.of(s);

  Widget _dot(String s, bool done, bool active, FlightOrderItem item) {
    final color = item.cancelled ? Colors.red : _stepperColor(s);
    final hasEvt = item.stateEvents.any((e) => e.status == s);
    return Tooltip(
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

  // ── State i18n ─────────────────────────────────────────────────────

}
