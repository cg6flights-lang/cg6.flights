import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter/material.dart';

import 'aircraft_widgets.dart';

/// Daily per-unit overview widgets used by the all-aircraft overview.

class DailyUnitPager extends StatelessWidget {
  const DailyUnitPager({
    super.key,
    required this.units,
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final List<UnitOption> units;
  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: Text(l10n.t('common.back')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentIndex + 1} / ${units.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: Text(l10n.t('common.next')),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            );
            return Center(child: controls);
          },
        ),
      ),
    );
  }
}

class DailyStatCard extends StatelessWidget {
  const DailyStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.footer,
  });

  final String label;
  final String value;
  final String? footer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(width: 6),
            Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DailyUnitSection extends StatelessWidget {
  const DailyUnitSection({
    super.key,
    required this.unit,
    required this.aircraft,
    required this.hoursByAircraft,
  });

  final UnitOption unit;
  final List<Aircraft> aircraft;
  final Map<String, AircraftFlightHours> hoursByAircraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final operational = aircraft.where((a) => a.status == 'operational').length;
    final inoperative = aircraft.length - operational;
    final unitHours = aircraft
        .map((a) => hoursByAircraft[a.id])
        .whereType<AircraftFlightHours>();
    final realHours = unitHours.fold<double>(0, (sum, h) => sum + h.realHours);
    final plannedHours = unitHours.fold<double>(
      0,
      (sum, h) => sum + h.plannedHours,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${unit.code} — ${unit.name}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        SmallMetaChip(
                          label:
                              '${l10n.t('aircraft.operational')}: $operational',
                        ),
                        SmallMetaChip(
                          label:
                              '${l10n.t('aircraft.inoperative')}: $inoperative',
                        ),
                        SmallMetaChip(
                          label:
                              '${l10n.t('aircraft.hours.engineOff')}: ${realHours.toStringAsFixed(1)}h',
                        ),
                        SmallMetaChip(
                          label:
                              '${l10n.t('aircraft.hours.ov')}: ${plannedHours.toStringAsFixed(1)}h',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: _buildModelGroupedTable(
                theme,
                aircraft,
                hoursByAircraft,
                l10n,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelGroupedTable(
    ThemeData theme,
    List<Aircraft> aircraft,
    Map<String, AircraftFlightHours> hoursByAircraft,
    AppLocalizations l10n,
  ) {
    final byModel = <String, List<Aircraft>>{};
    for (final a in aircraft) {
      byModel.putIfAbsent(a.model, () => []).add(a);
    }
    final models = byModel.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final model in models) ...[
            // Model divider header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flight,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    model,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${byModel[model]!.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Aircraft rows for this model
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 600),
                child: DataTable(
                  headingRowHeight: 28,
                  dataRowMinHeight: 30,
                  dataRowMaxHeight: 36,
                  columnSpacing: 12,
                  columns: [
                    DataColumn(
                      label: Text(
                        l10n.t('aircraft.tailNumber'),
                        style: _hdrStyle(theme),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.t('aircraft.status'),
                        style: _hdrStyle(theme),
                      ),
                    ),
                    DataColumn(label: Text('Esc', style: _hdrStyle(theme))),
                    DataColumn(
                      label: Text(
                        l10n.t('aircraft.lastFlight'),
                        style: _hdrStyle(theme),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        l10n.t('aircraft.daysWithoutFlyingLabel'),
                        style: _hdrStyle(theme),
                      ),
                    ),
                    DataColumn(label: Text('Prog.', style: _hdrStyle(theme))),
                    DataColumn(label: Text('Horas', style: _hdrStyle(theme))),
                    DataColumn(
                      label: Text('Situación', style: _hdrStyle(theme)),
                    ),
                  ],
                  rows: byModel[model]!.map((a) {
                    final sqName = a.squadronName ?? '';
                    final lastFlight = a.lastFlightAt != null
                        ? '${a.lastFlightAt!.day.toString().padLeft(2, '0')}/${a.lastFlightAt!.month.toString().padLeft(2, '0')}'
                        : '--';
                    final days = a.daysWithoutFlying?.toString() ?? '--';
                    final hours = hoursByAircraft[a.id];
                    final flightCount = hours != null
                        ? '${hours.flightCount}'
                        : '--';
                    final totalHours = hours != null
                        ? '${hours.realHours.toStringAsFixed(1)}h'
                        : '--';
                    final reason = a.inoperativeReason ?? '';
                    final statusColor = a.status == 'operational'
                        ? Colors.green
                        : a.status == 'maintenance'
                        ? Colors.orange
                        : Colors.red;
                    final statusLabel = a.status == 'operational'
                        ? l10n.t('aircraft.operational')
                        : a.status == 'maintenance'
                        ? l10n.t('aircraft.maintenance')
                        : l10n.t('aircraft.inoperative');
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            a.displayTailNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            sqName,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            lastFlight,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            days,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  days != '--' &&
                                      int.tryParse(days) != null &&
                                      int.parse(days) > 7
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            flightCount,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        DataCell(
                          Text(
                            totalHours,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle? _hdrStyle(ThemeData theme) => theme.textTheme.labelSmall?.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 11,
  );
}
