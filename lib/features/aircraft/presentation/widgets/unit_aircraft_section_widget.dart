import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aircraft_providers.dart';
import 'aircraft_detail_widgets.dart';
import 'aircraft_widgets.dart';
import 'flight_hours_chart_widget.dart';

class UnitAircraftSection extends ConsumerStatefulWidget {
  const UnitAircraftSection({
    super.key,
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
  ConsumerState<UnitAircraftSection> createState() =>
      _UnitAircraftSectionState();
}

class _UnitAircraftSectionState extends ConsumerState<UnitAircraftSection> {
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
          ModelCardGroup(
            model: model,
            aircraft: byModel[model]!,
            canManage: widget.canManage,
            onTap: (a) => showAircraftDetail(
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
      aircraftOperationalCurveProvider(
        AircraftCurveParams(unitId: widget.unit.id, granularity: _granularity),
      ),
    );
    final hoursAsync = ref.watch(aircraftFlightHoursProvider(widget.unit.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryPanel(l10n),
        const SizedBox(height: 12),
        FlightHoursChart(hoursAsync: hoursAsync),
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
                          child: InoperativeAircraftRow(
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
