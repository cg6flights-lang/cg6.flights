import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AuditPerformancePage extends StatelessWidget {
  const AuditPerformancePage({super.key, required this.logs});

  final List<AuditLog> logs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _TrendsChart(logs: logs, l10n: l10n),
              _DonutChart(logs: logs, l10n: l10n),
              _ActorsChart(logs: logs, l10n: l10n),
              _KpiCards(logs: logs, l10n: l10n),
            ],
          );
        }
        return ListView(
          children: [
            _TrendsChart(logs: logs, l10n: l10n),
            const SizedBox(height: 8),
            _DonutChart(logs: logs, l10n: l10n),
            const SizedBox(height: 8),
            _ActorsChart(logs: logs, l10n: l10n),
            const SizedBox(height: 8),
            _KpiCards(logs: logs, l10n: l10n),
          ],
        );
      },
    );
  }
}

// ── 1. Trends: Line chart ────────────────────────────────────────

class _TrendsChart extends StatelessWidget {
  const _TrendsChart({required this.logs, required this.l10n});
  final List<AuditLog> logs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group by day + result
    final daily = <DateTime, Map<String, int>>{};
    final now = DateTime.now();
    for (var i = 59; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      daily[day] = {'success': 0, 'denied': 0, 'failed': 0};
    }
    for (final log in logs) {
      final day =
          DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day);
      if (daily.containsKey(day)) {
        daily[day]![log.result] = (daily[day]![log.result] ?? 0) + 1;
      }
    }

    final days = daily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <String, List<FlSpot>>{
      'success': [],
      'denied': [],
      'failed': [],
    };

    for (var i = 0; i < days.length; i++) {
      final entry = days[i];
      for (final result in ['success', 'denied', 'failed']) {
        spots[result]!.add(FlSpot(i.toDouble(),
            (entry.value[result] ?? 0).toDouble()));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('audit.chartTrends'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox();
                          final d = days[idx].key;
                          return Text(
                            '${d.day}/${d.month}',
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _line(spots['success']!, Colors.green),
                    _line(spots['denied']!, Colors.orange),
                    _line(spots['failed']!, Colors.red),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final label = s.barIndex == 0
                            ? 'Exito'
                            : s.barIndex == 1
                                ? 'Denegado'
                                : 'Fallido';
                        return LineTooltipItem(
                          '$label: ${s.y.toInt()}',
                          TextStyle(color: s.bar.color, fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _legend(theme),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _legend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(Colors.green, 'Exito', theme),
        const SizedBox(width: 8),
        _dot(Colors.orange, 'Denegado', theme),
        const SizedBox(width: 8),
        _dot(Colors.red, 'Fallido', theme),
      ],
    );
  }

  Widget _dot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

// ── 2. Distribution: Donut chart ──────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.logs, required this.l10n});
  final List<AuditLog> logs;
  final AppLocalizations l10n;
  static const _colors = [
    Colors.blue, Colors.teal, Colors.orange, Colors.purple,
    Colors.pink, Colors.indigo, Colors.cyan, Colors.amber,
    Colors.deepPurple, Colors.lightGreen, Colors.brown, Colors.red,
    Colors.lime, Colors.deepOrange, Colors.blueGrey, Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byType = <String, int>{};
    for (final log in logs) {
      byType[log.resourceType] = (byType[log.resourceType] ?? 0) + 1;
    }
    final sorted = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('audit.chartDistribution'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: sorted.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    return PieChartSectionData(
                      color: _colors[idx % _colors.length],
                      value: e.value.toDouble(),
                      title: '',
                      radius: 18,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: sorted.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final label = switch (e.key) {
                  'crew' => 'Trip.',
                  'aircraft' => 'Aero.',
                  'unit' => 'Unid.',
                  'route' => 'Rutas',
                  'flight_order' => 'OV',
                  'flights' => 'Vuelos',
                  'access' => 'Acc.',
                  'auth' => 'Auth',
                  'settings' => 'Conf.',
                  'report' => 'Rep.',
                  'notification' => 'Notif.',
                  'message' => 'Msj.',
                  'profile' => 'Perf.',
                  'permission' => 'Perm.',
                  'role' => 'Rol',
                  'user' => 'Usr.',
                  'closure' => 'Cierre',
                  _ => e.key,
                };
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _colors[idx % _colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text('$label ${e.value}',
                        style: theme.textTheme.labelSmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3. Actors: Stacked horizontal bar chart ──────────────────────

class _ActorsChart extends StatelessWidget {
  const _ActorsChart({required this.logs, required this.l10n});
  final List<AuditLog> logs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byRole = <String, Map<String, int>>{};
    for (final log in logs) {
      byRole.putIfAbsent(log.actorRole, () => {'success': 0, 'denied': 0, 'failed': 0});
      byRole[log.actorRole]![log.result] =
          (byRole[log.actorRole]![log.result] ?? 0) + 1;
    }

    final roleLabel = <String, String>{
      'leader': 'Lider', 'general_admin': 'Admin Gral',
      'unit_command': 'Cmd Unidad', 'unit_admin': 'Admin Unidad', 'ttaa': 'TTAA',
    };

    final sorted = byRole.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.values.fold<int>(0, (s, v) => s + v);
        final bTotal = b.value.values.fold<int>(0, (s, v) => s + v);
        return bTotal.compareTo(aTotal);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('audit.chartActors'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.center,
                  barGroups: sorted.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final e = entry.value;
                    final success = (e.value['success'] ?? 0).toDouble();
                    final denied = (e.value['denied'] ?? 0).toDouble();
                    final failed = (e.value['failed'] ?? 0).toDouble();
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: success + denied + failed,
                          fromY: success + denied,
                          color: Colors.red,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: success + denied,
                          fromY: success,
                          color: Colors.orange,
                          width: 16,
                        ),
                        BarChartRodData(
                          toY: success,
                          fromY: 0,
                          color: Colors.green,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= sorted.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              roleLabel[sorted[idx].key] ?? sorted[idx].key,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  maxY: null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(Colors.green, 'Exito', theme),
                const SizedBox(width: 6),
                _legendDot(Colors.orange, 'Denegado', theme),
                const SizedBox(width: 6),
                _legendDot(Colors.red, 'Fallido', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

// ── 4. KPI cards ─────────────────────────────────────────────────

class _KpiCards extends StatelessWidget {
  const _KpiCards({required this.logs, required this.l10n});
  final List<AuditLog> logs;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = logs.length;
    final success = logs.where((l) => l.result == 'success').length;
    final denied = logs.where((l) => l.result == 'denied').length;
    final rate = total > 0 ? ((success / total) * 100).round() : 0;
    final denyRate = total > 0 ? ((denied / total) * 100).round() : 0;

    // Most active day
    final byDay = <DateTime, int>{};
    for (final log in logs) {
      final d = DateTime(log.createdAt.year, log.createdAt.month, log.createdAt.day);
      byDay[d] = (byDay[d] ?? 0) + 1;
    }
    String peakDay = '--';
    if (byDay.isNotEmpty) {
      final peak = byDay.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakDay = '${peak.key.day}/${peak.key.month}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.t('audit.chartKpi'),
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _kpi(l10n.t('audit.kpiTotal'), total.toString(),
                      Icons.receipt_long_outlined, Colors.blue, theme),
                  _kpi(l10n.t('audit.kpiSuccess'), '$rate%',
                      Icons.check_circle_outline, Colors.green, theme),
                  _kpi(l10n.t('audit.kpiDenied'), '$denyRate%',
                      Icons.block_outlined, Colors.orange, theme),
                  _kpi(l10n.t('audit.kpiPeakDay'), peakDay,
                      Icons.trending_up, Colors.purple, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String title, String value, IconData icon, Color color,
      ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(title,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }
}
