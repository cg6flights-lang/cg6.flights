import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OperabilityChartWidget extends ConsumerWidget {
  const OperabilityChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context).t;
    final curveAsync = ref.watch(operationalCurveProvider);

    final child = curveAsync.when(
      loading: () => _Centered(height: 180, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => _Centered(height: 180, child: Icon(Icons.error_outline, size: 20)),
      data: (result) => switch (result) {
        AppSuccess(data: final points) => points.isEmpty
            ? _Centered(height: 180, child: Text('Sin datos históricos', style: TextStyle(fontSize: 12)))
            : _ChartContent(points: points),
        AppFailure() => const _Centered(height: 180, child: Icon(Icons.error_outline, size: 20)),
      },
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('operability')!,
      child: child,
    );
  }
}

class _ChartContent extends StatelessWidget {
  const _ChartContent({required this.points});
  final List<OperationalDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDots = points.length <= 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true, drawVerticalLine: false, horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text('%', style: theme.textTheme.labelSmall),
              sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 20,
                getTitlesWidget: (value, _) => Text('${value.toInt()}', style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: _interval(points.length),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(points[idx].periodLabel, style: theme.textTheme.labelSmall?.copyWith(fontSize: 9)),
                );
              },
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].operationalPct)],
              isCurved: true, curveSmoothness: 0.2, color: theme.colorScheme.primary, barWidth: 2.5,
              dotData: FlDotData(show: showDots, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: theme.colorScheme.primary, strokeWidth: 0)),
              belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
            ),
          ],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((t) {
              final idx = t.spotIndex;
              final label = idx < points.length ? points[idx].periodLabel : '';
              return LineTooltipItem('$label\n${t.y.toStringAsFixed(0)}%', TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12));
            }).toList(),
          )),
        )),
      ),
    );
  }

  static double _interval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    if (count <= 24) return 3;
    return (count / 8).ceilToDouble();
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(height: height, child: Center(child: child));
}
