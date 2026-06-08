import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aircraft_form_dialog.dart';

const _defaultAircraftUnitId = '5334d249-674b-4b4e-8070-aba471a81394';

final _aircraftListProvider = FutureProvider<AppResult<List<Aircraft>>>((
  ref,
) async {
  final repo = ref.read(aircraftRepositoryProvider);
  return repo.listAircraft();
});

final _unitsProvider = FutureProvider<List<UnitOption>>((ref) async {
  final result = await ref.read(unitsRepositoryProvider).listUnits();
  return switch (result) {
    AppSuccess<List<UnitOption>>(data: final list) =>
      list.where((u) => u.active).toList(),
    _ => <UnitOption>[],
  };
});

class _CurveParams {
  const _CurveParams({required this.unitId, required this.granularity});
  final String unitId;
  final String granularity;

  @override
  bool operator ==(Object other) =>
      other is _CurveParams &&
      other.unitId == unitId &&
      other.granularity == granularity;

  @override
  int get hashCode => Object.hash(unitId, granularity);
}

final _selectedUnitProvider = NotifierProvider<_UnitNotifier, String?>(
  _UnitNotifier.new,
);

class _UnitNotifier extends Notifier<String?> {
  @override
  String? build() => _defaultAircraftUnitId;
  void select(String? id) => state = (state == id ? null : id);
}

class _AircraftOrdersParams {
  const _AircraftOrdersParams({
    required this.aircraftId,
    required this.from,
    required this.to,
  });

  final String aircraftId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is _AircraftOrdersParams &&
      other.aircraftId == aircraftId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(aircraftId, from, to);
}

final _aircraftOrdersProvider =
    FutureProvider.family<
      AppResult<List<FlightOrderItem>>,
      _AircraftOrdersParams
    >((ref, params) {
      return ref
          .read(flightOrdersRepositoryProvider)
          .listItemsByAircraft(
            aircraftId: params.aircraftId,
            from: params.from,
            to: params.to,
          );
    });

final _flightHoursProvider =
    FutureProvider.family<AppResult<List<AircraftFlightHours>>, String?>(
      (ref, unitId) =>
          ref.read(aircraftRepositoryProvider).getFlightHours(unitId: unitId),
    );

final _operationalCurveProvider =
    FutureProvider.family<AppResult<List<OperationalDataPoint>>, _CurveParams>((
      ref,
      params,
    ) async {
      final repo = ref.read(aircraftRepositoryProvider);
      return repo.getOperationalCurve(
        unitId: params.unitId,
        granularity: params.granularity,
      );
    });

class AircraftPage extends ConsumerWidget {
  const AircraftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final aircraftAsync = ref.watch(_aircraftListProvider);
    final unitsAsync = ref.watch(_unitsProvider);
    final canManage = session.can(AppPermission.aircraftManage);

    return aircraftAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: l10n.t('aircraft.loadFailed'),
        message: l10n.t('common.retry'),
        onRetry: () => ref.invalidate(_aircraftListProvider),
      ),
      data: (result) {
        final aircraft = switch (result) {
          AppSuccess<List<Aircraft>>(data: final list) => list,
          AppFailure<List<Aircraft>>() => null,
        };

        if (aircraft == null) {
          final error = (result as AppFailure<List<Aircraft>>).error;
          return DataStateView(
            kind: _stateKindForError(error.category),
            title: l10n.t('aircraft.loadFailed'),
            message: error.message,
            onRetry: () => ref.invalidate(_aircraftListProvider),
          );
        }

        if (aircraft.isEmpty) {
          return _AircraftEmptyState(
            canManage: canManage,
            onAdd: () => _openForm(context, ref, session.user?.unitId),
          );
        }

        final units = unitsAsync.value ?? [];
        final selectedUnitId = ref.watch(_selectedUnitProvider);

        final unitAircraft = <String, List<Aircraft>>{};
        for (final a in aircraft) {
          unitAircraft.putIfAbsent(a.unitId, () => []).add(a);
        }
        final allUnits = units
            .where((u) => unitAircraft.containsKey(u.id))
            .toList();
        final effectiveSelectedUnitId =
            selectedUnitId != null &&
                allUnits.any((u) => u.id == selectedUnitId)
            ? selectedUnitId
            : null;
        final showUnits = effectiveSelectedUnitId != null
            ? allUnits.where((u) => u.id == effectiveSelectedUnitId).toList()
            : allUnits;
        final compact = MediaQuery.sizeOf(context).width < 620;

        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('nav.aircraft'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () =>
                        _openForm(context, ref, session.user?.unitId),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(l10n.t('aircraft.add')),
                  ),
              ],
            ),
            if (session.user?.role?.isGlobal == true &&
                allUnits.length > 1) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final u in allUnits)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            u.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: effectiveSelectedUnitId == u.id,
                          onSelected: (_) => ref
                              .read(_selectedUnitProvider.notifier)
                              .select(u.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final unit in showUnits)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _UnitAircraftSection(
                  unit: unit,
                  aircraft: unitAircraft[unit.id]!,
                  canManage: canManage,
                  onAdd: () => _openForm(context, ref, unit.id),
                  onEdit: (a) => _openForm(context, ref, null, aircraft: a),
                  onDeactivate: (a) => _confirmDeactivate(context, ref, a),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    String? defaultUnitId, {
    Aircraft? aircraft,
  }) async {
    final l10n = AppLocalizations.of(context);
    final unitsResult = await ref.read(unitsRepositoryProvider).listUnits();
    final List<UnitOption> activeUnits;
    switch (unitsResult) {
      case AppSuccess<List<UnitOption>>(data: final list):
        activeUnits = list.where((u) => u.active).toList();
      case AppFailure<List<UnitOption>>(error: final error):
        if (context.mounted) _showError(context, error.message);
        return;
    }

    if (activeUnits.isEmpty) {
      if (context.mounted) {
        _showError(context, l10n.t('aircraft.noActiveUnits'));
      }
      return;
    }

    if (!context.mounted) return;

    // Load squadrons
    final sqResult = await ref.read(squadronRepositoryProvider).listSquadrons();
    final squadrons = switch (sqResult) {
      AppSuccess<List<FlightSquadron>>(data: final list) => list,
      _ => <FlightSquadron>[],
    };

    final saved = await showDialog<AircraftFormResult>(
      context: context,
      builder: (_) => AircraftFormDialog(
        aircraft: aircraft,
        units: activeUnits,
        defaultUnitId: defaultUnitId,
        squadrons: squadrons,
      ),
    );

    if (saved != null && context.mounted) {
      final repo = ref.read(aircraftRepositoryProvider);
      final result = await repo.saveAircraft(
        aircraftId: aircraft?.id,
        unitId: saved.unitId,
        tailNumber: saved.tailNumber,
        model: saved.model,
        manufacturer: saved.manufacturer,
        serialNumber: saved.serialNumber,
        year: saved.year,
        status: saved.status,
        inoperativeReason: saved.inoperativeReason,
        obTailNumber: saved.obTailNumber,
        displayRegistration: saved.displayRegistration,
        squadronId: saved.squadronId,
      );
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_aircraftListProvider);
          ref.invalidate(_operationalCurveProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    Aircraft aircraft,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.t('aircraft.deactivate')),
        content: Text(
          '${l10n.t('aircraft.deactivateConfirm')} ${aircraft.displayTailNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('aircraft.deactivate')),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final result = await ref
          .read(aircraftRepositoryProvider)
          .deactivateAircraft(aircraft.id);
      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_aircraftListProvider);
          ref.invalidate(_operationalCurveProvider);
        case AppFailure<void>(error: final error):
          _showError(context, error.message);
      }
    }
  }

  DataStateKind _stateKindForError(AppErrorCategory category) {
    return switch (category) {
      AppErrorCategory.auth ||
      AppErrorCategory.authorization => DataStateKind.permissionDenied,
      AppErrorCategory.validation => DataStateKind.validationError,
      AppErrorCategory.businessRule => DataStateKind.businessError,
      AppErrorCategory.network => DataStateKind.networkError,
      _ => DataStateKind.systemError,
    };
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnitAircraftSection extends ConsumerStatefulWidget {
  const _UnitAircraftSection({
    required this.unit,
    required this.aircraft,
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDeactivate,
  });

  final UnitOption unit;
  final List<Aircraft> aircraft;
  final bool canManage;
  final VoidCallback onAdd;
  final void Function(Aircraft) onEdit;
  final void Function(Aircraft) onDeactivate;

  @override
  ConsumerState<_UnitAircraftSection> createState() =>
      _UnitAircraftSectionState();
}

class _UnitAircraftSectionState extends ConsumerState<_UnitAircraftSection> {
  String _modelFilter = '';
  String _granularity = 'month';

  List<Aircraft> get _filtered {
    if (_modelFilter.isEmpty) return widget.aircraft;
    return widget.aircraft.where((a) => a.model == _modelFilter).toList();
  }

  List<Aircraft> get _operativas =>
      _filtered.where((a) => a.status == 'operational').toList();

  List<Aircraft> get _inoperativas =>
      _filtered.where((a) => a.status != 'operational').toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final modelOptions = widget.aircraft.map((a) => a.model).toSet().toList()
      ..sort();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.flight, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.unit.code} — ${widget.unit.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_filtered.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.canManage) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: l10n.t('aircraft.add'),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onAdd,
                  ),
                ],
              ],
            ),
            if (modelOptions.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  initialValue: '',
                  decoration: InputDecoration(
                    labelText: l10n.t('aircraft.modelFilter'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        l10n.t('aircraft.all'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    for (final m in modelOptions)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _modelFilter = v ?? ''),
                ),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return SizedBox(
                    height: 550,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Card(
                            elevation: 1,
                            margin: EdgeInsets.zero,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: _buildLeftColumn(l10n),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 32, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: _buildRightColumn(l10n),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        child: _buildLeftColumn(l10n),
                      ),
                    ),
                    const Divider(height: 32, thickness: 1),
                    _buildRightColumn(l10n),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn(AppLocalizations l10n) {
    final byModel = <String, List<Aircraft>>{};
    for (final a in _filtered) {
      byModel.putIfAbsent(a.model, () => []).add(a);
    }
    final models = byModel.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final model in models)
          _ModelCardGroup(
            model: model,
            aircraft: byModel[model]!,
            canManage: widget.canManage,
            onTap: (a) => _showAircraftDetail(
              context,
              a,
              canManage: widget.canManage,
              onEdit: widget.onEdit,
            ),
            onEdit: widget.onEdit,
          ),
      ],
    );
  }

  Widget _buildRightColumn(AppLocalizations l10n) {
    final curveAsync = ref.watch(
      _operationalCurveProvider(
        _CurveParams(unitId: widget.unit.id, granularity: _granularity),
      ),
    );
    final hoursAsync = ref.watch(_flightHoursProvider(widget.unit.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryPanel(l10n),
        const SizedBox(height: 12),
        _FlightHoursChart(hoursAsync: hoursAsync),
        const SizedBox(height: 16),
        _buildChartSection(l10n, curveAsync),
      ],
    );
  }

  Widget _buildSummaryPanel(AppLocalizations l10n) {
    final total = _filtered.length;
    final op = _operativas.length;
    final inop = _inoperativas.length;

    Widget statCard(
      String label,
      int count,
      int? pct,
      Color color, {
      VoidCallback? onTap,
    }) {
      final content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (pct != null)
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      );
      if (onTap == null) return content;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t('aircraft.summary'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: statCard(
                    l10n.t('aircraft.operational'),
                    op,
                    total > 0 ? (op * 100 ~/ total) : 0,
                    StatusColors.aircraft['operational']!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: statCard(
                    l10n.t('aircraft.inoperative'),
                    inop,
                    total > 0 ? (inop * 100 ~/ total) : 0,
                    StatusColors.aircraft['inoperative']!,
                    onTap: () => _showInoperativeAircraftModal(
                      context,
                      _inoperativas,
                      l10n,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('aircraft.totalSummary').replaceAll('{count}', '$total'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInoperativeAircraftModal(
    BuildContext context,
    List<Aircraft> aircraft,
    AppLocalizations l10n,
  ) {
    final sorted = [...aircraft]
      ..sort((a, b) => a.displayTailNumber.compareTo(b.displayTailNumber));
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('aircraft.inoperativeSummary')),
        content: SizedBox(
          width: 560,
          child: sorted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.t('aircraft.noInoperativeAircraft'),
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in sorted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InoperativeAircraftRow(
                            aircraft: a,
                            noReasonLabel: l10n.t(
                              'aircraft.noInoperativeReason',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('common.close')),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    AppLocalizations l10n,
    AsyncValue<AppResult<List<OperationalDataPoint>>> curveAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t('aircraft.chart.title'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'month',
                  label: Text(
                    l10n.t('aircraft.chart.month'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ButtonSegment(
                  value: 'week',
                  label: Text(
                    l10n.t('aircraft.chart.week'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ButtonSegment(
                  value: 'year',
                  label: Text(
                    l10n.t('aircraft.chart.year'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              selected: {_granularity},
              onSelectionChanged: (v) => setState(() => _granularity = v.first),
              emptySelectionAllowed: false,
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: curveAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => _buildNoData(l10n),
                data: (result) {
                  return switch (result) {
                    AppSuccess<List<OperationalDataPoint>>(
                      data: final points,
                    ) =>
                      points.isEmpty
                          ? _buildNoData(l10n)
                          : _buildLineChart(points),
                    AppFailure<List<OperationalDataPoint>>() => _buildNoData(
                      l10n,
                    ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('aircraft.chart.noData'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<OperationalDataPoint> points) {
    final colorScheme = Theme.of(context).colorScheme;
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.operationalPct))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 0.5,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _xLabelInterval(points.length),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortLabel(points[idx].periodLabel),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: colorScheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: spots.length <= 12,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: colorScheme.primary,
                    strokeWidth: 0,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            isCurved: true,
            curveSmoothness: 0.2,
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final label = idx < points.length
                    ? points[idx].periodLabel
                    : '';
                return LineTooltipItem(
                  '$label\n${spot.y.toStringAsFixed(1)}%',
                  TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _xLabelInterval(int total) {
    if (total <= 6) return 1;
    if (total <= 12) return 2;
    if (total <= 24) return 4;
    return (total / 6).ceil().toDouble();
  }

  String _shortLabel(String periodLabel) {
    if (periodLabel.length >= 7) return periodLabel.substring(5);
    return periodLabel;
  }
}

class _AircraftEmptyState extends StatelessWidget {
  const _AircraftEmptyState({required this.canManage, required this.onAdd});

  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('aircraft.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('aircraft.add')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InoperativeAircraftRow extends StatelessWidget {
  const _InoperativeAircraftRow({
    required this.aircraft,
    required this.noReasonLabel,
  });

  final Aircraft aircraft;
  final String noReasonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = aircraft.inoperativeReason?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: StatusColors.aircraft['inoperative']!.withValues(alpha: 0.25),
        ),
        color: StatusColors.aircraft['inoperative']!.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  aircraft.displayTailNumber,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                aircraft.model,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason == null || reason.isEmpty ? noReasonLabel : reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StatusColors.aircraft['inoperative'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Model Card Group ───────────────────────────────────────────────────

class _ModelCardGroup extends StatelessWidget {
  const _ModelCardGroup({
    required this.model,
    required this.aircraft,
    required this.canManage,
    this.onTap,
    this.onEdit,
  });
  final String model;
  final List<Aircraft> aircraft;
  final bool canManage;
  final void Function(Aircraft)? onTap;
  final void Function(Aircraft)? onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ops = aircraft.where((a) => a.status == 'operational').length;
    final inop = aircraft.length - ops;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flight,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    model,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      '$ops ops',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  if (inop > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.red.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        '$inop inop',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in aircraft)
                    InkWell(
                      onTap: onTap != null ? () => onTap!(a) : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 96,
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                (a.status == 'operational'
                                        ? Colors.green
                                        : Colors.red)
                                    .withValues(alpha: 0.4),
                          ),
                          color:
                              (a.status == 'operational'
                                      ? Colors.green
                                      : Colors.red)
                                  .withValues(alpha: 0.05),
                        ),
                        child: Center(
                          child: Text(
                            a.displayTailNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Aircraft Detail Dialog ─────────────────────────────────────────────

void _showAircraftDetail(
  BuildContext context,
  Aircraft aircraft, {
  required bool canManage,
  required void Function(Aircraft) onEdit,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      content: SizedBox(
        width: 640,
        child: _DetailContent(
          aircraft: aircraft,
          canManage: canManage,
          onEdit: onEdit,
        ),
      ),
    ),
  );
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({
    required this.aircraft,
    required this.canManage,
    required this.onEdit,
  });

  final Aircraft aircraft;
  final bool canManage;
  final void Function(Aircraft) onEdit;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final aircraft = widget.aircraft;
    final isOp = aircraft.status == 'operational';
    final color = isOp ? Colors.green : Colors.red;
    final hoursAsync = ref.watch(_flightHoursProvider(aircraft.unitId));
    final ordersAsync = ref.watch(
      _aircraftOrdersProvider(
        _AircraftOrdersParams(aircraftId: aircraft.id, from: _from, to: _to),
      ),
    );
    final hours = switch (hoursAsync.asData?.value) {
      AppSuccess(data: final h) => h,
      _ => <AircraftFlightHours>[],
    };
    final ac = hours.where((h) => h.aircraftId == aircraft.id).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOp ? Icons.check_circle : Icons.error,
                      size: 24,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        aircraft.displayTailNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.canManage) ...[
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onEdit(aircraft);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l10n.t('aircraft.edit'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: color.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        isOp ? 'Operativa' : 'Inoperativa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${aircraft.manufacturer} ${aircraft.model}${aircraft.year != null ? ' · ${aircraft.year}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (aircraft.serialNumber != null)
                  Text(
                    '${l10n.t('aircraft.detail.serial')}: ${aircraft.serialNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!isOp && aircraft.inoperativeReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('aircraft.detail.reason')}: ${aircraft.inoperativeReason}',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (ac != null) ...[
            Row(
              children: [
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.real'),
                    '${ac.realHours.toStringAsFixed(1)}h',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.planned'),
                    '${ac.plannedHours.toStringAsFixed(1)}h',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.flights'),
                    '${ac.flightCount}',
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ac.diffHours >= 0
                  ? l10n
                        .t('aircraft.hours.more')
                        .replaceAll(
                          '{hours}',
                          ac.diffHours.abs().toStringAsFixed(1),
                        )
                  : l10n
                        .t('aircraft.hours.less')
                        .replaceAll(
                          '{hours}',
                          ac.diffHours.abs().toStringAsFixed(1),
                        ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: ac.diffHours >= 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _RelatedOrdersSection(
            from: _from,
            to: _to,
            ordersAsync: ordersAsync,
            onChangeFrom: () => _pickDate(isFrom: true),
            onChangeTo: () => _pickDate(isFrom: false),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = DateTime(selected.year, selected.month, selected.day);
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = DateTime(selected.year, selected.month, selected.day);
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }
}

class _RelatedOrdersSection extends StatelessWidget {
  const _RelatedOrdersSection({
    required this.from,
    required this.to,
    required this.ordersAsync,
    required this.onChangeFrom,
    required this.onChangeTo,
  });

  final DateTime from;
  final DateTime to;
  final AsyncValue<AppResult<List<FlightOrderItem>>> ordersAsync;
  final VoidCallback onChangeFrom;
  final VoidCallback onChangeTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.t('aircraft.relatedOrders'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onChangeFrom,
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                '${l10n.t('aircraft.from')}: ${_formatAircraftDate(from)}',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onChangeTo,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(
                '${l10n.t('aircraft.to')}: ${_formatAircraftDate(to)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ordersAsync.when(
          loading: () => Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _RelatedOrdersState(
            message: l10n.t('aircraft.relatedOrdersFailed'),
          ),
          data: (result) => switch (result) {
            AppSuccess<List<FlightOrderItem>>(data: final items) =>
              items.isEmpty
                  ? _RelatedOrdersState(
                      message: l10n.t('aircraft.noRelatedOrders'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RelatedOrderCard(item: item),
                          ),
                      ],
                    ),
            AppFailure<List<FlightOrderItem>>() => _RelatedOrdersState(
              message: l10n.t('aircraft.relatedOrdersFailed'),
            ),
          },
        ),
      ],
    );
  }
}

class _RelatedOrdersState extends StatelessWidget {
  const _RelatedOrdersState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RelatedOrderCard extends StatelessWidget {
  const _RelatedOrderCard({required this.item});

  final FlightOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.orderNumber ?? item.flightOrderId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SmallMetaChip(
                label: item.operationDate != null
                    ? _formatAircraftDate(item.operationDate!)
                    : '--',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallMetaChip(
                label:
                    '${l10n.t('aircraft.orderStatus')}: ${_labelOrDash(item.orderStatus)}',
              ),
              _SmallMetaChip(
                label:
                    '${l10n.t('aircraft.itemStatus')}: ${_labelOrDash(item.status)}',
              ),
              _SmallMetaChip(
                label:
                    '${l10n.t('aircraft.etd')}: ${_formatAircraftTime(item.scheduledDeparture)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.t('aircraft.mission')}: ${_labelOrDash(item.mission)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${l10n.t('aircraft.route')}: ${_routeSummary(item)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetaChip extends StatelessWidget {
  const _SmallMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _formatAircraftDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatAircraftTime(DateTime? date) {
  if (date == null) return '--';
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _labelOrDash(String? value) {
  if (value == null || value.trim().isEmpty) return '--';
  return value;
}

String _routeSummary(FlightOrderItem item) {
  if (item.routes.isEmpty) return '--';
  final route = item.routes.first;
  final origin = route.originIcao ?? route.originRouteName ?? route.originLabel;
  final destination =
      route.destinationIcao ??
      route.destinationRouteName ??
      route.destinationLabel;
  return '${_labelOrDash(origin)} - ${_labelOrDash(destination)}';
}

class _HrCard extends StatelessWidget {
  const _HrCard(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      color: color.withValues(alpha: 0.05),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ── Flight Hours Chart ─────────────────────────────────────────────────

class _FlightHoursChart extends StatelessWidget {
  const _FlightHoursChart({required this.hoursAsync});

  final AsyncValue<AppResult<List<AircraftFlightHours>>> hoursAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return hoursAsync.when(
      loading: () => _FlightHoursChartState(
        title: l10n.t('aircraft.hours.byModel'),
        child: const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => _FlightHoursChartState(
        title: l10n.t('aircraft.hours.byModel'),
        message: l10n.t('aircraft.hours.loadFailed'),
      ),
      data: (result) => switch (result) {
        AppSuccess<List<AircraftFlightHours>>(data: final hours) =>
          hours.isEmpty
              ? _FlightHoursChartState(
                  title: l10n.t('aircraft.hours.byModel'),
                  message: l10n.t('aircraft.hours.empty'),
                )
              : _FlightHoursChartContent(hours: hours, theme: theme),
        AppFailure<List<AircraftFlightHours>>() => _FlightHoursChartState(
          title: l10n.t('aircraft.hours.byModel'),
          message: l10n.t('aircraft.hours.loadFailed'),
        ),
      },
    );
  }
}

class _FlightHoursChartState extends StatelessWidget {
  const _FlightHoursChartState({required this.title, this.message, this.child});

  final String title;
  final String? message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child ??
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(
                child: Text(
                  message ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _FlightHoursChartContent extends StatelessWidget {
  const _FlightHoursChartContent({required this.hours, required this.theme});

  final List<AircraftFlightHours> hours;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byModel = <String, List<AircraftFlightHours>>{};
    for (final h in hours) {
      byModel.putIfAbsent(h.model, () => []).add(h);
    }
    final entries =
        byModel.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.fold<double>(
                  0,
                  (total, aircraft) => total + aircraft.plannedHours,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('aircraft.hours.byModel'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: (entries.length * 32.0).clamp(60, 200),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (int i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value,
                        color: theme.colorScheme.primary,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final index = response?.spot?.touchedBarGroupIndex;
                  if (index == null || index < 0 || index >= entries.length) {
                    return;
                  }
                  final model = entries[index].key;
                  _showModelHoursDialog(
                    context,
                    model: model,
                    aircraftHours: byModel[model] ?? const [],
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}h',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) => v.toInt() < entries.length
                        ? Text(
                            entries[v.toInt()].key,
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  strokeWidth: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _showModelHoursDialog(
  BuildContext context, {
  required String model,
  required List<AircraftFlightHours> aircraftHours,
}) {
  final sorted = [...aircraftHours]
    ..sort((a, b) {
      final byHours = b.plannedHours.compareTo(a.plannedHours);
      if (byHours != 0) return byHours;
      return a.tailNumber.compareTo(b.tailNumber);
    });
  final l10n = AppLocalizations.of(context);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${l10n.t('aircraft.hours.modelSummary')} · $model'),
      content: SizedBox(
        width: 460,
        child: sorted.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.t('aircraft.hours.emptyModel'),
                  textAlign: TextAlign.center,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ModelHoursRow(hours: item),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.t('common.close')),
        ),
      ],
    ),
  );
}

class _ModelHoursRow extends StatelessWidget {
  const _ModelHoursRow({required this.hours});

  final AircraftFlightHours hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hours.tailNumber,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${l10n.t('aircraft.hours.ov')}: ${hours.plannedHours.toStringAsFixed(1)}h',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${l10n.t('aircraft.hours.engineOff')}: ${hours.realHours.toStringAsFixed(1)}h',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
