import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_state_confirm_dialog.dart';
import 'package:cg6_flights/features/flights/presentation/flight_detail_panel.dart';
import 'package:cg6_flights/features/flights/presentation/flight_led_board.dart';
import 'package:cg6_flights/features/flights/presentation/metar_widget.dart';
import 'package:cg6_flights/features/routes/data/routes_repository.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _flightsProvider =
    FutureProvider.family<AppResult<List<FlightOrderItem>>, DateTime>((
      ref,
      date,
    ) {
      final repo = ref.read(flightOrdersRepositoryProvider);
      return repo.listFlightsByDate(date: date);
    });

final _routeIcaosProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.read(routesRepositoryProvider);
  final result = await repo.listRoutes();
  final icaos = <String>{};
  if (result case AppSuccess(data: final routes)) {
    for (final r in routes) {
      if (r.icaoCode != null && r.icaoCode!.isNotEmpty) {
        icaos.add(r.icaoCode!.toUpperCase());
      }
    }
  }
  return icaos;
});

class FlightsPage extends ConsumerStatefulWidget {
  const FlightsPage({super.key});

  @override
  ConsumerState<FlightsPage> createState() => _FlightsPageState();
}

class _FlightsPageState extends ConsumerState<FlightsPage> {
  late DateTime _selectedDate;
  FlightOrderItem? _selectedItem;
  String? _selectedUnitId;
  List<UnitOption> _units = [];
  bool _mobileDetailOpen = false;

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadUnits();
    _autoRefresh = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => ref.invalidate(_flightsProvider(_selectedDate)));
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
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

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String _dateLabel(DateTime d) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _advanceState(FlightOrderItem item) async {
    final next = _nextState[item.status];
    if (next == null) return;

    // Confirmation dialog
    final tailNumber = item.aircraftRegistration ?? item.aircraftId;
    final confirmed = await showFlightStateConfirm(
      context: context,
      tailNumber: tailNumber,
      currentState: item.status,
      nextState: next,
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .advanceItemState(item.id, next);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<void>():
        ref.invalidate(_flightsProvider(_selectedDate));
        // Reload items to get fresh stateEvents
        final reloaded = await ref
            .read(flightOrdersRepositoryProvider)
            .listItems(item.flightOrderId);
        if (!mounted) return;
        switch (reloaded) {
          case AppSuccess<List<FlightOrderItem>>(data: final items):
            final updated = items.where((i) => i.id == item.id).firstOrNull;
            if (updated != null) setState(() => _selectedItem = updated);
          case AppFailure<List<FlightOrderItem>>():
            setState(() => _selectedItem = item.copyWith(status: next));
        }
      case AppFailure<void>(error: final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _lastEventTime(FlightOrderItem item, int tzOffset) {
    if (item.stateEvents.isEmpty) {
      return formatTimeWithOffset(item.scheduledDeparture, tzOffset);
    }
    final sorted = [...item.stateEvents]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return formatTimeWithOffset(sorted.last.occurredAt, tzOffset);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flightsAsync = ref.watch(_flightsProvider(_selectedDate));
    final tz = ref.watch(timezoneProvider);
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: title + date navigator ──────────────────────
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flight_takeoff,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.t('nav.flights'),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: t('flights.refresh'),
                      onPressed: () =>
                          ref.invalidate(_flightsProvider(_selectedDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _unitFilterButton(theme),
                    _ledBoardButton(l10n),
                    _dateNav(theme),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.flight_takeoff,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.t('nav.flights'),
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                _unitFilterButton(theme),
                const SizedBox(width: 8),
                _ledBoardButton(l10n),
                const SizedBox(width: 12),
                _dateNav(theme),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: t('flights.refresh'),
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
                final board = _buildBoard(
                  flightsAsync,
                  l10n,
                  theme,
                  tz,
                  useDesktopSelection: wide,
                );
                if (!wide) {
                  return board;
                }

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
                                onChanged: () => ref.invalidate(
                                  _flightsProvider(_selectedDate),
                                ),
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
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
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
            icon: Icon(
              Icons.chevron_right,
              size: 20,
              color: canGoForward ? null : Colors.grey.withValues(alpha: 0.3),
            ),
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
    int tz, {
    required bool useDesktopSelection,
  }) {
    return flightsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36),
            SizedBox(height: 8),
            Text('Error al cargar vuelos'),
            SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(_flightsProvider(_selectedDate)),
              child: Text(l10n.t('common.retry')),
            ),
          ],
        ),
      ),
      data: (result) {
        final flights = switch (result) {
          AppSuccess<List<FlightOrderItem>>(data: final list) => list,
          AppFailure<List<FlightOrderItem>>() => null,
        };

        if (flights == null) {
          return Center(child: Text((result as AppFailure).error.message));
        }

        // Desktop keeps a side detail panel. Mobile opens details only on tap.
        if (useDesktopSelection &&
            _selectedItem == null &&
            flights.isNotEmpty) {
          _selectedItem = flights.first;
        }

        // Filter by unit if selected
        var filtered = flights;
        if (_selectedUnitId != null) {
          filtered = flights.where((f) => f.unitId == _selectedUnitId).toList();
        }

        // Split flights: Departures (before landing) / Arrivals (landing+)
        final departures = filtered
            .where(
              (f) =>
                  f.status == 'waiting' ||
                  f.status == 'taxi' ||
                  f.status == 'takeoff' ||
                  f.cancelled,
            )
            .toList();
        final arrivals = filtered
            .where((f) => f.status == 'landing' || f.status == 'engine_off')
            .toList();

        if (flights.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flight,
                  size: 42,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _isToday
                      ? 'No hay vuelos programados para hoy'
                      : 'Sin vuelos para ${_dateLabel(_selectedDate)}',
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetarWidget(
                icaoCodes: {
                  ..._extractIcaos(flights),
                  ...(ref.watch(_routeIcaosProvider).value ?? const <String>{}),
                }.toList()..sort(),
              ),
              const SizedBox(height: 12),
              _sectionHeader('🛫 Departures', departures.length, theme),
              if (departures.isEmpty)
                _emptySection('Sin despegues programados', theme)
              else
                _flightTable(
                  departures,
                  l10n,
                  theme,
                  tz,
                  useDesktopSelection: useDesktopSelection,
                ),
              const SizedBox(height: 16),
              _sectionHeader('🛬 Arrivals', arrivals.length, theme),
              if (arrivals.isEmpty)
                _emptySection('Sin llegadas registradas', theme)
              else
                _flightTable(
                  arrivals,
                  l10n,
                  theme,
                  tz,
                  useDesktopSelection: useDesktopSelection,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCell(FlightOrderItem item) {
    final color = item.cancelled ? Colors.red : StatusColors.of(item.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: 6),
        StatusChip.fromStatus(item.cancelled ? 'cancelled' : item.status),
      ],
    );
  }

  Widget _unitFilterButton(ThemeData theme) {
    final selectedUnitName = _selectedUnitId != null
        ? (_units.where((u) => u.id == _selectedUnitId).firstOrNull?.name ??
              'Unidades')
        : 'Unidades';
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) => setState(() => _selectedUnitId = v.isEmpty ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: '',
          child: Text(
            'Unidades',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ..._units
            .where((u) => u.active)
            .map(
              (u) => PopupMenuItem<String>(
                value: u.id,
                child: Text(
                  u.name,
                  style: TextStyle(
                    fontWeight: _selectedUnitId == u.id
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                selectedUnitName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _ledBoardButton(AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FlightLedBoard())),
      icon: const Icon(Icons.monitor, size: 18),
      label: Text(l10n.t('flights.ledBoard')),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: const Color(0xFFFFD21A),
        side: const BorderSide(color: Color(0xFFFFD21A), width: 1),
      ),
    );
  }

  // ── Advance button ──────────────────────────────────────────────────

  Future<void> _showMobileDetail(
    BuildContext context,
    FlightOrderItem item,
    AppLocalizations l10n,
    int tz,
  ) async {
    if (_mobileDetailOpen) return;
    _mobileDetailOpen = true;
    final selected = item;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.t('common.close'),
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FlightDetailPanel(
                    key: ValueKey(selected.id),
                    item: selected,
                    onChanged: () =>
                        ref.invalidate(_flightsProvider(_selectedDate)),
                  ),
                  const SizedBox(height: 16),
                  _advanceButton(selected, l10n),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _mobileDetailOpen = false;
      _selectedItem = null;
    });
  }

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

  List<DataColumn> _columns(AppLocalizations l10n) => [
    DataColumn(label: Text(l10n.t('flightOrders.time'))),
    DataColumn(label: Text(l10n.t('flightOrders.orderNumber'))),
    DataColumn(label: Text(l10n.t('flightOrders.aircraft'))),
    DataColumn(label: const Text('Misión')),
    DataColumn(label: Text(l10n.t('flightOrders.status'))),
    DataColumn(label: const Text('ETE')),
  ];

  List<String> _extractIcaos(List<FlightOrderItem> flights) {
    final icaos = <String>{};
    for (final f in flights) {
      for (final r in f.routes) {
        if (r.originIcao != null && r.originIcao!.isNotEmpty) {
          icaos.add(r.originIcao!.toUpperCase());
        }
        if (r.destinationIcao != null && r.destinationIcao!.isNotEmpty) {
          icaos.add(r.destinationIcao!.toUpperCase());
        }
      }
    }
    return icaos.toList()..sort();
  }

  Widget _sectionHeader(String title, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String message, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _flightTable(
    List<FlightOrderItem> flights,
    AppLocalizations l10n,
    ThemeData theme,
    int tz, {
    required bool useDesktopSelection,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
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
            columns: _columns(l10n),
            rows: _buildFlightRows(flights, l10n, theme, tz, useDesktopSelection),
          ),
        ),
      ),
    );
  }

  List<DataRow> _buildFlightRows(
    List<FlightOrderItem> flights,
    AppLocalizations l10n,
    ThemeData theme,
    int tz,
    bool useDesktopSelection,
  ) {
    final hasShifts = flights.any((f) => f.shift != null && f.shift!.isNotEmpty);
    if (!hasShifts) {
      return flights.map((f) => _flightDataRow(f, theme, tz, useDesktopSelection)).toList();
    }
    final shiftOrder = ['I', 'II', 'III', 'IV'];
    final byShift = <String, List<FlightOrderItem>>{};
    for (final f in flights) {
      byShift.putIfAbsent(f.shift ?? '', () => []).add(f);
    }
    final rows = <DataRow>[];
    final sorted = byShift.keys.toList()..sort((a, b) => shiftOrder.indexOf(a).compareTo(shiftOrder.indexOf(b)));
    for (final s in sorted) {
      rows.add(DataRow(
        color: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
        cells: [DataCell(SizedBox(width: 700, child: Text('TURNO $s', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.colorScheme.primary))))],
      ));
      for (final f in byShift[s]!) {
        rows.add(_flightDataRow(f, theme, tz, useDesktopSelection));
      }
    }
    return rows;
  }

  DataRow _flightDataRow(FlightOrderItem f, ThemeData theme, int tz, bool useDesktopSelection) {
    return DataRow(
      selected: useDesktopSelection && _selectedItem?.id == f.id,
      onSelectChanged: (_) {
        if (useDesktopSelection) { setState(() => _selectedItem = f); } else { _showMobileDetail(context, f, AppLocalizations.of(context), tz); }
      },
      color: useDesktopSelection && _selectedItem?.id == f.id ? WidgetStateProperty.all(theme.colorScheme.primary.withValues(alpha: 0.08)) : null,
      cells: [
        DataCell(Text(_lastEventTime(f, tz), style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface))),
        DataCell(Text(f.orderNumber ?? '--', style: const TextStyle(fontSize: 12))),
        DataCell(Text(f.aircraftRegistration ?? '--', style: const TextStyle(fontSize: 12))),
        DataCell(SizedBox(width: 140, child: Text(f.mission ?? '--', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
        DataCell(_statusCell(f)),
        DataCell(Text(f.eteMinutes != null ? '${f.eteMinutes}m' : '--', style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
