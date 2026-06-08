import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KpisWidget extends ConsumerWidget {
  const KpisWidget({super.key, this.unitId, this.squadronId});
  final String? unitId;
  final String? squadronId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightsAsync = ref.watch(todayFlightsProvider);
    final statsAsync = ref.watch(aircraftKpiProvider);

    final flightsResult = flightsAsync.asData?.value;
    final flightsCount = switch (flightsResult) {
      AppSuccess(data: final f) => f.length,
      _ => null,
    };

    final child = statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Icon(Icons.error_outline, size: 20)),
      ),
      data: (stats) => _KpisContent(stats: stats, flightsCount: flightsCount),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('kpis')!,
      child: child,
    );
  }
}

class _KpisContent extends StatelessWidget {
  const _KpisContent({required this.stats, required this.flightsCount});
  final DashboardAircraftKpiStats stats;
  final int? flightsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final operabilityPct = stats.total > 0 ? '${stats.operationalPct}%' : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _kpi(
                  flightsCount?.toString() ?? '...',
                  l10n.t('dashboard.kpi.flightsToday'),
                  Colors.green,
                  theme,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _kpi(
                  operabilityPct,
                  l10n.t('dashboard.kpi.operability'),
                  Colors.blue,
                  theme,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _kpi(
                  stats.total.toString(),
                  l10n.t('dashboard.kpi.fleetTotal'),
                  theme.colorScheme.primary,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (stats.units.isEmpty)
            _emptyUnits(theme, l10n)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final unit in stats.units)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _UnitKpiRow(unit: unit),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kpi(String value, String label, Color color, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyUnits(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        l10n.t('dashboard.kpi.noUnits'),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _UnitKpiRow extends StatelessWidget {
  const _UnitKpiRow({required this.unit});

  final DashboardAircraftUnitKpi unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final opPct = unit.total > 0 ? unit.operationalPct : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              unit.unitCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: unit.total > 0 ? unit.operational / unit.total : 0,
                minHeight: 5,
                color: Colors.green,
                backgroundColor: Colors.red.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              unit.total > 0 ? '$opPct%' : '--',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${unit.operational} ${l10n.t('dashboard.kpi.opsShort')} / '
            '${unit.inoperative} ${l10n.t('dashboard.kpi.inopShort')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
