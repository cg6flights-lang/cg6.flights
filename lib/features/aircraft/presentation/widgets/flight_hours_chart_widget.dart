import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightHoursChart extends StatelessWidget {
  const FlightHoursChart({super.key, required this.hoursAsync});

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
