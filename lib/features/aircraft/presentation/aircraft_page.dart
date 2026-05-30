import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aircraft_form_dialog.dart';

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

final _operationalCurveProvider = FutureProvider.family<
  AppResult<List<OperationalDataPoint>>,
  _CurveParams
>((ref, params) async {
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

        final unitAircraft = <String, List<Aircraft>>{};
        for (final a in aircraft) {
          unitAircraft.putIfAbsent(a.unitId, () => []).add(a);
        }

        final showUnits = units
            .where((u) => unitAircraft.containsKey(u.id))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 16),
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

    final saved = await showDialog<AircraftFormResult>(
      context: context,
      builder: (_) => AircraftFormDialog(
        aircraft: aircraft,
        units: activeUnits,
        defaultUnitId: defaultUnitId,
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
          '${l10n.t('aircraft.deactivateConfirm')} ${aircraft.tailNumber}?',
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
      _filtered.where((a) => a.status == 'inoperative').toList();

  List<Aircraft> get _mantenimiento =>
      _filtered.where((a) => a.status == 'maintenance').toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final modelOptions = widget.aircraft
        .map((a) => a.model)
        .toSet()
        .toList()
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
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
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
                      child: Text(l10n.t('aircraft.all'),
                          style: const TextStyle(fontSize: 13)),
                    ),
                    for (final m in modelOptions)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _modelFilter = v ?? ''),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSubsection(
          title: l10n.t('aircraft.operativeSection'),
          aircraft: _operativas,
          icon: Icons.check_circle_outline,
          color: StatusColors.aircraft['operational']!,
        ),
        const SizedBox(height: 16),
        _buildSubsection(
          title: l10n.t('aircraft.inoperativeSection'),
          aircraft: _inoperativas,
          icon: Icons.error_outline,
          color: StatusColors.aircraft['inoperative']!,
        ),
        const SizedBox(height: 16),
        _buildSubsection(
          title: l10n.t('aircraft.maintenanceSection'),
          aircraft: _mantenimiento,
          icon: Icons.build_outlined,
          color: StatusColors.aircraft['maintenance']!,
        ),
      ],
    );
  }

  Widget _buildRightColumn(AppLocalizations l10n) {
    final curveAsync = ref.watch(_operationalCurveProvider(_CurveParams(
      unitId: widget.unit.id,
      granularity: _granularity,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryPanel(l10n),
        const SizedBox(height: 16),
        _buildChartSection(l10n, curveAsync),
      ],
    );
  }

  Widget _buildSummaryPanel(AppLocalizations l10n) {
    final total = _filtered.length;
    final op = _operativas.length;
    final inop = _inoperativas.length;
    final maint = _mantenimiento.length;

    Widget statCard(String label, int count, int? pct, Color color) {
      return Container(
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
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
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
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: statCard(
                    l10n.t('aircraft.maintenance'),
                    maint,
                    total > 0 ? (maint * 100 ~/ total) : 0,
                    StatusColors.aircraft['maintenance']!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: statCard(
                    l10n.t('aircraft.total'),
                    total,
                    null,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
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
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'month',
                  label: Text(l10n.t('aircraft.chart.month'),
                      style: const TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 'week',
                  label: Text(l10n.t('aircraft.chart.week'),
                      style: const TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 'year',
                  label: Text(l10n.t('aircraft.chart.year'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_granularity},
              onSelectionChanged: (v) =>
                  setState(() => _granularity = v.first),
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
                      data: final points
                    ) =>
                      points.isEmpty
                          ? _buildNoData(l10n)
                          : _buildLineChart(points),
                    AppFailure<List<OperationalDataPoint>>() =>
                      _buildNoData(l10n),
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 10),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 9),
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
                final label =
                    idx < points.length ? points[idx].periodLabel : '';
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

  Widget _buildSubsection({
    required String title,
    required List<Aircraft> aircraft,
    required IconData icon,
    required Color color,
  }) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${aircraft.length})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (aircraft.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.t('aircraft.empty'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 560),
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.titleSmall,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: [
                  DataColumn(label: Text(l10n.t('aircraft.tailNumber'))),
                  DataColumn(label: Text(l10n.t('aircraft.manufacturer'))),
                  DataColumn(label: Text(l10n.t('aircraft.model'))),
                  DataColumn(label: Text(l10n.t('aircraft.year'))),
                  if (widget.canManage) const DataColumn(label: Text('')),
                ],
                rows: [
                  for (final a in aircraft)
                    DataRow(
                      cells: [
                        DataCell(Text(a.tailNumber,
                            style: const TextStyle(fontSize: 13))),
                        DataCell(Text(a.manufacturer,
                            style: const TextStyle(fontSize: 13))),
                        DataCell(Text(a.model,
                            style: const TextStyle(fontSize: 13))),
                        DataCell(Text(a.year?.toString() ?? '-',
                            style: const TextStyle(fontSize: 13))),
                        if (widget.canManage)
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  tooltip: l10n.t('aircraft.edit'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => widget.onEdit(a),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  tooltip: l10n.t('aircraft.deactivate'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => widget.onDeactivate(a),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
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
