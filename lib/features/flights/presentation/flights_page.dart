import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flights/presentation/flight_detail_panel.dart';
import 'package:cg6_flights/features/flights/presentation/flight_led_board.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _flightsProvider =
    FutureProvider.family<AppResult<List<FlightOrderItem>>, DateTime>(
  (ref, date) {
    final repo = ref.read(flightOrdersRepositoryProvider);
    return repo.listFlightsByDate(date: date);
  },
);

class FlightsPage extends ConsumerStatefulWidget {
  const FlightsPage({super.key});

  @override
  ConsumerState<FlightsPage> createState() => _FlightsPageState();
}

class _FlightsPageState extends ConsumerState<FlightsPage> {
  DateTime _selectedDate = DateTime.now();
  FlightOrderItem? _selectedItem;
  List<UnitOption> _units = [];

  static const _nextState = {
    'waiting': 'taxi',
    'taxi': 'takeoff',
    'takeoff': 'landing',
    'landing': 'engine_off',
  };
  static const _stateIcons = {
    'taxi': Icons.directions_car,
    'takeoff': Icons.flight_takeoff,
    'landing': Icons.flight_land,
    'engine_off': Icons.power_settings_new,
  };

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final result = await ref.read(unitsRepositoryProvider).listUnits();
    if (!mounted) return;
    switch (result) {
      case AppSuccess<List<UnitOption>>(data: final units):
        setState(() => _units = units);
      case AppFailure<List<UnitOption>>():
        setState(() => _units = []);
    }
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _selectedItem = null;
    });
  }

  bool get _isToday => _selectedDate == _today;

  String _dateLabel(DateTime d) {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _advanceState(FlightOrderItem item) async {
    final next = _nextState[item.status];
    if (next == null) return;
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .advanceItemState(item.id, next);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_flightsProvider(_selectedDate));
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _selectedItem = item.copyWith(status: next));
        });
      case AppFailure<void>(error: final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _lastEventTime(FlightOrderItem item) {
    if (item.stateEvents.isEmpty) return item.scheduledDeparture != null
        ? '${item.scheduledDeparture!.hour.toString().padLeft(2, "0")}:${item.scheduledDeparture!.minute.toString().padLeft(2, "0")}'
        : '--';
    final sorted = [...item.stateEvents]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final last = sorted.last;
    return '${last.occurredAt.hour.toString().padLeft(2, "0")}:${last.occurredAt.minute.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flightsAsync = ref.watch(_flightsProvider(_selectedDate));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: title + date navigator ──────────────────────
          Row(
            children: [
              Icon(Icons.flight_takeoff, size: 24,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(l10n.t('nav.flights'), style: theme.textTheme.headlineSmall),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FlightLedBoard()),
                ),
                icon: const Icon(Icons.monitor, size: 18),
                label: const Text('Pantalla LED'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF39FF14),
                  side: const BorderSide(color: Color(0xFF39FF14), width: 1),
                ),
              ),
              const SizedBox(width: 12),
              _dateNav(theme),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refrescar',
                onPressed: () =>
                    ref.invalidate(_flightsProvider(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Board ───────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1100;
                final board = _buildBoard(flightsAsync, l10n, theme);
                if (!wide) return board;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: board),
                    if (_selectedItem != null) ...[
                      const VerticalDivider(width: 24, thickness: 1),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Expanded(
                              child: FlightDetailPanel(
                                key: ValueKey(_selectedItem!.id),
                                item: _selectedItem!,
                                onChanged: () =>
                                    ref.invalidate(_flightsProvider(_selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _advanceButton(_selectedItem!, l10n),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateNav(ThemeData theme) {
    final canGoForward = _selectedDate.isBefore(_today);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () => _changeDate(-1),
          ),
          SizedBox(
            width: 130,
            child: Text(
              _dateLabel(_selectedDate),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1,
                color: _isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                size: 20,
                color: canGoForward
                    ? null
                    : Colors.grey.withValues(alpha: 0.3)),
            visualDensity: VisualDensity.compact,
            onPressed: canGoForward ? () => _changeDate(1) : null,
          ),
        ],
      ),
    );
  }

  // ── Board table ────────────────────────────────────────────────────

  Widget _buildBoard(
    AsyncValue<AppResult<List<FlightOrderItem>>> flightsAsync,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return flightsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 36),
          const SizedBox(height: 8),
          const Text('Error al cargar vuelos'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                ref.invalidate(_flightsProvider(_selectedDate)),
            child: Text(l10n.t('common.retry')),
          ),
        ]),
      ),
      data: (result) {
        final flights = switch (result) {
          AppSuccess<List<FlightOrderItem>>(data: final list) => list,
          AppFailure<List<FlightOrderItem>>() => null,
        };

        if (flights == null) {
          return Center(
              child: Text((result as AppFailure).error.message));
        }

        if (flights.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.flight, size: 42,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(_isToday
                  ? 'No hay vuelos programados para hoy'
                  : 'Sin vuelos para ${_dateLabel(_selectedDate)}'),
            ]),
          );
        }

        return Card(
          elevation: 1,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  headingTextStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  headingRowHeight: 36,
                  horizontalMargin: 12,
                  columnSpacing: 16,
                  columns: [
                    DataColumn(label: Text(l10n.t('flightOrders.time'))),
                    DataColumn(
                        label: Text(l10n.t('flightOrders.orderNumber'))),
                    DataColumn(
                        label: Text(l10n.t('flightOrders.aircraft'))),
                    DataColumn(label: const Text('Misión')),
                    DataColumn(
                        label: Text(l10n.t('flightOrders.status'))),
                    DataColumn(label: const Text('ETE')),
                  ],
                  rows: [
                    for (final f in flights)
                      DataRow(
                        selected: _selectedItem?.id == f.id,
                        onSelectChanged: (_) =>
                            setState(() => _selectedItem = f),
                        color: _selectedItem?.id == f.id
                            ? WidgetStateProperty.all(theme
                                .colorScheme.primary
                                .withValues(alpha: 0.08))
                            : null,
                        cells: [
                          DataCell(Text(_lastEventTime(f),
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ))),
                          DataCell(Text(f.orderNumber ?? '--',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(
                            f.aircraftRegistration ?? '--',
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(SizedBox(
                            width: 140,
                            child: Text(
                              f.mission ?? '--',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(_statusCell(f)),
                          DataCell(Text(
                            f.eteMinutes != null
                                ? '${f.eteMinutes}m'
                                : '--',
                            style: const TextStyle(fontSize: 12),
                          )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusCell(FlightOrderItem item) {
    final color = item.cancelled ? Colors.red : StatusColors.of(item.status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 6),
      StatusChip.fromStatus(item.cancelled ? 'cancelled' : item.status),
    ]);
  }

  // ── Advance button ──────────────────────────────────────────────────

  Widget _advanceButton(FlightOrderItem item, AppLocalizations l10n) {
    final next = _nextState[item.status];
    if (item.cancelled || next == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _advanceState(item),
        icon: Icon(_stateIcons[next] ?? Icons.arrow_forward, size: 18),
        label: Text(_stateLabel(next, l10n)),
      ),
    );
  }

  String _stateLabel(String state, AppLocalizations l10n) => switch (state) {
        'taxi' => l10n.t('flightOrders.taxi'),
        'takeoff' => l10n.t('flightOrders.takeoff'),
        'landing' => l10n.t('flightOrders.landing'),
        'engine_off' => l10n.t('flightOrders.engineOff'),
        _ => state,
      };
}
